import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../legal/privacy_policy_text.dart';
import '../models/fixture_entry.dart';
import '../models/play.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../state/app_data_controller.dart';
import '../state/match_controller.dart';
import '../utils/platform_support.dart';
import '../utils/sample_team.dart';
import 'storage_service.dart';

/// Las colecciones que viajan a la nube (por cuenta):
/// `matches/{uid}/user_matches/{matchId}`, `teams/{uid}/user_teams/{teamId}`,
/// `plays/{uid}/user_plays/{playId}` (jugadas de la pizarra) y
/// `fixture/{uid}/user_fixture/{entryId}`.
enum SyncCollection { matches, teams, plays, fixture }

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

  /// Versión de la política que la cuenta aceptó al activar la nube
  /// (`cloudConsent.privacyPolicyVersion`), del servidor; null si no hay o
  /// no se pudo leer.
  Future<String?> readConsentVersion(String uid);

  /// Guarda el interruptor. Con [consentPolicyVersion] deja además registro
  /// de qué versión de la política aceptó la cuenta al activar la nube.
  Future<void> writeFlag(String uid, bool enabled, {String? consentPolicyVersion});
}

class FirestoreCloudSyncStore implements CloudSyncStore {
  /// Operaciones por batch al borrar (el máximo de Firestore es 500).
  static const batchSize = 400;
  static const _timeout = Duration(seconds: 30);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(SyncCollection c, String uid) {
    switch (c) {
      case SyncCollection.matches:
        return _db.collection('matches').doc(uid).collection('user_matches');
      case SyncCollection.teams:
        return _db.collection('teams').doc(uid).collection('user_teams');
      case SyncCollection.plays:
        return _db.collection('plays').doc(uid).collection('user_plays');
      case SyncCollection.fixture:
        return _db.collection('fixture').doc(uid).collection('user_fixture');
    }
  }

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
  Future<String?> readConsentVersion(String uid) async {
    try {
      final snap = await _account(uid).get(const GetOptions(source: Source.server)).timeout(_timeout);
      final consent = snap.data()?['cloudConsent'];
      final version = consent is Map ? consent['privacyPolicyVersion'] : null;
      return version is String ? version : null;
    } catch (_) {
      return null;
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
/// fotos) con Firestore, si la cuenta activó la nube; desde la sección 8
/// (opción A), también las jugadas de la pizarra y el fixture, con las
/// mismas reglas que los equipos. Los partidos en curso y las fotos no viajan
/// (siguen en Exportar todo). Hive sigue siendo la fuente de todo lo que se
/// muestra: el sync solo copia de un lado al otro.
///
/// - [push]/[pushTeam]/[pushPlay]/[pushFixtureEntry]: sin esperar (el SDK de
///   Firestore encola sin red).
/// - [uploadAll]: subida inicial al activar la nube, reanudable.
/// - [pull]: incremental, con el cursor en `serverUpdatedAt` (hora del
///   servidor). Gana el `updatedAt` más nuevo (null = el más viejo; empate:
///   no se toca); si lo local es más nuevo se vuelve a subir, para que una
///   escritura vieja encolada en otro dispositivo no deje la nube atrasada.
///   Una marca `deletedAt` manda el partido a la papelera (o el equipo, la
///   jugada o la fila del fixture a ocultos): que algo falte en la nube nunca
///   borra nada local.
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

  /// `Play.toJson()` con las fechas como `Timestamp`. Los trazos son una
  /// lista de mapas (cada uno con sus listas de puntos), sin listas dentro de
  /// listas.
  @visibleForTesting
  static Map<String, dynamic> playToFirestoreJson(Play play) {
    final json = play.toJson();
    json['date'] = Timestamp.fromDate(play.date);
    json['updatedAt'] = _ts(play.updatedAt);
    json['deletedAt'] = _ts(play.deletedAt);
    return json;
  }

  @visibleForTesting
  static Play playFromFirestoreJson(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data)..remove('serverUpdatedAt');
    for (final key in const ['date', 'updatedAt', 'deletedAt']) {
      json[key] = _iso(json[key]);
    }
    return Play.fromJson(json);
  }

  /// `FixtureEntry.toJson()` con las fechas como `Timestamp`.
  @visibleForTesting
  static Map<String, dynamic> fixtureToFirestoreJson(FixtureEntry entry) {
    final json = entry.toJson();
    json['date'] = Timestamp.fromDate(entry.date);
    json['updatedAt'] = _ts(entry.updatedAt);
    json['deletedAt'] = _ts(entry.deletedAt);
    return json;
  }

  @visibleForTesting
  static FixtureEntry fixtureFromFirestoreJson(Map<String, dynamic> data) {
    final json = Map<String, dynamic>.from(data)..remove('serverUpdatedAt');
    for (final key in const ['date', 'updatedAt', 'deletedAt']) {
      json[key] = _iso(json[key]);
    }
    return FixtureEntry.fromJson(json);
  }

  /// Tamaño (bytes UTF-8) del JSON del partido: aproxima el del documento.
  static int documentBytes(VolleyMatch match) => utf8.encode(jsonEncode(match.toJson())).length;

  /// Igual que [documentBytes], para una jugada (una muy larga, con miles
  /// de puntos dibujados, podría pasar el límite).
  static int playBytes(Play play) => utf8.encode(jsonEncode(play.toJson())).length;

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

  /// Jugadas que no se pudieron subir por tamaño.
  List<String> get oversizePlayIds {
    final uid = _uid;
    if (uid == null) return const [];
    return [...(_s.loadAccountValue(StorageService.cloudOversizePlaysKey, uid) as List? ?? const []).cast<String>()];
  }

  /// Desde qué versión de la política la nube incluye jugadas y fixture.
  static const playsAndFixturePolicyVersion = '2.1';

  /// 1 si la versión [a] ("2.1") es posterior a [b], 0 si es la misma, -1 si
  /// es anterior.
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  /// Versión de la política aceptada para la nube por la cuenta abierta
  /// (caché), o null si no se sabe.
  String? get acceptedPolicyVersion {
    final uid = _uid;
    if (uid == null) return null;
    final v = _s.loadAccountValue(StorageService.cloudConsentVersionKey, uid);
    return v is String ? v : null;
  }

  /// La cuenta aceptó una política que incluye jugadas y fixture en la nube
  /// (2.1 o posterior). Sin eso, jugadas y fixture no suben ni bajan: una
  /// cuenta que activó la nube con la 2.0 aceptó que solo viajaran partidos y
  /// equipos.
  bool get coversPlaysAndFixture {
    final v = acceptedPolicyVersion;
    return v != null && compareVersions(v, playsAndFixturePolicyVersion) >= 0;
  }

  /// La nube está activada pero con un consentimiento anterior a la
  /// política vigente: hay que mostrar el aviso de la 2.1.
  bool get needsPolicyUpdate => enabled && !coversPlaysAndFixture;

  /// Antes de mostrar el aviso: si la caché no alcanza, consulta en el
  /// servidor qué versión aceptó la cuenta (puede haberla aceptado en otro
  /// dispositivo) y la guarda. Devuelve [needsPolicyUpdate].
  Future<bool> refreshConsent() async {
    final session = _session();
    if (!enabled || session == null || coversPlaysAndFixture) return needsPolicyUpdate;
    final remote = await _store.readConsentVersion(session.uid);
    if (!_same(session)) return false;
    if (remote != null) await _saveValue(session, StorageService.cloudConsentVersionKey, remote);
    return needsPolicyUpdate;
  }

  /// "Entendido" en el aviso de la 2.1: registra el consentimiento con la
  /// versión vigente y sube lo que faltaba (jugadas y fixture; lo ya subido
  /// no se repite).
  Future<void> acceptCurrentPolicy() async {
    final session = _session();
    if (!enabled || session == null) return;
    await _saveValue(session, StorageService.cloudConsentVersionKey, kPrivacyPolicyVersion);
    await _saveValue(session, StorageService.cloudUploadDoneKey, null);
    notifyListeners();
    try {
      await _store
          .writeFlag(session.uid, true, consentPolicyVersion: kPrivacyPolicyVersion)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('MatchSyncService: no se pudo guardar el consentimiento ($e)');
    }
    unawaited(uploadAll());
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

  Future<void> _setOversizePlay(_Session session, String playId, bool oversize) async {
    final ids = oversizePlayIds;
    if (oversize == ids.contains(playId)) return;
    oversize ? ids.add(playId) : ids.remove(playId);
    await _saveValue(session, StorageService.cloudOversizePlaysKey, ids);
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

  /// Sube una jugada sin esperar. Si no entra en un documento, no se sube y
  /// queda anotada.
  void pushPlay(Play play) {
    final session = _session();
    if (!enabled || session == null || !coversPlaysAndFixture) return;
    final tooBig = playBytes(play) > maxDocumentBytes;
    unawaited(_setOversizePlay(session, play.id, tooBig));
    if (tooBig) return;
    _fireAndForget(_store.write(SyncCollection.plays, session.uid, play.id, playToFirestoreJson(play)));
  }

  /// Sube una fila del fixture sin esperar.
  void pushFixtureEntry(FixtureEntry entry) {
    final session = _session();
    if (!enabled || session == null || !coversPlaysAndFixture) return;
    _fireAndForget(_store.write(SyncCollection.fixture, session.uid, entry.id, fixtureToFirestoreJson(entry)));
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

  void deleteRemotePlay(String playId) {
    final session = _session();
    if (!enabled || session == null || !coversPlaysAndFixture) return;
    _fireAndForget(_store.delete(SyncCollection.plays, session.uid, playId));
  }

  void deleteRemoteFixtureEntry(String entryId) {
    final session = _session();
    if (!enabled || session == null || !coversPlaysAndFixture) return;
    _fireAndForget(_store.delete(SyncCollection.fixture, session.uid, entryId));
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
  /// después partidos, jugadas y por último el fixture (sus filas apuntan a
  /// partidos). Sin red o con la nube apagada no hace nada. Si ya hay uno en
  /// curso, devuelve ese.
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
      if (!_same(session)) return;
      if (coversPlaysAndFixture) {
        await _pullCollection(SyncCollection.plays, session);
        if (!_same(session)) return;
        await _pullCollection(SyncCollection.fixture, session);
      }
      await _saveValue(session, StorageService.cloudLastSyncKey, DateTime.now().toIso8601String());
    } on UserDataClosedError {
      // Se cerró la sesión en el medio: no se escribió nada en la otra cuenta.
    } catch (e) {
      debugPrint('MatchSyncService: no se pudo bajar de la nube ($e)');
    }
  }

  Future<void> _pullCollection(SyncCollection collection, _Session session) async {
    final key = _cursorKeys[collection]!;
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
        final handled = switch (collection) {
          SyncCollection.matches => await _applyMatch(doc, session),
          SyncCollection.teams => await _applyTeam(doc, session),
          SyncCollection.plays => await _applyPlay(doc, session),
          SyncCollection.fixture => await _applyFixtureEntry(doc, session),
        };
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

  static const _cursorKeys = {
    SyncCollection.matches: StorageService.cloudCursorMatchesKey,
    SyncCollection.teams: StorageService.cloudCursorTeamsKey,
    SyncCollection.plays: StorageService.cloudCursorPlaysKey,
    SyncCollection.fixture: StorageService.cloudCursorFixtureKey,
  };

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

  Future<bool> _applyPlay(RemoteDoc doc, _Session session) async {
    final remote = playFromFirestoreJson(doc.data);
    final local = appData.findPlay(remote.id);
    if (local != null) {
      final cmp = _compare(remote.updatedAt, local.updatedAt);
      if (cmp == 0) return true;
      if (cmp < 0) {
        pushPlay(local);
        return true;
      }
    }
    await appData.savePlay(remote, syncToCloud: false, sessionToken: session.token);
    return true;
  }

  /// Una fila cuyo partido todavía no bajó (o no existe) cuenta como "sin
  /// jugar" (`AppDataController.linkedMatchOf`): no hace falta esperarlo.
  Future<bool> _applyFixtureEntry(RemoteDoc doc, _Session session) async {
    final remote = fixtureFromFirestoreJson(doc.data);
    final local = appData.findFixtureEntry(remote.id);
    if (local != null) {
      final cmp = _compare(remote.updatedAt, local.updatedAt);
      if (cmp == 0) return true;
      if (cmp < 0) {
        pushFixtureEntry(local);
        return true;
      }
    }
    await appData.saveFixtureEntry(remote, syncToCloud: false, sessionToken: session.token);
    return true;
  }

  // ---------------- Subida inicial ----------------

  /// Sube todos los equipos, después todos los partidos terminados (también
  /// los de la papelera, con su marca), sin tope, y por último las jugadas y
  /// el fixture (también los borrados, con su marca). Primero baja lo que ya hay
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
      // Jugadas y fixture, solo con el consentimiento 2.1 (ver coversPlaysAndFixture).
      if (coversPlaysAndFixture)
        for (final p in [...appData.plays, ...appData.hiddenPlays])
          ('p:${p.id}', () async {
            final tooBig = playBytes(p) > maxDocumentBytes;
            await _setOversizePlay(session, p.id, tooBig);
            if (!tooBig) await _store.write(SyncCollection.plays, session.uid, p.id, playToFirestoreJson(p));
          }),
      if (coversPlaysAndFixture)
        for (final e in [...appData.fixtureEntries, ...appData.hiddenFixtureEntries])
          ('f:${e.id}', () => _store.write(SyncCollection.fixture, session.uid, e.id, fixtureToFirestoreJson(e))),
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
  /// todo ya se sube solo, vuelve a subir todos los equipos, partidos
  /// terminados, jugadas y el fixture, después de bajar lo nuevo (así no pisa una versión más
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
  /// [deleteRemoteCopy] además borra la copia de la nube (partidos, equipos,
  /// jugadas y fixture). Nunca toca lo local.
  Future<void> setCloudSync(bool on, {bool deleteRemoteCopy = false}) async {
    final session = _session();
    if (!supported || session == null) return;
    await _saveValue(session, StorageService.cloudSyncKey, on);
    // Al activarla se acepta la política vigente (ver el aviso de activación).
    if (on) await _saveValue(session, StorageService.cloudConsentVersionKey, kPrivacyPolicyVersion);
    if (!on) {
      // La próxima vez que se active, todo vuelve a subir y a bajar de cero.
      for (final key in const [
        StorageService.cloudCursorMatchesKey,
        StorageService.cloudCursorTeamsKey,
        StorageService.cloudCursorPlaysKey,
        StorageService.cloudCursorFixtureKey,
        StorageService.cloudUploadedKey,
        StorageService.cloudUploadDoneKey,
        StorageService.cloudOversizeKey,
        StorageService.cloudOversizePlaysKey,
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

  /// Borra `matches/{uid}`, `teams/{uid}`, `plays/{uid}` y `fixture/{uid}`
  /// (al apagar la nube eligiendo borrar la copia, y al eliminar la cuenta).
  /// Necesita red: si falla, lanza.
  Future<void> deleteAllRemote(String uid) async {
    for (final c in SyncCollection.values) {
      await _store.deleteAll(c, uid);
    }
  }
}

class _Session {
  final String uid;
  final int token;
  _Session(this.uid, this.token);
}
