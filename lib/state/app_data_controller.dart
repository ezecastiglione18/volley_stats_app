import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/fixture_entry.dart';
import '../models/play.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../services/free_stats_quota_store.dart';
import '../services/full_backup.dart';
import '../services/match_sync_service.dart';
import '../services/storage_service.dart';
import '../utils/app_version.dart';
import '../utils/sample_team.dart';

/// Se lanza al intentar guardar un partido nuevo (no una actualización de
/// uno ya guardado), o al restaurar uno de la papelera, cuando la cuenta no
/// es premium y el archivo ya llegó al tope de 3 partidos de la versión free.
class MatchArchiveLimitException implements Exception {
  @override
  String toString() =>
      'La versión free permite hasta 3 partidos en el archivo. Suscribite a premium '
      'para guardar partidos ilimitados.';
}

/// Estado global de la app: lista de equipos precargados, archivo de
/// partidos y archivo de jugadas de pizarra guardados de la cuenta logueada.
/// Se mantiene en memoria y se sincroniza con Hive (y, si la cuenta activó
/// la nube, con Firestore vía [sync]).
///
/// Papelera: un partido eliminado no se borra, pasa a [trashedMatches]
/// (`deletedAt`) y se purga a los 30 días. [matches] nunca lo incluye, así
/// que lo ignora todo lo que lee el archivo (scouting, temporada, impacto,
/// comparador, CSV, fixture, cupo free y tope de 3). Lo mismo con los equipos
/// borrados: salen de [teams] y quedan en [hiddenTeams] hasta la purga.
class AppDataController extends ChangeNotifier {
  /// Tope de partidos en el archivo de la versión free (por cuenta: cada
  /// cuenta tiene sus propios cajones).
  static const freeMatchLimit = 3;

  /// Cuánto queda un partido en la papelera (o un equipo borrado oculto)
  /// antes de borrarse definitivamente.
  static const trashRetention = Duration(days: 30);

  AppDataController({FreeStatsQuotaStore? quotaStore, DateTime Function()? clock})
      : _quotaStore = quotaStore,
        _clock = clock ?? DateTime.now;

  /// Se crea recién al usarse: los tests arman este controlador sin Firebase.
  FreeStatsQuotaStore? _quotaStore;
  FreeStatsQuotaStore get _quota => _quotaStore ??= FirestoreFreeStatsQuotaStore();

  final DateTime Function() _clock;

  /// Hora "de ahora" (reemplazable en tests para la purga).
  DateTime now() => _clock();

  /// Sync con la nube. Lo conecta `main.dart` (y los tests que lo prueban);
  /// null = sin sync. Todos los disparadores pasan por acá y el servicio
  /// decide si corresponde (nube activada, partido terminado).
  MatchSyncService? sync;

  /// Equipos visibles (sin los borrados).
  List<Team> teams = [];

  /// Equipos borrados (`deletedAt`): no se muestran en ningún lado, se
  /// conservan hasta la purga para que el borrado viaje a los otros
  /// dispositivos y no "resucite" con una copia vieja.
  List<Team> hiddenTeams = [];

  /// Archivo de partidos, sin los de la papelera.
  List<VolleyMatch> matches = [];

  /// Papelera, del borrado más reciente al más viejo.
  List<VolleyMatch> trashedMatches = [];

  List<Play> plays = [];

  /// Fixture (partidos por jugar), por fecha ascendente.
  List<FixtureEntry> fixtureEntries = [];

  /// Id del partido que ya consumió el único cupo de estadística de la
  /// versión free (ver [registerFreeStatsUsage]). `null` si todavía no se
  /// generó ninguna.
  String? freeStatsMatchId;

  /// Cuenta cuyos datos están cargados, o `null` (antes del login, después
  /// de cerrar sesión).
  String? accountUid;

  /// Abre los cajones de [uid], carga sus datos y purga lo que lleva más de
  /// 30 días en la papelera (ver `_AccountDataGate` en `main.dart`: corre
  /// recién con la sesión ya validada).
  Future<void> openAccount(String uid) async {
    await StorageService.instance.openUserBoxes(uid);
    await loadAll();
    await purgeExpired();
  }

  /// Carga en memoria los datos de la cuenta con los cajones abiertos.
  Future<void> loadAll() async {
    final s = StorageService.instance;
    final uid = s.openUid;
    if (uid == null) {
      throw UserDataClosedError('No hay una cuenta con los datos abiertos para cargar (loadAll).');
    }
    final allTeams = s.loadTeams();
    teams = allTeams.where((t) => t.deletedAt == null).toList();
    hiddenTeams = allTeams.where((t) => t.deletedAt != null).toList();
    final allMatches = s.loadMatches();
    matches = allMatches.where((m) => m.deletedAt == null).toList();
    trashedMatches = allMatches.where((m) => m.deletedAt != null).toList();
    _sortTrash();
    plays = s.loadPlays();
    fixtureEntries = s.loadFixtureEntries();
    freeStatsMatchId = s.loadFreeStatsMatchId(uid);
    accountUid = uid;
    notifyListeners();
  }

  /// Al cerrar sesión (después de volver a la primera pantalla): vacía las
  /// listas en memoria y cierra los cajones. Nunca borra nada del disco.
  Future<void> closeAccount() async {
    accountUid = null;
    teams = [];
    hiddenTeams = [];
    matches = [];
    trashedMatches = [];
    plays = [];
    fixtureEntries = [];
    freeStatsMatchId = null;
    notifyListeners();
    await StorageService.instance.closeUserBoxes();
  }

  // ---------------- Equipos ----------------

  /// El equipo [id], visible u oculto (borrado), o null.
  Team? findTeam(String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    for (final t in hiddenTeams) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _placeTeam(Team team) {
    teams.removeWhere((t) => t.id == team.id);
    hiddenTeams.removeWhere((t) => t.id == team.id);
    if (team.deletedAt == null) {
      teams.add(team);
      teams.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      hiddenTeams.add(team);
    }
  }

  /// Guarda un equipo (alta o edición) y estampa `updatedAt`. Con
  /// [syncToCloud] en false (lo que llega del pull, ver `MatchSyncService`)
  /// conserva el `updatedAt` remoto y no se vuelve a subir; [sessionToken]
  /// hace que falle en vez de escribir si mientras tanto cambió la cuenta.
  Future<void> saveTeam(Team team, {bool syncToCloud = true, int? sessionToken}) async {
    if (syncToCloud) team.updatedAt = now();
    await StorageService.instance.saveTeam(team, sessionToken: sessionToken);
    _placeTeam(team);
    notifyListeners();
    if (syncToCloud) sync?.pushTeam(team);
  }

  /// Borra un equipo: lo oculta (`deletedAt`) en este y en los otros
  /// dispositivos, y se purga a los 30 días. Los partidos que lo usaron no
  /// cambian (guardan su propia copia del plantel).
  Future<void> deleteTeam(String teamId) async {
    final team = findTeam(teamId);
    if (team == null || team.deletedAt != null) return;
    final t = now();
    team.deletedAt = t;
    team.updatedAt = t;
    await StorageService.instance.saveTeam(team);
    _placeTeam(team);
    notifyListeners();
    sync?.pushTeam(team);
  }

  /// "Cargar equipo de ejemplo". Devuelve false si ya existe (por id o por
  /// nombre). Se crea con `updatedAt` null para que no se suba a la nube
  /// hasta que se edite (ver `buildSampleTeam`); si estaba borrado, volver a
  /// cargarlo es una edición explícita: se revive con `updatedAt` = ahora.
  Future<bool> addSampleTeam() async {
    if (teams.any((t) => t.id == kSampleTeamId || t.name == kSampleTeamName)) return false;
    final wasDeleted = hiddenTeams.any((t) => t.id == kSampleTeamId);
    final team = buildSampleTeam();
    if (wasDeleted) {
      await saveTeam(team);
    } else {
      await StorageService.instance.saveTeam(team);
      _placeTeam(team);
      notifyListeners();
    }
    return true;
  }

  // ---------------- Partidos ----------------

  /// El partido [id], en el archivo o en la papelera, o null.
  VolleyMatch? findMatch(String id) {
    for (final m in matches) {
      if (m.id == id) return m;
    }
    for (final m in trashedMatches) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _sortTrash() => trashedMatches.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  void _placeMatch(VolleyMatch match) {
    matches.removeWhere((m) => m.id == match.id);
    trashedMatches.removeWhere((m) => m.id == match.id);
    if (match.deletedAt == null) {
      matches.add(match);
      matches.sort((a, b) => b.date.compareTo(a.date));
    } else {
      trashedMatches.add(match);
      _sortTrash();
    }
  }

  /// [isPremium] es obligatorio a propósito: fuerza a que cada lugar que
  /// crea/guarda un partido pase el estado de suscripción actual, para que
  /// el tope de 3 partidos de la versión free (sólo aplica a partidos
  /// *nuevos*, no a actualizar uno ya contado) no se pueda pisar por
  /// descuido.
  ///
  /// Estampa `updatedAt` = ahora y lo sube a la nube (si corresponde). Con
  /// [syncToCloud] en false (lo que llega del pull, ver `MatchSyncService`)
  /// conserva el `updatedAt` remoto, no se vuelve a subir y no aplica el
  /// tope: la bajada nunca deja afuera un partido de la cuenta.
  /// [sessionToken] hace que falle en vez de escribir si mientras tanto
  /// cambió la cuenta abierta.
  Future<void> saveMatch(
    VolleyMatch match, {
    required bool isPremium,
    bool syncToCloud = true,
    int? sessionToken,
  }) async {
    final isNew = findMatch(match.id) == null;
    if (syncToCloud && isNew && match.deletedAt == null && !isPremium && matches.length >= freeMatchLimit) {
      throw MatchArchiveLimitException();
    }
    if (syncToCloud) match.updatedAt = now();
    await StorageService.instance.saveMatch(match, sessionToken: sessionToken);
    _placeMatch(match);
    notifyListeners();
    if (syncToCloud) sync?.push(match);
  }

  /// "Eliminar" (también "Abandonar partido" en la carga en vivo): manda el
  /// partido a la papelera. No toca el fixture: mientras está en la
  /// papelera, la fila cuenta como "sin jugar" ([linkedMatchOf] no lo
  /// encuentra) y al restaurarlo vuelve a figurar como jugada.
  Future<void> trashMatch(String matchId) async {
    final idx = matches.indexWhere((m) => m.id == matchId);
    if (idx == -1) return;
    final match = matches[idx];
    final t = now();
    match.deletedAt = t;
    match.updatedAt = t;
    await StorageService.instance.saveMatch(match);
    _placeMatch(match);
    notifyListeners();
    sync?.push(match);
  }

  /// Saca un partido de la papelera. Sin premium respeta el tope de 3: si el
  /// archivo está lleno lanza [MatchArchiveLimitException] y el partido
  /// sigue en la papelera (si no, borrar y restaurar esquivaría el tope).
  Future<void> restoreMatch(String matchId, {required bool isPremium}) async {
    final idx = trashedMatches.indexWhere((m) => m.id == matchId);
    if (idx == -1) return;
    if (!isPremium && matches.length >= freeMatchLimit) throw MatchArchiveLimitException();
    final match = trashedMatches[idx];
    match.deletedAt = null;
    match.updatedAt = now();
    await StorageService.instance.saveMatch(match);
    _placeMatch(match);
    notifyListeners();
    sync?.push(match);
  }

  /// "Eliminar definitivamente" (desde la papelera, y la purga de los 30
  /// días): borra el partido de este dispositivo y de la nube. Las filas del
  /// fixture que apuntaban a él vuelven a quedar "sin jugar". En los otros
  /// dispositivos sigue en la papelera hasta su propia purga (que falte en la
  /// nube nunca significa borrarlo).
  Future<void> deleteMatch(String matchId) async {
    await StorageService.instance.deleteMatch(matchId);
    matches.removeWhere((m) => m.id == matchId);
    trashedMatches.removeWhere((m) => m.id == matchId);
    // Si el partido salía de una fila del fixture, esa fila vuelve a quedar
    // "sin jugar" (no se borra: el partido por jugar sigue existiendo).
    for (final entry in fixtureEntries.where((e) => e.linkedMatchId == matchId)) {
      entry.linkedMatchId = null;
      await StorageService.instance.saveFixtureEntry(entry);
    }
    notifyListeners();
    sync?.deleteRemoteMatch(matchId);
  }

  /// Días que le quedan a [match] en la papelera (0 = se purga en el próximo
  /// arranque).
  int trashDaysLeft(VolleyMatch match) {
    final deletedAt = match.deletedAt;
    if (deletedAt == null) return trashRetention.inDays;
    final left = deletedAt.add(trashRetention).difference(now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  /// Borra definitivamente lo que lleva más de 30 días en la papelera y los
  /// equipos borrados hace más de 30 días, acá y en la nube. Corre al abrir
  /// los datos de la cuenta ([openAccount]).
  Future<void> purgeExpired() async {
    final cutoff = now().subtract(trashRetention);
    for (final m in trashedMatches.where((m) => m.deletedAt!.isBefore(cutoff)).toList()) {
      await deleteMatch(m.id);
    }
    final expiredTeams = hiddenTeams.where((t) => t.deletedAt!.isBefore(cutoff)).toList();
    for (final t in expiredTeams) {
      await StorageService.instance.deleteTeam(t.id);
      hiddenTeams.removeWhere((h) => h.id == t.id);
      sync?.deleteRemoteTeam(t.id);
    }
    if (expiredTeams.isNotEmpty) notifyListeners();
  }

  // ---------------- Fixture ----------------

  Future<void> saveFixtureEntry(FixtureEntry entry) async {
    await StorageService.instance.saveFixtureEntry(entry);
    final idx = fixtureEntries.indexWhere((e) => e.id == entry.id);
    if (idx == -1) {
      fixtureEntries.add(entry);
    } else {
      fixtureEntries[idx] = entry;
    }
    fixtureEntries.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  Future<void> deleteFixtureEntry(String entryId) async {
    await StorageService.instance.deleteFixtureEntry(entryId);
    fixtureEntries.removeWhere((e) => e.id == entryId);
    notifyListeners();
  }

  /// Vincula la fila [entryId] del fixture con el partido [matchId] recién
  /// creado a partir de ella (queda como "jugada"). No-op si la fila ya no
  /// existe (se borró mientras se armaba el partido).
  Future<void> linkFixtureEntryToMatch(String entryId, String matchId) async {
    final idx = fixtureEntries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    fixtureEntries[idx].linkedMatchId = matchId;
    await StorageService.instance.saveFixtureEntry(fixtureEntries[idx]);
    notifyListeners();
  }

  /// El partido de la fila [entry], si todavía existe en el archivo. Una fila
  /// cuyo `linkedMatchId` apunta a un partido que ya no está (o que está en
  /// la papelera) cuenta como "sin jugar".
  VolleyMatch? linkedMatchOf(FixtureEntry entry) {
    final id = entry.linkedMatchId;
    if (id == null) return null;
    for (final m in matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Marca [matchId] como el partido que gastó el único cupo de estadística
  /// free, tras la confirmación explícita del usuario (ver
  /// `_FreeStatsConfirmScreen` en `MatchSummaryScreen` — no se llama por el
  /// solo hecho de entrar a mirar). No-op si el cupo ya estaba gastado (con
  /// este mismo partido o con otro). El registro persiste aunque el partido
  /// se borre del archivo después.
  ///
  /// El cupo es uno por cuenta en todos sus dispositivos: se registra en
  /// Firestore "solo si no existe" ([FreeStatsQuotaStore.claimIfAbsent]); si
  /// otro dispositivo ya había registrado otro partido, gana ese y es el que
  /// queda acá. Necesita red: sin conexión lanza [FreeStatsOfflineException]
  /// y no registra nada.
  Future<void> registerFreeStatsUsage(String matchId) async {
    if (freeStatsMatchId != null) return;
    final uid = accountUid;
    if (uid == null) {
      throw UserDataClosedError('No hay una cuenta abierta para registrar la estadística gratis.');
    }
    final winner = await _quota.claimIfAbsent(uid, matchId);
    // La caché es de esa cuenta aunque mientras tanto se haya cerrado la
    // sesión: el registro en el servidor ya quedó hecho.
    await StorageService.instance.saveFreeStatsMatchId(uid, winner);
    if (accountUid != uid) return;
    freeStatsMatchId = winner;
    notifyListeners();
  }

  /// Al loguearse (con los cajones ya abiertos): trae el cupo registrado en
  /// Firestore y actualiza la caché local. Migración de instalaciones
  /// viejas: si en el servidor no hay nada pero la caché local tiene un id
  /// (el cupo se gastó cuando era por dispositivo), se sube con la misma
  /// regla "solo si no existe". Sin red no hace nada: queda la caché.
  Future<void> syncFreeStatsQuota() async {
    final uid = accountUid;
    if (uid == null) return;
    try {
      var registered = await _quota.read(uid);
      final cached = StorageService.instance.loadFreeStatsMatchId(uid);
      if (registered == null && cached != null) {
        registered = await _quota.claimIfAbsent(uid, cached);
      }
      if (registered == null) return;
      await StorageService.instance.saveFreeStatsMatchId(uid, registered);
      if (accountUid == uid && freeStatsMatchId != registered) {
        freeStatsMatchId = registered;
        notifyListeners();
      }
    } on FreeStatsOfflineException catch (e) {
      debugPrint('AppDataController: no se pudo sincronizar el cupo free (${e.cause}).');
    }
  }

  // ---------------- Copia completa ----------------

  /// Todos los datos de la cuenta abierta en el formato de [FullBackup]
  /// ("Exportar todo"), incluidos la papelera y los equipos borrados (viajan
  /// con su `deletedAt` y al importarlos vuelven a quedar así).
  Map<String, dynamic> buildBackupJson() => FullBackup.buildJson(
        teams: [...teams, ...hiddenTeams],
        matches: [...matches, ...trashedMatches],
        plays: plays,
        fixture: fixtureEntries,
        createdAt: DateTime.now(),
        appVersion: kAppVersion,
      );

  /// Agrega a la cuenta abierta lo que trae [backup] y todavía no existe
  /// (por id, contando también la papelera y los equipos borrados). Nunca
  /// pisa ni borra nada. Con [applyFreeCap] ("Importar copia completa" sin
  /// premium) los partidos respetan el tope de [freeMatchLimit], igual que al
  /// crear uno (entran primero los más recientes; los que vienen en la
  /// papelera no ocupan lugar); "Restaurar copia automática" lo llama sin
  /// tope, porque son datos que ya estaban en este dispositivo. Lo que entra
  /// conserva su `updatedAt` y se sube a la nube si está activada.
  Future<ImportSummary> importBackup(FullBackup backup, {required bool applyFreeCap}) async {
    final s = StorageService.instance;
    final summary = ImportSummary();
    final addedTeams = <Team>[];
    final addedMatches = <VolleyMatch>[];

    final teamIds = {for (final t in [...teams, ...hiddenTeams]) t.id};
    for (final t in backup.teams) {
      if (!teamIds.add(t.id)) {
        summary.alreadyExisted++;
        continue;
      }
      _dropMissingPhotos(t);
      await s.saveTeam(t);
      _placeTeam(t);
      addedTeams.add(t);
      summary.teams++;
    }

    final matchIds = {for (final m in [...matches, ...trashedMatches]) m.id};
    final incoming = [...backup.matches]..sort((a, b) => b.date.compareTo(a.date));
    for (final m in incoming) {
      if (matchIds.contains(m.id)) {
        summary.alreadyExisted++;
        continue;
      }
      if (applyFreeCap && m.deletedAt == null && matches.length >= freeMatchLimit) {
        summary.matchesSkippedByCap++;
        continue;
      }
      matchIds.add(m.id);
      await s.saveMatch(m);
      _placeMatch(m);
      addedMatches.add(m);
      summary.matches++;
    }

    final playIds = {for (final p in plays) p.id};
    for (final p in backup.plays) {
      if (!playIds.add(p.id)) {
        summary.alreadyExisted++;
        continue;
      }
      await s.savePlay(p);
      plays.add(p);
      summary.plays++;
    }

    // Una fila cuyo partido quedó afuera por el tope cuenta como "sin jugar"
    // (ver [linkedMatchOf]); no hace falta tocarla.
    final fixtureIds = {for (final e in fixtureEntries) e.id};
    for (final e in backup.fixture) {
      if (!fixtureIds.add(e.id)) {
        summary.alreadyExisted++;
        continue;
      }
      await s.saveFixtureEntry(e);
      fixtureEntries.add(e);
      summary.fixture++;
    }

    plays.sort((a, b) => b.date.compareTo(a.date));
    fixtureEntries.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    for (final t in addedTeams) {
      sync?.pushTeam(t);
    }
    for (final m in addedMatches) {
      sync?.push(m);
    }
    return summary;
  }

  /// Las fotos no viajan en la copia (solo su ruta local): si el archivo no
  /// está en este dispositivo, el jugador queda sin foto en vez de apuntar a
  /// una imagen que no existe.
  void _dropMissingPhotos(Team team) {
    for (final p in team.players) {
      final path = p.photoPath;
      if (path != null && !File(path).existsSync()) p.photoPath = null;
    }
  }

  Future<void> savePlay(Play play) async {
    await StorageService.instance.savePlay(play);
    final idx = plays.indexWhere((p) => p.id == play.id);
    if (idx == -1) {
      plays.add(play);
    } else {
      plays[idx] = play;
    }
    plays.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deletePlay(String playId) async {
    await StorageService.instance.deletePlay(playId);
    plays.removeWhere((p) => p.id == playId);
    notifyListeners();
  }
}
