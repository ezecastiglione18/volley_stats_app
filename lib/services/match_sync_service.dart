import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../legal/privacy_policy_text.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../state/app_data_controller.dart';
import '../state/match_controller.dart';
import '../utils/platform_support.dart';
import '../utils/sample_team.dart';
import 'storage_service.dart';

/// Las dos colecciones que viajan a la nube (por cuenta):
/// `matches/{uid}/user_matches/{matchId}` y `teams/{uid}/user_teams/{teamId}`.
enum SyncCollection { matches, teams }

/// Valor de `account_devices/{uid}.cloudSync`.
enum CloudSyncFlag {
  on,
  off,

  /// El campo no existe: nunca se le preguntó a la cuenta.
  unset,

  /// No se pudo leer (sin red) y no hay caché.
  unknown,
}

/// Un documento leído de la nube.
class RemoteDoc {
  final String id;
  final Map<String, dynamic> data;

  /// `serverUpdatedAt` (hora del servidor de la última escritura): solo se
  /// usa como cursor del pull.
  final DateTime serverUpdatedAt;

  /// Para pedir la página siguiente (en Firestore, el `DocumentSnapshot`).
  final Object? cursor;

  RemoteDoc(this.id, this.data, this.serverUpdatedAt, [this.cursor]);
}

/// Acceso a la nube que usa [MatchSyncService]. Interfaz para poder probar el
/// sync con un fake, sin Firebase (no hay `fake_cloud_firestore` en el
/// proyecto).
abstract class CloudSyncStore {
  /// Escribe (pisa) el documento [id] con [data] más `serverUpdatedAt` =
  /// hora del servidor. El SDK la encola si no hay red: el Future se
  /// resuelve recién cuando el servidor la confirma.
  Future<void> write(SyncCollection collection, String uid, String id, Map<String, dynamic> data);

  /// Documentos con `serverUpdatedAt` posterior a [since] (todos si es
  /// null), ordenados por `serverUpdatedAt`, de a [limit], empezando después
  /// de [after]. Siempre del servidor, nunca de la caché local.
  Future<List<RemoteDoc>> fetchChanged(
    SyncCollection collection,
    String uid, {
    DateTime? since,
    RemoteDoc? after,
    required int limit,
  });

  Future<void> delete(SyncCollection collection, String uid, String id);

  /// Borra la colección entera de [uid] (en batches).
  Future<void> deleteAll(SyncCollection collection, String uid);

  /// Borra los documentos con `deletedAt` anterior a [cutoff] (la purga de
  /// los 30 días del lado de la nube).
  Future<void> deleteTrashedBefore(SyncCollection collection, String uid, DateTime cutoff);

  Future<CloudSyncFlag> readFlag(String uid);

  /// Guarda el interruptor. Con [consentPolicyVersion] deja además registro
  /// de qué versión de la política aceptó la cuenta al activar la nube.
  Future<void> writeFlag(String uid, bool enabled, {String? consentPolicyVersion});
}

class FirestoreCloudSyncStore implements CloudSyncStore {
  /// Operaciones por batch al borrar (el máximo de Firestore es 500).
  static const batchSize = 400;
  static const _timeout = Duration(seconds: 30);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(SyncCollection c, String uid) =>
      c == SyncCollection.matches
          ? _db.collection('matches').doc(uid).collection('user_matches')
          : _db.collection('teams').doc(uid).collection('user_teams');

  @override
  Future<void> write(SyncCollection collection, String uid, String id, Map<String, dynamic> data) =>
      _col(collection, uid).doc(id).set({...data, 'serverUpdatedAt': FieldValue.serverTimestamp()});

  @override
  Future<List<RemoteDoc>> fetchChanged(
    SyncCollection collection,
    String uid, {
    DateTime? since,
    RemoteDoc? after,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> q = _col(collection, uid).orderBy('serverUpdatedAt');
    if (since != null) q = q.where('serverUpdatedAt', isGreaterThan: Timestamp.fromDate(since));
    final cursor = after?.cursor;
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.limit(limit).get(const GetOptions(source: Source.server)).timeout(_timeout);
    return [
      for (final d in snap.docs)
        if (d.data()['serverUpdatedAt'] is Timestamp)
          RemoteDoc(d.id, d.data(), (d.data()['serverUpdatedAt'] as Timestamp).toDate(), d),
    ];
  }

  @override
  Future<void> delete(SyncCollection collection, String uid, String id) =>
      _col(collection, uid).doc(id).delete();

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(batchSize).get(const GetOptions(source: Source.server)).timeout(_timeout);
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit().timeout(_timeout);
      if (snap.docs.length < batchSize) return;
    }
  }

  @override
  Future<void> deleteAll(SyncCollection collection, String uid) => _deleteQuery(_col(collection, uid));

  @override
  Future<void> deleteTrashedBefore(SyncCollection collection, String uid, DateTime cutoff) =>
      _deleteQuery(_col(collection, uid).where('deletedAt', isLessThan: Timestamp.fromDate(cutoff)));

  DocumentReference<Map<String, dynamic>> _account(String uid) =>
      _db.collection('account_devices').doc(uid);

  @override
  Future<CloudSyncFlag> readFlag(String uid) async {
    try {
      final snap = await _account(uid).get(const GetOptions(source: Source.server)).timeout(_timeout);
      final value = snap.data()?['cloudSync'];
      if (value is bool) return value ? CloudSyncFlag.on : CloudSyncFlag.off;
      return snap.exists ? CloudSyncFlag.unset : CloudSyncFlag.unknown;
    } catch (_) {
      return CloudSyncFlag.unknown;
    }
  }

  @override
  Future<void> writeFlag(String uid, bool enabled, {String? consentPolicyVersion}) =>
      // `update` y no `set`: si la cuenta ya no existe, no se recrea su documento.
      _account(uid).update({
        'cloudSync': enabled,
        if (consentPolicyVersion != null)
          'cloudConsent': {
            'privacyPolicyVersion': consentPolicyVersion,
            'acceptedAt': FieldValue.serverTimestamp(),
          },
      });
}

/// Sección 3, Etapa 2 de `documents/RallyStats-Funcionalidades-Pendientes.pdf`:
/// sync de los partidos terminados y los equipos (con sus jugadores, sin
/// fotos) con Firestore, si la cuenta activó la nube. Las jugadas y el
/// fixture no viajan (siguen en Exportar todo). Hive sigue siendo la fuente
/// de todo lo que se muestra: el sync solo copia de un lado al otro.
///
/// - [push]/[pushTeam]: sin esperar (el SDK de Firestore encola sin red).
/// - [uploadAll]: subida inicial al activar la nube, reanudable.
/// - [pull]: incremental, con el cursor en `serverUpdatedAt` (hora del
///   servidor). Gana el `updatedAt` más nuevo (null = el más viejo; empate:
///   no se toca); si lo local es más nuevo se vuelve a subir, para que una
///   escritura vieja encolada en otro dispositivo no deje la nube atrasada.
///   Una marca `deletedAt` manda el partido a la papelera (o el equipo a
///   ocultos): que algo falte en la nube nunca borra nada local.
/// - Nada escribe en Hive si mientras tanto cambió la cuenta abierta.
///
/// Free y premium por igual: ni la subida ni la bajada aplican el tope de 3.
/// En Windows ([isCloudSyncSupported]) no hace nada.
class MatchSyncService extends ChangeNotifier {
  MatchSyncService({
    required this.appData,
    CloudSyncStore? store,
    bool? platformSupported,
    this.pullMargin = const Duration(minutes: 2),
    this.pageSize = 20,
    this.uploadTimeout = const Duration(seconds: 30),
  })  : _storeOverride = store,
        supported = platformSupported ?? isCloudSyncSupported {
    appData.sync = this;
  }

  /// Un partido cuyo JSON pasa este tamaño no se sube (el límite de un
  /// documento de Firestore es 1 MiB; un partido de 5 sets con zonas y notas
  /// largas mide ~190 KB). Queda anotado para avisarlo en Configuración.
  static const maxDocumentBytes = 700 * 1024;

  final AppDataController appData;
  CloudSyncStore? _storeOverride;
  CloudSyncStore get _store => _storeOverride ??= FirestoreCloudSyncStore();

  /// false en Windows: no aparece el interruptor y no se sincroniza nada.
  final bool supported;

  /// Cuánto se retrocede el cursor en cada pull (aplicar dos veces el mismo
  /// documento no cambia nada).
  final Duration pullMargin;
  final int pageSize;

  /// Espera por documento en la subida inicial; si se pasa, la subida se
  /// pausa y se retoma la próxima vez.
  final Duration uploadTimeout;

  StorageService get _s => StorageService.instance;

  // ---------------- Conversiones ----------------

  static Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

  static String? _iso(Object? v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is String) return v;
    return null;
  }

  static List<Map<String, dynamic>> _playersWithoutPhotos(Object? players) => [
        for (final p in (players as List? ?? const []))
          {...Map<String, dynamic>.from(p as Map), 'photoPath': null},
      ];

  /// `VolleyMatch.toJson()` con las fechas del partido como `Timestamp` y sin
  /// las rutas de las fotos del plantel. Firestore no acepta listas dentro de
  /// listas, pero el JSON de un partido no tiene ninguna (las listas de
  /// eventos están dentro de los mapas de cada set): no hace falta convertir
  /// nada más. Nunca se usa para Hive.
  @visibleForTesting
  static Map<String, dynamic> matchToFirestoreJson(VolleyMatch match) {
    final json = match.toJson();
    json['date'] = Timestamp.fromDate(match.date);
    json['updatedAt'] = _ts(match.updatedAt);
    json['deletedAt'] = _ts(match.deletedAt);
    json['ownRoster'] = _playersWithoutPhotos(json['ownRoster']);
    return json;
  }

  @visibleForTesting
  static VolleyMatch matchFromFirestoreJson(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data)..remove('serverUpdatedAt');
    for (final key in const ['date', 'updatedAt', 'deletedAt']) {
      json[key] = _iso(json[key]);
    }
    return VolleyMatch.fromJson(json);
  }

  /// `Team.toJson()` (con sus jugadores) con `photoPath` en null y las
  /// fechas del equipo como `Timestamp`.
  @visibleForTesting
  static Map<String, dynamic> teamToFirestoreJson(Team team) {
    final json = team.toJson();
    json['players'] = _playersWithoutPhotos(json['players']);
    json['updatedAt'] = _ts(team.updatedAt);
    json['deletedAt'] = _ts(team.deletedAt);
    return json;
  }

  @visibleForTesting
  static Team teamFromFirestoreJson(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data)..remove('serverUpdatedAt');
    for (final key in const ['updatedAt', 'deletedAt']) {
      json[key] = _iso(json[key]);
    }
    return Team.fromJson(json);
  }

  /// Tamaño (bytes UTF-8) del JSON del partido: aproxima el del documento.
  static int documentBytes(VolleyMatch match) => utf8.encode(jsonEncode(match.toJson())).length;

  // ---------------- Estado por cuenta ----------------

  String? get _uid => appData.accountUid;

  /// Lo que eligió la cuenta abierta (caché de `account_devices/{uid}.cloudSync`
  /// para leerlo sin red), o null si nunca se le preguntó.
  bool? get cloudSyncSetting {
    final uid = _uid;
    if (uid == null) return null;
    final v = _s.loadAccountValue(StorageService.cloudSyncKey, uid);
    return v is bool ? v : null;
  }

  /// La nube está activada para la cuenta abierta (y la plataforma la
  /// soporta).
  bool get enabled => supported && _uid != null && cloudSyncSetting == true;

  DateTime? get lastSyncAt {
    final uid = _uid;
    if (uid == null) return null;
    return DateTime.tryParse(_s.loadAccountValue(StorageService.cloudLastSyncKey, uid) as String? ?? '');
  }

  /// Partidos que no se pudieron subir por tamaño.
  List<String> get oversizeMatchIds {
    final uid = _uid;
    if (uid == null) return const [];
    return [...(_s.loadAccountValue(StorageService.cloudOversizeKey, uid) as List? ?? const []).cast<String>()];
  }

  bool get initialUploadDone {
    final uid = _uid;
    return uid != null && _s.loadAccountValue(StorageService.cloudUploadDoneKey, uid) == true;
  }

  Future<void>? _pullFuture;
  Future<void>? _uploadFuture;
  String? _progressUid;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  bool get pulling => _pullFuture != null;
  bool get uploading => _uploadFuture != null && _progressUid == _uid;

  /// Progreso de la subida inicial ("Subiendo X de N"), de la cuenta abierta.
  int get uploadDone => _progressUid == _uid ? _uploadDone : 0;
  int get uploadTotal => _progressUid == _uid ? _uploadTotal : 0;

  _Session? _session() {
    final uid = _uid;
    return uid == null ? null : _Session(uid, _s.userDataToken);
  }

  /// La cuenta que lanzó la operación sigue siendo la abierta.
  bool _same(_Session session) =>
      appData.accountUid == session.uid && _s.userDataToken == session.token;

  Future<void> _saveValue(_Session session, String key, Object? value) async {
    if (!_same(session)) return;
    await _s.saveAccountValue(key, session.uid, value);
  }

  Future<void> _setOversize(_Session session, String matchId, bool oversize) async {
    final ids = oversizeMatchIds;
    if (oversize == ids.contains(matchId)) return;
    oversize ? ids.add(matchId) : ids.remove(matchId);
    await _saveValue(session, StorageService.cloudOversizeKey, ids);
    notifyListeners();
  }

  // ---------------- Push ----------------

  static bool _isUneditedSample(Team team) => team.id == kSampleTeamId && team.updatedAt == null;

  /// Sube un partido sin esperar. Solo partidos terminados (los en curso
  /// siguen pasando por Exportar/Importar) y con la nube activada. Si no
  /// entra en un documento, no se sube y queda anotado.
  void push(VolleyMatch match) {
    final session = _session();
    if (!enabled || session == null || match.status != MatchStatus.finished) return;
    final tooBig = documentBytes(match) > maxDocumentBytes;
    unawaited(_setOversize(session, match.id, tooBig));
    if (tooBig) return;
    _fireAndForget(_store.write(SyncCollection.matches, session.uid, match.id, matchToFirestoreJson(match)));
  }

  /// Sube un equipo sin esperar (siempre, salvo el de ejemplo sin editar).
  void pushTeam(Team team) {
    final session = _session();
    if (!enabled || session == null || _isUneditedSample(team)) return;
    _fireAndForget(_store.write(SyncCollection.teams, session.uid, team.id, teamToFirestoreJson(team)));
  }

  /// "Eliminar definitivamente" y la purga local: también en la nube.
  void deleteRemoteMatch(String matchId) {
    final session = _session();
    if (!enabled || session == null) return;
    _fireAndForget(_store.delete(SyncCollection.matches, session.uid, matchId));
  }

  void deleteRemoteTeam(String teamId) {
    final session = _session();
    if (!enabled || session == null) return;
    _fireAndForget(_store.delete(SyncCollection.teams, session.uid, teamId));
  }

  void _fireAndForget(Future<void> write) {
    unawaited(write.catchError((Object e) => debugPrint('MatchSyncService: no se pudo escribir ($e)')));
  }

  // ---------------- Pull ----------------

  /// 1 si [a] es más nueva que [b], -1 si es más vieja, 0 si empatan. Null
  /// cuenta como la más vieja.
  static int _compare(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.microsecondsSinceEpoch.compareTo(b.microsecondsSinceEpoch);
  }

  /// Las fotos no viajan: cada jugador que ya existe acá (mismo `Player.id`)
  /// conserva la suya si el archivo está en este dispositivo; los nuevos
  /// quedan sin foto.
  void _keepLocalPhotos(List<Player> incoming, Iterable<Player> local) {
    final photos = <String, String>{
      for (final p in local)
        if (p.photoPath != null && File(p.photoPath!).existsSync()) p.id: p.photoPath!,
    };
    for (final p in incoming) {
      p.photoPath = photos[p.id];
    }
  }

  Iterable<Player> _localPlayers() sync* {
    for (final t in [...appData.teams, ...appData.hiddenTeams]) {
      yield* t.players;
    }
  }

  /// Baja lo que cambió en la nube desde el último pull: primero equipos,
  /// después partidos. Sin red o con la nube apagada no hace nada. Si ya hay
  /// uno en curso, devuelve ese.
  Future<void> pull() {
    if (!enabled) return Future.value();
    final running = _pullFuture;
    if (running != null) return running;
    final future = _pull();
    _pullFuture = future;
    notifyListeners();
    return future.whenComplete(() {
      _pullFuture = null;
      notifyListeners();
    });
  }

  Future<void> _pull() async {
    final session = _session();
    if (session == null) return;
    // El interruptor es por cuenta: si se apagó desde otro dispositivo, acá
    // también deja de bajar y de subir.
    final flag = await _store.readFlag(session.uid);
    if (!_same(session)) return;
    if (flag == CloudSyncFlag.off) {
      await _saveValue(session, StorageService.cloudSyncKey, false);
      notifyListeners();
      return;
    }
    try {
      await _pullCollection(SyncCollection.teams, session);
      if (!_same(session)) return;
      await _pullCollection(SyncCollection.matches, session);
      await _saveValue(session, StorageService.cloudLastSyncKey, DateTime.now().toIso8601String());
    } on UserDataClosedError {
      // Se cerró la sesión en el medio: no se escribió nada en la otra cuenta.
    } catch (e) {
      debugPrint('MatchSyncService: no se pudo bajar de la nube ($e)');
    }
  }

  Future<void> _pullCollection(SyncCollection collection, _Session session) async {
    final key = collection == SyncCollection.matches
        ? StorageService.cloudCursorMatchesKey
        : StorageService.cloudCursorTeamsKey;
    final cursor = DateTime.tryParse(_s.loadAccountValue(key, session.uid) as String? ?? '');
    final since = cursor?.subtract(pullMargin);
    var newCursor = cursor;
    var skipped = false;
    RemoteDoc? after;
    while (true) {
      final page = await _store.fetchChanged(collection, session.uid,
          since: since, after: after, limit: pageSize);
      if (!_same(session)) return;
      for (final doc in page) {
        final handled = collection == SyncCollection.matches
            ? await _applyMatch(doc, session)
            : await _applyTeam(doc, session);
        if (!_same(session)) return;
        if (!handled) {
          // Partido abierto en la carga en vivo: el cursor no lo pasa, así el
          // próximo pull lo vuelve a traer y lo aplica.
          skipped = true;
        } else if (!skipped && (newCursor == null || doc.serverUpdatedAt.isAfter(newCursor))) {
          newCursor = doc.serverUpdatedAt;
        }
      }
      if (newCursor != null) await _saveValue(session, key, newCursor.toIso8601String());
      if (page.length < pageSize) return;
      after = page.last;
    }
  }

  /// Aplica un partido de la nube. Devuelve false si lo salteó por estar
  /// abierto en la carga en vivo.
  Future<bool> _applyMatch(RemoteDoc doc, _Session session) async {
    final remote = matchFromFirestoreJson(doc.data);
    final local = appData.findMatch(remote.id);
    if (local != null) {
      final cmp = _compare(remote.updatedAt, local.updatedAt);
      if (cmp == 0) return true;
      if (cmp < 0) {
        // Lo local es más nuevo: la nube quedó atrás (por ejemplo, una
        // escritura vieja encolada en otro dispositivo). Se vuelve a subir.
        push(local);
        return true;
      }
      if (MatchController.isOpen(remote.id)) return false;
    }
    _keepLocalPhotos(remote.ownRoster, [...?local?.ownRoster, ..._localPlayers()]);
    // isPremium no importa: con syncToCloud en false no aplica el tope.
    await appData.saveMatch(remote, isPremium: true, syncToCloud: false, sessionToken: session.token);
    return true;
  }

  Future<bool> _applyTeam(RemoteDoc doc, _Session session) async {
    final remote = teamFromFirestoreJson(doc.data);
    final local = appData.findTeam(remote.id);
    if (local != null) {
      final cmp = _compare(remote.updatedAt, local.updatedAt);
      if (cmp == 0) return true;
      if (cmp < 0) {
        pushTeam(local);
        return true;
      }
    }
    _keepLocalPhotos(remote.players, [...?local?.players, ..._localPlayers()]);
    await appData.saveTeam(remote, syncToCloud: false, sessionToken: session.token);
    return true;
  }

  // ---------------- Subida inicial ----------------

  /// Sube todos los equipos y después todos los partidos terminados (también
  /// los de la papelera, con su marca), sin tope. Primero baja lo que ya hay
  /// en la nube, para no pisar una versión más nueva. Reanudable: anota cada
  /// documento confirmado por el servidor y la próxima vez sube solo los que
  /// faltan. Si se corta (sin red), se retoma al volver a abrir la app.
  Future<void> uploadAll() {
    if (!enabled) return Future.value();
    final running = _uploadFuture;
    if (running != null) return running;
    final future = _uploadAll();
    _uploadFuture = future;
    return future.whenComplete(() {
      _uploadFuture = null;
      notifyListeners();
    });
  }

  Future<void> _uploadAll() async {
    final session = _session();
    if (session == null) return;
    await pull();
    if (!_same(session) || !enabled) return;
    final uploaded = <String>{
      ...(_s.loadAccountValue(StorageService.cloudUploadedKey, session.uid) as List? ?? const []).cast<String>(),
    };
    final items = <(String, Future<void> Function())>[
      for (final t in [...appData.teams, ...appData.hiddenTeams])
        if (!_isUneditedSample(t))
          ('t:${t.id}', () => _store.write(SyncCollection.teams, session.uid, t.id, teamToFirestoreJson(t))),
      for (final m in [...appData.matches, ...appData.trashedMatches])
        if (m.status == MatchStatus.finished)
          ('m:${m.id}', () async {
            final tooBig = documentBytes(m) > maxDocumentBytes;
            await _setOversize(session, m.id, tooBig);
            if (!tooBig) {
              await _store.write(SyncCollection.matches, session.uid, m.id, matchToFirestoreJson(m));
            }
          }),
    ];
    _progressUid = session.uid;
    _uploadTotal = items.length;
    _uploadDone = items.where((i) => uploaded.contains(i.$1)).length;
    notifyListeners();
    for (final (key, upload) in items) {
      if (uploaded.contains(key)) continue;
      if (!_same(session) || !enabled) return;
      try {
        await upload().timeout(uploadTimeout);
      } catch (e) {
        debugPrint('MatchSyncService: subida inicial en pausa ($e); se retoma la próxima vez.');
        return;
      }
      if (!_same(session)) return;
      uploaded.add(key);
      await _saveValue(session, StorageService.cloudUploadedKey, uploaded.toList());
      _uploadDone++;
      notifyListeners();
    }
    await _saveValue(session, StorageService.cloudUploadDoneKey, true);
  }

  /// "Hacer una copia ahora" (Configuración, debajo del interruptor): aunque
  /// todo ya se sube solo, vuelve a subir todos los equipos y partidos
  /// terminados, después de bajar lo nuevo (así no pisa una versión más
  /// nueva de otro dispositivo). Devuelve true si terminó; false sin
  /// conexión o si se cortó (lo que quedó pendiente se retoma solo, como la
  /// subida inicial).
  Future<bool> backupNow() async {
    final session = _session();
    if (!enabled || session == null) return false;
    // Sin red se avisa enseguida, en vez de esperar a que venza cada subida.
    final flag = await _store.readFlag(session.uid);
    if (!_same(session) || flag == CloudSyncFlag.unknown) return false;
    final running = _uploadFuture;
    if (running != null) await running;
    await _saveValue(session, StorageService.cloudUploadedKey, null);
    await _saveValue(session, StorageService.cloudUploadDoneKey, null);
    await uploadAll();
    return _same(session) && initialUploadDone;
  }

  // ---------------- Interruptor ----------------

  /// Al abrir los datos de la cuenta (y con la app ya en Inicio): baja lo
  /// nuevo, purga en la nube lo que lleva más de 30 días borrado y, si la
  /// subida inicial quedó a medias, la retoma.
  Future<void> onAccountReady() async {
    if (!enabled) return;
    final session = _session()!;
    await pull();
    if (!_same(session)) return;
    await purgeRemote();
    if (_same(session) && !initialUploadDone) await uploadAll();
  }

  /// Purga del lado de la nube (la local la hace `AppDataController.purgeExpired`).
  Future<void> purgeRemote() async {
    final session = _session();
    if (!enabled || session == null) return;
    final cutoff = appData.now().subtract(AppDataController.trashRetention);
    try {
      for (final c in SyncCollection.values) {
        await _store.deleteTrashedBefore(c, session.uid, cutoff);
      }
    } catch (e) {
      debugPrint('MatchSyncService: no se pudo purgar la nube ($e)');
    }
  }

  /// Qué eligió la cuenta, consultando `account_devices/{uid}` (y
  /// actualizando la caché). Sin red devuelve la caché, o
  /// [CloudSyncFlag.unknown] si no hay.
  Future<CloudSyncFlag> refreshFlag() async {
    final session = _session();
    if (!supported || session == null) return CloudSyncFlag.unknown;
    final remote = await _store.readFlag(session.uid);
    if (!_same(session)) return CloudSyncFlag.unknown;
    final cached = cloudSyncSetting;
    if (remote == CloudSyncFlag.on || remote == CloudSyncFlag.off) {
      await _saveValue(session, StorageService.cloudSyncKey, remote == CloudSyncFlag.on);
      notifyListeners();
      return remote;
    }
    if (cached == null) return remote;
    if (remote == CloudSyncFlag.unset) {
      // Este dispositivo ya contestó pero la escritura no llegó: se reintenta.
      unawaited(_store.writeFlag(session.uid, cached).catchError((Object _) {}));
    }
    return cached ? CloudSyncFlag.on : CloudSyncFlag.off;
  }

  /// Activa o apaga la nube para la cuenta abierta (en todos sus
  /// dispositivos). Activarla deja registro de la versión de la política
  /// aceptada y lanza [uploadAll]. Apagarla deja de subir y de bajar; con
  /// [deleteRemoteCopy] además borra la copia de la nube (partidos y
  /// equipos). Nunca toca lo local.
  Future<void> setCloudSync(bool on, {bool deleteRemoteCopy = false}) async {
    final session = _session();
    if (!supported || session == null) return;
    await _saveValue(session, StorageService.cloudSyncKey, on);
    if (!on) {
      // La próxima vez que se active, todo vuelve a subir y a bajar de cero.
      for (final key in const [
        StorageService.cloudCursorMatchesKey,
        StorageService.cloudCursorTeamsKey,
        StorageService.cloudUploadedKey,
        StorageService.cloudUploadDoneKey,
        StorageService.cloudOversizeKey,
      ]) {
        await _saveValue(session, key, null);
      }
    }
    notifyListeners();
    try {
      await _store
          .writeFlag(session.uid, on, consentPolicyVersion: on ? kPrivacyPolicyVersion : null)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Sin red queda encolada en el SDK (y la caché ya está); refreshFlag la
      // reintenta si no llegó.
      debugPrint('MatchSyncService: no se pudo guardar el interruptor ($e)');
    }
    if (on) {
      unawaited(uploadAll());
    } else if (deleteRemoteCopy) {
      await deleteAllRemote(session.uid);
    }
  }

  /// Borra `matches/{uid}` y `teams/{uid}` (al apagar la nube eligiendo
  /// borrar la copia, y al eliminar la cuenta). Necesita red: si falla,
  /// lanza.
  Future<void> deleteAllRemote(String uid) async {
    await _store.deleteAll(SyncCollection.matches, uid);
    await _store.deleteAll(SyncCollection.teams, uid);
  }
}

class _Session {
  final String uid;
  final int token;
  _Session(this.uid, this.token);
}
