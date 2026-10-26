import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/fixture_entry.dart';
import '../models/play.dart';
import '../models/team.dart';
import '../models/visual_stats.dart';
import '../models/volley_match.dart';
import '../utils/app_version.dart';
import '../utils/id_gen.dart';
import 'full_backup.dart';

/// Se lanza al usar equipos/partidos/jugadas/fixture sin los cajones de una
/// cuenta abiertos (antes del login, después de cerrar sesión), o al guardar
/// con un [StorageService.userDataToken] de una sesión que ya terminó. Es un
/// [StateError] con un mensaje claro en vez del `LateInitializationError`
/// que daría un `late Box` sin abrir.
class UserDataClosedError extends StateError {
  UserDataClosedError(super.message);
}

/// Sufijo de los cajones de una cuenta que no es la dueña de los datos
/// legacy (ver [StorageService.openUserBoxes]). Hive pasa los nombres de caja
/// a minúsculas y los uid de Firebase distinguen mayúsculas, así que el uid
/// no se puede usar tal cual: se codifica en base32 (RFC 4648, alfabeto en
/// minúsculas `a-z2-7`, sin relleno), que es inyectivo y no depende de
/// mayúsculas. Base32 y no hex porque un uid de Firebase puede tener hasta
/// 128 caracteres: en hex serían 256 y `fixture_box_` + 256 se pasa de los
/// 255 que acepta Hive; en base32 son 205 como máximo (217 con el prefijo
/// más largo). Un uid de email/contraseña (28 caracteres) da 45.
String boxSuffixFor(String uid) {
  if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'no puede estar vacío');
  const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in utf8.encode(uid)) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(alphabet[(buffer >> bits) & 31]);
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(alphabet[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

/// Guarda Equipos y Partidos como Map<String,dynamic> planos dentro de Hive,
/// sin necesidad de generar TypeAdapters (evita build_runner).
///
/// Datos por cuenta: `settings_box` es del dispositivo (deviceId, tema,
/// preferencias de estadística visual) y se abre en [init]. Equipos,
/// partidos, jugadas y fixture son de la cuenta logueada y se abren con
/// [openUserBoxes] recién cuando hay sesión (ver `_AccountDataGate` en
/// `main.dart`); al cerrar sesión se cierran con [closeUserBoxes], nunca se
/// borran.
///
/// Los cajones de siempre (`teams_box`, `matches_box`, `plays_box`,
/// `fixture_box`) no se migran ni se renombran: pasan a ser de la cuenta
/// dueña ([legacyOwnerUid]), y cualquier otra cuenta estrena los suyos con
/// el sufijo de [boxSuffixFor]. Así no hay ninguna migración que se pueda
/// cortar a la mitad. Dos casos aceptados a propósito (se corrigen con
/// Exportar todo / Importar copia completa, o partido por partido):
///
/// - Actualizar sin sesión: el primer uid que inicia sesión después de
///   actualizar queda como dueño, aunque sea otra persona.
/// - Si antes de esta versión dos cuentas ya usaron el mismo dispositivo,
///   sus datos están mezclados en los cajones de siempre y quedan todos con
///   el dueño. No hay forma de separarlos, pero no se pierden.
class StorageService {
  static const _teamsBox = 'teams_box';
  static const _matchesBox = 'matches_box';
  static const _playsBox = 'plays_box';
  static const _fixtureBox = 'fixture_box';
  static const _settingsBox = 'settings_box';
  static const _themeModeKey = 'theme_mode';
  static const _deviceIdKey = 'device_id';
  static const _legacyDeviceIdKey = 'legacy_device_id';
  static const _legacyOwnerUidKey = 'legacy_owner_uid';
  static const _preAccountBackupDoneKey = 'pre_account_backup_done';
  static const _subscriptionCacheKey = 'subscription_cache';
  static const _freeStatsMatchIdKey = 'free_stats_match_id';
  static const _pdfVisualChartsKey = 'pdf_visual_charts';
  static const _pdfCourtMapsKey = 'pdf_court_maps';
  static const _screenVisualChartsKey = 'screen_visual_charts';
  static const _screenCourtMapsKey = 'screen_court_maps';

  /// Carpeta (dentro del directorio de documentos de la app) de la copia
  /// previa automática. En Android queda excluida del Auto Backup en la nube
  /// (ver `backup_rules.xml`/`data_extraction_rules.xml`).
  static const backupsFolderName = 'rallystats_backups';

  Box? _teams;
  Box? _matches;
  Box? _plays;
  Box? _fixture;
  late Box _settings;
  late String _deviceId;

  /// Cuenta cuyos cajones están abiertos, o `null` si no hay ninguna.
  String? _openUid;

  /// Cambia cada vez que se abren o cierran los cajones de una cuenta (ver
  /// [userDataToken]).
  int _sessionToken = 0;

  /// Cola de aperturas/cierres: un login rechazado o un cierre forzado
  /// pueden cruzarse con una apertura en curso, y nunca tienen que quedar
  /// a medio hacer uno encima del otro.
  Future<void> _boxOps = Future<void>.value();

  static final StorageService instance = StorageService._();
  StorageService._();

  Future<void>? _initFuture;
  bool _ready = false;

  /// Dónde se escribe la copia previa. Se puede reemplazar en tests (por
  /// ejemplo, para simular que falla).
  @visibleForTesting
  Future<Directory> Function() backupsDirectoryResolver = _defaultBackupsDirectory;

  static Future<Directory> _defaultBackupsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}$backupsFolderName');
  }

  /// Carpeta de las copias automáticas (puede no existir todavía).
  Future<Directory> backupsDirectory() => backupsDirectoryResolver();

  /// Abre `settings_box`, hace la copia previa si todavía no se hizo y
  /// resuelve el deviceId. No abre los datos de ninguna cuenta (ver
  /// [openUserBoxes]). Se puede llamar más de una vez.
  Future<void> init() async {
    // Atajo sin esperar ningún Future si ya terminó: esperar el Future
    // memorizado (creado en otra zona) cuelga a quien llama dentro del tiempo
    // simulado de un testWidgets.
    if (_ready) return;
    await (_initFuture ??= _init());
    _ready = true;
  }

  Future<void> _init() async {
    await Hive.initFlutter();
    _settings = await Hive.openBox(_settingsBox);
    // Antes que cualquier otra cosa: la copia de los datos tal como estaban.
    await _ensurePreAccountBackup();
    _deviceId = await _resolveDeviceId();
  }

  /// Cierra todo y vuelve al estado de recién creado, para que cada test
  /// arranque de cero con su propio directorio temporal.
  @visibleForTesting
  Future<void> resetForTest() async {
    await Hive.close();
    _teams = _matches = _plays = _fixture = null;
    _openUid = null;
    _sessionToken++;
    _boxOps = Future<void>.value();
    _initFuture = null;
    _ready = false;
    backupsDirectoryResolver = _defaultBackupsDirectory;
  }

  // ---------------- Copia previa ----------------

  /// En el primer arranque de la versión con datos por cuenta escribe un
  /// JSON con todo el contenido de los 4 cajones de siempre (formato de
  /// [FullBackup], el mismo que "Exportar todo") en
  /// `rallystats_backups/rallystats_backup_<yyyyMMdd>.json`. Si los 4 están
  /// vacíos (instalación nueva) solo se marca como hecha. Si falla, se
  /// registra y el arranque sigue (los pasos siguientes no mueven datos);
  /// sin la marca, se reintenta en el próximo arranque.
  Future<void> _ensurePreAccountBackup() async {
    if (_settings.get(_preAccountBackupDoneKey) == true) return;
    final opened = <Box>[];
    try {
      Future<Box> open(String name) async {
        final b = await Hive.openBox(name);
        opened.add(b);
        return b;
      }

      final teams = _decodeTeams(await open(_teamsBox));
      final matches = _decodeMatches(await open(_matchesBox));
      final plays = _decodePlays(await open(_playsBox));
      final fixture = _decodeFixture(await open(_fixtureBox));
      if (teams.isNotEmpty || matches.isNotEmpty || plays.isNotEmpty || fixture.isNotEmpty) {
        final now = DateTime.now();
        final json = FullBackup.buildJson(
          teams: teams,
          matches: matches,
          plays: plays,
          fixture: fixture,
          createdAt: now,
          appVersion: kAppVersion,
        );
        final dir = await backupsDirectoryResolver();
        await dir.create(recursive: true);
        final name = 'rallystats_backup_${DateFormat('yyyyMMdd').format(now)}.json';
        final target = File('${dir.path}${Platform.pathSeparator}$name');
        // Se escribe a un temporal y se renombra: un corte a la mitad nunca
        // deja un archivo truncado con el nombre definitivo.
        final tmp = File('${target.path}.tmp');
        await tmp.writeAsString(jsonEncode(json), flush: true);
        await tmp.rename(target.path);
      }
      await _settings.put(_preAccountBackupDoneKey, true);
    } catch (e, st) {
      debugPrint('StorageService: no se pudo hacer la copia previa ($e). Se reintenta en el próximo arranque.\n$st');
    } finally {
      for (final b in opened) {
        await b.close();
      }
    }
  }

  // ---------------- Cajones por cuenta ----------------

  /// Uid de la cuenta dueña de los cajones de siempre, o `null` si todavía
  /// no se fijó (ver [ensureLegacyOwner]).
  String? get legacyOwnerUid => _settings.get(_legacyOwnerUidKey) as String?;

  /// Fija [uid] como dueño de los cajones de siempre si todavía no hay uno.
  /// Se fija una sola vez y nunca cambia: con la sesión ya abierta en el
  /// primer arranque (`main.dart`) o, si no había, con el primer uid que
  /// entra (lo llama [openUserBoxes]).
  Future<void> ensureLegacyOwner(String uid) async {
    if (legacyOwnerUid != null) return;
    await _settings.put(_legacyOwnerUidKey, uid);
  }

  /// Cuenta cuyos cajones están abiertos, o `null`.
  String? get openUid => _openUid;

  /// Identifica la sesión de datos abierta: cambia en cada [openUserBoxes] y
  /// [closeUserBoxes]. Quien guarda desde algo que puede sobrevivir a un
  /// cierre de sesión (`MatchController`) lo captura al crearse y lo pasa al
  /// guardar, para que un guardado tardío nunca caiga en el cajón de otra
  /// cuenta.
  int get userDataToken => _sessionToken;

  Future<void> _serialized(Future<void> Function() op) {
    final result = _boxOps.then((_) => op());
    _boxOps = result.catchError((_) {});
    return result;
  }

  /// Abre equipos, partidos, jugadas y fixture de [uid]. El dueño legacy
  /// abre los cajones de siempre; cualquier otra cuenta,
  /// `<caja>_<boxSuffixFor(uid)>`. Si había otra cuenta abierta, primero la
  /// cierra.
  Future<void> openUserBoxes(String uid) => _serialized(() async {
        await init();
        if (_openUid == uid) return;
        await _closeUserBoxesNow();
        await ensureLegacyOwner(uid);
        final suffix = uid == legacyOwnerUid ? null : boxSuffixFor(uid);
        String name(String base) => suffix == null ? base : '${base}_$suffix';
        final opened = <Box>[];
        try {
          for (final base in [_teamsBox, _matchesBox, _playsBox, _fixtureBox]) {
            opened.add(await Hive.openBox(name(base)));
          }
        } catch (_) {
          for (final b in opened) {
            await b.close();
          }
          rethrow;
        }
        _teams = opened[0];
        _matches = opened[1];
        _plays = opened[2];
        _fixture = opened[3];
        _openUid = uid;
        _sessionToken++;
      });

  /// Cierra los cajones de la cuenta abierta (al cerrar sesión). Nunca los
  /// borra: los datos se vuelven a ver al entrar otra vez con esa cuenta.
  Future<void> closeUserBoxes() => _serialized(_closeUserBoxesNow);

  Future<void> _closeUserBoxesNow() async {
    final boxes = [_teams, _matches, _plays, _fixture].whereType<Box>().toList();
    // Primero se sueltan las referencias, para que cualquier guardado que
    // llegue mientras se cierra falle con el error claro.
    _teams = _matches = _plays = _fixture = null;
    _openUid = null;
    _sessionToken++;
    // `close` espera a que terminen las escrituras pendientes.
    for (final b in boxes) {
      await b.close();
    }
  }

  Box _box(Box? box, String what) {
    if (box == null) {
      throw UserDataClosedError(
          'No hay una cuenta con los datos abiertos: no se puede acceder a $what antes de '
          'iniciar sesión ni después de cerrarla (StorageService.openUserBoxes).');
    }
    return box;
  }

  Box get _teamsBoxOpen => _box(_teams, 'los equipos');
  Box get _matchesBoxOpen => _box(_matches, 'los partidos');
  Box get _playsBoxOpen => _box(_plays, 'las jugadas');
  Box get _fixtureBoxOpen => _box(_fixture, 'el fixture');

  /// Clave de `settings_box` que depende de la cuenta: el dueño legacy usa la
  /// de siempre (así conserva lo que ya tenía), las demás `<clave>_<sufijo>`.
  String _accountKey(String base, String uid) =>
      uid == legacyOwnerUid ? base : '${base}_${boxSuffixFor(uid)}';

  // ---------------- Teams ----------------

  static List<Team> _decodeTeams(Box box) => box.values
      .map((v) => Team.fromJson(Map<dynamic, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Team> loadTeams() => _decodeTeams(_teamsBoxOpen);

  /// [sessionToken]: igual que en [saveMatch].
  Future<void> saveTeam(Team team, {int? sessionToken}) async {
    _checkSession(sessionToken, 'El equipo ${team.id}');
    await _teamsBoxOpen.put(team.id, team.toJson());
  }

  Future<void> deleteTeam(String teamId) async {
    await _teamsBoxOpen.delete(teamId);
  }

  // ---------------- Matches ----------------

  static List<VolleyMatch> _decodeMatches(Box box) => box.values
      .map((v) => VolleyMatch.fromJson(Map<dynamic, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<VolleyMatch> loadMatches() => _decodeMatches(_matchesBoxOpen);

  /// [sessionToken]: si se pasa (ver [userDataToken]) y la sesión de datos
  /// ya no es la misma, falla con [UserDataClosedError] en vez de escribir.
  Future<void> saveMatch(VolleyMatch match, {int? sessionToken}) async {
    _checkSession(sessionToken, 'El partido ${match.id}');
    await _matchesBoxOpen.put(match.id, match.toJson());
  }

  void _checkSession(int? sessionToken, String what) {
    if (sessionToken != null && sessionToken != _sessionToken) {
      throw UserDataClosedError(
          '$what es de una sesión que ya se cerró: no se guarda en los datos de la cuenta '
          'abierta ahora.');
    }
  }

  Future<void> deleteMatch(String matchId) async {
    await _matchesBoxOpen.delete(matchId);
  }

  // ---------------- Plays (jugadas de la pizarra táctica) ----------------

  static List<Play> _decodePlays(Box box) => box.values
      .map((v) => Play.fromJson(Map<dynamic, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<Play> loadPlays() => _decodePlays(_playsBoxOpen);

  /// [sessionToken]: igual que en [saveMatch].
  Future<void> savePlay(Play play, {int? sessionToken}) async {
    _checkSession(sessionToken, 'La jugada ${play.id}');
    await _playsBoxOpen.put(play.id, play.toJson());
  }

  Future<void> deletePlay(String playId) async {
    await _playsBoxOpen.delete(playId);
  }

  // ---------------- Fixture (partidos por jugar) ----------------

  static List<FixtureEntry> _decodeFixture(Box box) => box.values
      .map((v) => FixtureEntry.fromJson(Map<dynamic, dynamic>.from(v as Map)))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  List<FixtureEntry> loadFixtureEntries() => _decodeFixture(_fixtureBoxOpen);

  /// [sessionToken]: igual que en [saveMatch].
  Future<void> saveFixtureEntry(FixtureEntry entry, {int? sessionToken}) async {
    _checkSession(sessionToken, 'La fila del fixture ${entry.id}');
    await _fixtureBoxOpen.put(entry.id, entry.toJson());
  }

  Future<void> deleteFixtureEntry(String entryId) async {
    await _fixtureBoxOpen.delete(entryId);
  }

  // ---------------- Settings (preferencias de la app) ----------------

  /// Modo de tema elegido manualmente por el usuario. Por defecto, claro.
  ThemeMode loadThemeMode() {
    final v = _settings.get(_themeModeKey, defaultValue: 'light') as String;
    return v == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _settings.put(_themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  /// Identificador de este dispositivo para `AuthService` (distinguir "el
  /// mismo dispositivo volviendo a entrar" de "otro dispositivo tratando de
  /// usar la misma cuenta"). Resuelto una vez en [init] y cacheado en
  /// memoria; ver [_resolveDeviceId] para de dónde sale.
  String loadOrCreateDeviceId() => _deviceId;

  /// Id de dispositivo anterior a la migración a `ANDROID_ID` (ver
  /// [_resolveDeviceId]), si esta cuenta venía de esa versión. Puede seguir
  /// registrado en `account_devices` en Firestore a nombre de este mismo
  /// dispositivo, así que `AuthService` lo usa para reconocerse y migrar el
  /// lugar ya reclamado en vez de perderlo contra el límite del plan.
  String? loadLegacyDeviceId() => _settings.get(_legacyDeviceIdKey) as String?;

  /// Limpia el id legacy una vez que ya cumplió su función (se usó para
  /// migrar o liberar el lugar que tenía reclamado).
  Future<void> clearLegacyDeviceId() async => await _settings.delete(_legacyDeviceIdKey);

  /// En Android usa `Settings.Secure.ANDROID_ID` (vía el plugin `android_id`):
  /// a diferencia de un id guardado solo en Hive, sobrevive a desinstalar y
  /// reinstalar la app en el mismo equipo (aunque no a un reset de fábrica),
  /// que es justo el caso que antes generaba un "dispositivo fantasma" en
  /// `account_devices` — la reinstalación creaba un id nuevo sin liberar el
  /// lugar del anterior, y con el límite de 1 dispositivo del plan gratis
  /// eso dejaba al usuario sin poder volver a entrar a su propia cuenta. Se
  /// sigue cacheando en `_settings` para no depender del plugin en cada
  /// arranque y como respaldo si `getId()` no devuelve nada (algunos ROMs) o
  /// tira excepción; ahí, y en cualquier plataforma que no sea Android
  /// (donde no existe un equivalente a ANDROID_ID), se mantiene el esquema
  /// anterior: un id random generado una sola vez y persistido en Hive (por
  /// lo tanto sí se pierde si se desinstala, como antes).
  ///
  /// Cuentas que ya estaban logueadas con el esquema anterior (id random en
  /// Hive) migran acá mismo: si el `ANDROID_ID` difiere del cacheado, el
  /// cacheado viejo se guarda como [_legacyDeviceIdKey] *antes* de pisarlo
  /// con el nuevo, para que `AuthService` pueda reconocer que este
  /// dispositivo es el mismo que ya tenía un lugar reclamado con ese id
  /// viejo — si no quedara persistido acá (solo en memoria), se perdería en
  /// el primer arranque tras la migración y esa cuenta quedaría trabada
  /// afuera contra el límite de dispositivos.
  Future<String> _resolveDeviceId() async {
    final cached = _settings.get(_deviceIdKey) as String?;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidId = await const AndroidId().getId();
        if (androidId != null && androidId.isNotEmpty) {
          if (androidId != cached) {
            if (cached != null && cached.isNotEmpty) {
              await _settings.put(_legacyDeviceIdKey, cached);
            }
            await _settings.put(_deviceIdKey, androidId);
          }
          return androidId;
        }
      } catch (_) {
        // Defensivo: si el plugin falla, cae al esquema de respaldo abajo.
      }
    }
    if (cached != null && cached.isNotEmpty) return cached;
    final generated = generateId('device_');
    await _settings.put(_deviceIdKey, generated);
    return generated;
  }

  /// Última caché conocida del estado de la suscripción de [uid] (ver
  /// `SubscriptionController`), para poder resolver algo razonable al abrir
  /// la app sin depender de una llamada de red a RevenueCat. `null` si esa
  /// cuenta todavía no guardó ninguna. Es por cuenta: si fuera una sola, al
  /// cambiar de cuenta sin red la nueva arrancaría con el premium de la
  /// anterior.
  Map<String, dynamic>? loadSubscriptionCache(String uid) {
    final raw = _settings.get(_accountKey(_subscriptionCacheKey, uid)) as String?;
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSubscriptionCache(String uid, Map<String, dynamic> json) async {
    await _settings.put(_accountKey(_subscriptionCacheKey, uid), jsonEncode(json));
  }

  /// Caché local del único partido para el que [uid] (cuenta free) ya generó
  /// estadística. La fuente de verdad es `account_devices/{uid}` en
  /// Firestore (ver `FreeStatsQuotaStore`); esto es solo para leerlo sin
  /// red. Se mantiene aunque el partido se borre del archivo, para que
  /// borrar y crear uno nuevo no lo esquive.
  String? loadFreeStatsMatchId(String uid) =>
      _settings.get(_accountKey(_freeStatsMatchIdKey, uid)) as String?;

  Future<void> saveFreeStatsMatchId(String uid, String matchId) async {
    await _settings.put(_accountKey(_freeStatsMatchIdKey, uid), matchId);
  }

  // Estado del sync con la nube (ver `MatchSyncService`), por cuenta.
  static const cloudSyncKey = 'cloud_sync';
  static const cloudCursorMatchesKey = 'cloud_cursor_matches';
  static const cloudCursorTeamsKey = 'cloud_cursor_teams';
  static const cloudCursorPlaysKey = 'cloud_cursor_plays';
  static const cloudCursorFixtureKey = 'cloud_cursor_fixture';
  static const cloudUploadedKey = 'cloud_uploaded';
  static const cloudUploadDoneKey = 'cloud_upload_done';
  static const cloudOversizeKey = 'cloud_oversize';
  static const cloudOversizePlaysKey = 'cloud_oversize_plays';
  static const cloudLastSyncKey = 'cloud_last_sync';

  /// Versión de la política que aceptó la cuenta para la nube (caché de
  /// `account_devices/{uid}.cloudConsent.privacyPolicyVersion`).
  static const cloudConsentVersionKey = 'cloud_consent_version';

  static const _accountValueKeys = {
    cloudSyncKey,
    cloudCursorMatchesKey,
    cloudCursorTeamsKey,
    cloudCursorPlaysKey,
    cloudCursorFixtureKey,
    cloudUploadedKey,
    cloudUploadDoneKey,
    cloudOversizeKey,
    cloudOversizePlaysKey,
    cloudLastSyncKey,
    cloudConsentVersionKey,
  };

  /// Valor de `settings_box` que es de la cuenta [uid], con la misma regla
  /// de clave que la caché de la suscripción (el dueño legacy usa [base] tal
  /// cual, el resto `<base>_<sufijo>`). [base] es una de las claves
  /// `cloud*Key` de arriba, así [deleteUserData] la borra.
  Object? loadAccountValue(String base, String uid) {
    assert(_accountValueKeys.contains(base), 'Clave por cuenta no registrada: $base');
    return _settings.get(_accountKey(base, uid));
  }

  /// [value] null borra la clave.
  Future<void> saveAccountValue(String base, String uid, Object? value) async {
    assert(_accountValueKeys.contains(base), 'Clave por cuenta no registrada: $base');
    if (value == null) {
      await _settings.delete(_accountKey(base, uid));
    } else {
      await _settings.put(_accountKey(base, uid), value);
    }
  }

  /// Al eliminar la cuenta [uid] (ver `AuthService.deleteAccount`): borra del
  /// disco sus 4 cajones y sus claves de `settings_box`. Si estaban abiertos,
  /// primero los cierra. `legacy_owner_uid` no cambia: si era el dueño de los
  /// cajones de siempre, esos quedan vacíos.
  Future<void> deleteUserData(String uid) => _serialized(() async {
        await init();
        if (_openUid == uid) await _closeUserBoxesNow();
        for (final base in [_teamsBox, _matchesBox, _playsBox, _fixtureBox]) {
          await Hive.deleteBoxFromDisk(_accountKey(base, uid));
        }
        for (final base in {..._accountValueKeys, _subscriptionCacheKey, _freeStatsMatchIdKey}) {
          await _settings.delete(_accountKey(base, uid));
        }
      });

  // Qué estadística visual se muestra (Configuración → Estadística visual en
  // pantalla / del PDF, funciones premium). Si nunca se eligió nada, todo.
  // Cuál se usa de verdad lo decide `VisualStatsPreferences` (sin premium,
  // siempre todo).

  /// Gráficos que lleva el PDF del partido.
  Set<VisualChart> loadPdfVisualCharts() => _loadEnumSet(_pdfVisualChartsKey, VisualChart.values);
  Future<void> savePdfVisualCharts(Set<VisualChart> v) => _saveEnumSet(_pdfVisualChartsKey, VisualChart.values, v);

  /// Mapas de dirección (columnas de la planilla por jugador) que lleva el PDF.
  Set<ShotKind> loadPdfCourtMaps() => _loadEnumSet(_pdfCourtMapsKey, ShotKind.values);
  Future<void> savePdfCourtMaps(Set<ShotKind> v) => _saveEnumSet(_pdfCourtMapsKey, ShotKind.values, v);

  /// Gráficos que se ven en la pestaña "Gráficos" de Estadísticas.
  Set<VisualChart> loadScreenVisualCharts() => _loadEnumSet(_screenVisualChartsKey, VisualChart.values);
  Future<void> saveScreenVisualCharts(Set<VisualChart> v) =>
      _saveEnumSet(_screenVisualChartsKey, VisualChart.values, v);

  /// Mapas que se ven en la pestaña "Mapas" de Estadísticas.
  Set<ShotKind> loadScreenCourtMaps() => _loadEnumSet(_screenCourtMapsKey, ShotKind.values);
  Future<void> saveScreenCourtMaps(Set<ShotKind> v) => _saveEnumSet(_screenCourtMapsKey, ShotKind.values, v);

  /// Borra una clave de `settings_box` (para simular datos de una versión
  /// anterior en los tests).
  @visibleForTesting
  Future<void> debugRemoveSetting(String key) => _settings.delete(key);

  /// Valores de enum agregados después de que pudo haber selecciones
  /// guardadas sin una lista `_known` (ver [_loadEnumSet]).
  static const _enumValuesAddedLater = {'attackOrigin'};

  /// Se guarda la lista de nombres (no los índices) para que agregar o
  /// reordenar valores del enum no cambie lo que eligió el usuario, más la
  /// lista de valores que existían al guardar (`<clave>_known`): un valor
  /// nuevo (p. ej. un gráfico agregado en una versión posterior) aparece
  /// elegido hasta que el usuario lo saque, en vez de quedar oculto.
  Set<T> _loadEnumSet<T extends Enum>(String key, List<T> values) {
    final raw = _settings.get(key);
    if (raw is! List) return values.toSet();
    final names = raw.map((e) => e.toString()).toSet();
    final rawKnown = _settings.get('${key}_known');
    final known = rawKnown is List
        ? rawKnown.map((e) => e.toString()).toSet()
        : {for (final v in values) if (!_enumValuesAddedLater.contains(v.name)) v.name};
    return {for (final v in values) if (names.contains(v.name) || !known.contains(v.name)) v};
  }

  Future<void> _saveEnumSet<T extends Enum>(String key, List<T> values, Set<T> selected) async {
    await _settings.put(key, [for (final v in values) if (selected.contains(v)) v.name]);
    await _settings.put('${key}_known', [for (final v in values) v.name]);
  }
}
