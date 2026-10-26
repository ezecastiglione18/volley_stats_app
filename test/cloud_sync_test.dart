// Sync de partidos y equipos con la nube (sección 3, Etapa 2 de
// documents/RallyStats-Funcionalidades-Pendientes.pdf) y papelera de 30 días.
// Sin red: Firestore se reemplaza por un fake en memoria que implementa
// CloudSyncStore (no hay fake_cloud_firestore en el proyecto). Hive en un
// directorio temporal por test, como en account_storage_test.dart.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/legal/privacy_policy_text.dart';
import 'package:rally_stats/models/fixture_entry.dart';
import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/play.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/team.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/services/full_backup.dart';
import 'package:rally_stats/services/match_sync_service.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/utils/sample_team.dart';

/// Firestore en memoria. `serverUpdatedAt` sale de un reloj propio que avanza
/// un segundo por escritura (la "hora del servidor", independiente del reloj
/// del dispositivo).
class _FakeCloudStore implements CloudSyncStore {
  final Map<String, Map<String, Map<String, dynamic>>> _cols = {};
  DateTime _serverClock = DateTime(2026, 10, 1, 12);
  CloudSyncFlag flag = CloudSyncFlag.on;
  String? consentVersion;
  int writes = 0;
  final List<String> fetchedIds = [];

  /// Si no es null, cada write a partir de ese número falla (se corta la red).
  int? failFromWrite;

  /// Si no es null, fetchChanged espera a que se complete (para cambiar de
  /// cuenta en el medio de un pull).
  Completer<void>? fetchGate;

  Map<String, Map<String, dynamic>> _col(SyncCollection c, String uid) =>
      _cols.putIfAbsent('${c.name}/$uid', () => {});

  static Object? _copy(Object? v) {
    if (v is Map) return {for (final e in v.entries) e.key as String: _copy(e.value)};
    if (v is List) return [for (final e in v) _copy(e)];
    return v;
  }

  Map<String, dynamic>? doc(SyncCollection c, String uid, String id) => _col(c, uid)[id];
  int count(SyncCollection c, String uid) => _col(c, uid).length;

  /// Otro dispositivo de la cuenta escribe directo en la nube.
  void putRemote(SyncCollection c, String uid, String id, Map<String, dynamic> data) {
    _serverClock = _serverClock.add(const Duration(seconds: 1));
    _col(c, uid)[id] = {...(_copy(data) as Map<String, dynamic>), 'serverUpdatedAt': Timestamp.fromDate(_serverClock)};
  }

  void removeRemote(SyncCollection c, String uid, String id) => _col(c, uid).remove(id);

  @override
  Future<void> write(SyncCollection collection, String uid, String id, Map<String, dynamic> data) async {
    if (failFromWrite != null && writes >= failFromWrite!) throw Exception('sin red');
    writes++;
    putRemote(collection, uid, id, data);
  }

  @override
  Future<List<RemoteDoc>> fetchChanged(SyncCollection collection, String uid,
      {DateTime? since, RemoteDoc? after, required int limit}) async {
    if (fetchGate != null) await fetchGate!.future;
    DateTime sut(Map<String, dynamic> d) => (d['serverUpdatedAt'] as Timestamp).toDate();
    final all = _col(collection, uid).entries.where((e) => since == null || sut(e.value).isAfter(since)).toList()
      ..sort((a, b) {
        final c = sut(a.value).compareTo(sut(b.value));
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    var start = 0;
    if (after != null) start = all.indexWhere((e) => e.key == after.cursor) + 1;
    final page = all.skip(start).take(limit).toList();
    fetchedIds.addAll(page.map((e) => e.key));
    return [
      for (final e in page)
        RemoteDoc(e.key, _copy(e.value) as Map<String, dynamic>, sut(e.value), e.key),
    ];
  }

  @override
  Future<void> delete(SyncCollection collection, String uid, String id) async => _col(collection, uid).remove(id);

  @override
  Future<void> deleteAll(SyncCollection collection, String uid) async => _col(collection, uid).clear();

  @override
  Future<void> deleteTrashedBefore(SyncCollection collection, String uid, DateTime cutoff) async =>
      _col(collection, uid).removeWhere(
          (_, d) => d['deletedAt'] is Timestamp && (d['deletedAt'] as Timestamp).toDate().isBefore(cutoff));

  @override
  Future<CloudSyncFlag> readFlag(String uid) async => flag;

  @override
  Future<String?> readConsentVersion(String uid) async => consentVersion;

  @override
  Future<void> writeFlag(String uid, bool enabled, {String? consentPolicyVersion}) async {
    flag = enabled ? CloudSyncFlag.on : CloudSyncFlag.off;
    consentVersion = consentPolicyVersion ?? consentVersion;
  }
}

const _uidA = 'UidDeLaCuentaA00000000000001';
const _uidB = 'UidDeLaCuentaB00000000000002';

Player _p(String id, {String? photo}) =>
    Player(id: id, firstName: id, lastName: 'Test', number: 1, position: PlayerPosition.armador, photoPath: photo);

VolleyMatch _match(String id,
        {MatchStatus status = MatchStatus.finished, DateTime? updatedAt, DateTime? deletedAt, String? notes}) =>
    VolleyMatch(
      id: id,
      date: DateTime(2026, 5, 1),
      ownTeamName: 'Propio',
      ownRoster: [_p('pl_1', photo: '/no/existe.jpg')],
      rivalTeamName: 'Rival $id',
      config: MatchConfig(),
      status: status,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      notes: notes,
    );

Team _team(String id, {DateTime? updatedAt, DateTime? deletedAt, List<Player>? players}) =>
    Team(id: id, name: 'Equipo $id', players: players ?? [_p('${id}_p1')], updatedAt: updatedAt, deletedAt: deletedAt);

/// Lista que contiene directamente otra lista (Firestore no la acepta).
bool _hasNestedList(Object? v) {
  if (v is List) return v.any((e) => e is List || _hasNestedList(e));
  if (v is Map) return v.values.any(_hasNestedList);
  return false;
}

late Directory _dir;

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? _dir.path : null,
    );
  });

  final storage = StorageService.instance;
  late DateTime now;
  late AppDataController appData;
  late _FakeCloudStore store;
  late MatchSyncService sync;

  /// [consent]: versión de la política con la que la cuenta activó la nube
  /// (por defecto la vigente; '2.0' = antes de que viajaran jugadas y fixture).
  Future<void> openAs(String uid, {bool cloud = true, String consent = kPrivacyPolicyVersion}) async {
    await appData.openAccount(uid);
    if (cloud) {
      await storage.saveAccountValue(StorageService.cloudSyncKey, uid, true);
      await storage.saveAccountValue(StorageService.cloudConsentVersionKey, uid, consent);
    }
  }

  setUp(() async {
    await storage.resetForTest();
    _dir = Directory.systemTemp.createTempSync('rally_stats_cloud_test');
    now = DateTime(2026, 10, 20, 10);
    appData = AppDataController(clock: () => now);
    store = _FakeCloudStore();
    sync = MatchSyncService(
      appData: appData,
      store: store,
      platformSupported: true,
      pullMargin: Duration.zero,
      pageSize: 2,
    );
    await openAs(_uidA);
  });

  tearDownAll(() => storage.resetForTest());

  group('conversiones', () {
    test('partido: fechas como Timestamp, sin fotos, sin listas dentro de listas, ida y vuelta', () async {
      final roster = [for (var i = 1; i <= 6; i++) _p('pl_$i', photo: '/fotos/$i.jpg')];
      final m = VolleyMatch(
        id: 'm1',
        date: DateTime(2026, 9, 20, 18, 30),
        ownTeamName: 'Propio',
        ownRoster: roster,
        rivalTeamName: 'Los Andes',
        config: MatchConfig(),
        notes: 'Saca flotado',
        updatedAt: DateTime(2026, 9, 20, 20),
      );
      // Un set de verdad (eventos con playerIds, cambios, zonas).
      MatchController(m)
        ..startSet(
            setNumber: 1,
            startingOrderOwn: [for (final p in roster) p.id],
            startingServer: TeamSide.own,
            nineHitZones: true)
        ..simulateRestOfSet();
      m.status = MatchStatus.finished;

      final json = MatchSyncService.matchToFirestoreJson(m);
      expect(json['date'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());
      expect(json['deletedAt'], isNull);
      expect((json['ownRoster'] as List).every((p) => (p as Map)['photoPath'] == null), isTrue);
      expect(_hasNestedList(json), isFalse);
      expect(m.ownRoster.first.photoPath, '/fotos/1.jpg', reason: 'no toca el partido local');

      final back = MatchSyncService.matchFromFirestoreJson({...json, 'serverUpdatedAt': Timestamp.now()});
      final expected = m.toJson()
        ..['ownRoster'] = [for (final p in m.ownRoster) {...p.toJson(), 'photoPath': null}];
      expect(back.toJson(), expected);
    });

    test('equipo: sin fotos, fechas como Timestamp, ida y vuelta', () {
      final t = _team('t1', updatedAt: DateTime(2026, 9, 1), players: [_p('a', photo: '/f/a.jpg'), _p('b')])
        ..headCoach = 'DT';
      final json = MatchSyncService.teamToFirestoreJson(t);
      expect(json['updatedAt'], isA<Timestamp>());
      expect((json['players'] as List).every((p) => (p as Map)['photoPath'] == null), isTrue);
      expect(_hasNestedList(json), isFalse);
      final back = MatchSyncService.teamFromFirestoreJson(json);
      expect(back.updatedAt, t.updatedAt);
      expect(back.players.map((p) => p.id), ['a', 'b']);
      expect(back.headCoach, 'DT');
      expect(back.players.first.photoPath, isNull);
    });

    test('fromJson de un partido y un equipo viejos (sin updatedAt ni deletedAt)', () {
      final oldMatch = _match('m1').toJson()
        ..remove('updatedAt')
        ..remove('deletedAt');
      final m = VolleyMatch.fromJson(oldMatch);
      expect(m.updatedAt, isNull);
      expect(m.deletedAt, isNull);
      final oldTeam = _team('t1').toJson()
        ..remove('updatedAt')
        ..remove('deletedAt');
      final t = Team.fromJson(oldTeam);
      expect(t.updatedAt, isNull);
      expect(t.deletedAt, isNull);
    });
  });

  group('push', () {
    test('solo partidos terminados y con la nube activada', () async {
      await appData.saveMatch(_match('enCurso', status: MatchStatus.inProgress), isPremium: true);
      expect(store.count(SyncCollection.matches, _uidA), 0);

      await appData.saveMatch(_match('m1'), isPremium: true);
      expect(store.doc(SyncCollection.matches, _uidA, 'm1'), isNotNull);

      await storage.saveAccountValue(StorageService.cloudSyncKey, _uidA, false);
      await appData.saveMatch(_match('m2'), isPremium: true);
      expect(store.doc(SyncCollection.matches, _uidA, 'm2'), isNull);
    });

    test('saveMatch estampa updatedAt; desde el pull (syncToCloud: false) lo conserva, no sube ni aplica el tope',
        () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      expect(appData.findMatch('m1')!.updatedAt, now);

      for (final id in ['a', 'b', 'c']) {
        await appData.saveMatch(_match(id), isPremium: true);
      }
      final writes = store.writes;
      final remote = _match('r1', updatedAt: DateTime(2026, 1, 1));
      await appData.saveMatch(remote, isPremium: false, syncToCloud: false);
      expect(appData.findMatch('r1')!.updatedAt, DateTime(2026, 1, 1));
      expect(store.writes, writes);
      expect(appData.matches.length, 5, reason: 'la bajada no aplica el tope de 3');
    });

    test('un partido que no entra en un documento no se sube y queda anotado', () async {
      final big = _match('big', notes: 'x' * (MatchSyncService.maxDocumentBytes + 10));
      await appData.saveMatch(big, isPremium: true);
      await _settle();
      expect(store.doc(SyncCollection.matches, _uidA, 'big'), isNull);
      expect(sync.oversizeMatchIds, ['big']);
    });

    test('sin soporte de la plataforma (Windows) no hace nada', () async {
      final windows = MatchSyncService(appData: appData, store: store, platformSupported: false);
      await appData.saveMatch(_match('m1'), isPremium: true);
      await windows.pull();
      expect(windows.enabled, isFalse);
      expect(store.count(SyncCollection.matches, _uidA), 0);
    });
  });

  group('pull', () {
    test('incremental: cursor tomado de serverUpdatedAt y sin re-subida', () async {
      for (final id in ['r1', 'r2', 'r3']) {
        store.putRemote(SyncCollection.matches, _uidA, id,
            MatchSyncService.matchToFirestoreJson(_match(id, updatedAt: DateTime(2026, 9, 1))));
      }
      await sync.pull();
      expect(appData.matches.map((m) => m.id).toSet(), {'r1', 'r2', 'r3'});
      expect(store.writes, 0, reason: 'lo que baja no se vuelve a subir');
      final cursor = storage.loadAccountValue(StorageService.cloudCursorMatchesKey, _uidA) as String;
      final lastServer = (store.doc(SyncCollection.matches, _uidA, 'r3')!['serverUpdatedAt'] as Timestamp).toDate();
      expect(DateTime.parse(cursor), lastServer);

      store.fetchedIds.clear();
      store.putRemote(SyncCollection.matches, _uidA, 'r4',
          MatchSyncService.matchToFirestoreJson(_match('r4', updatedAt: DateTime(2026, 9, 2))));
      await sync.pull();
      expect(store.fetchedIds, ['r4'], reason: 'solo lo posterior al cursor');
      expect(appData.findMatch('r4'), isNotNull);
      expect(sync.lastSyncAt, isNotNull);
    });

    test('con margen hacia atrás, aplicar dos veces el mismo documento no cambia nada', () async {
      final withMargin = MatchSyncService(appData: appData, store: store, platformSupported: true);
      store.putRemote(SyncCollection.matches, _uidA, 'r1',
          MatchSyncService.matchToFirestoreJson(_match('r1', updatedAt: DateTime(2026, 9, 1), notes: 'a')));
      await withMargin.pull();
      final first = appData.findMatch('r1');
      await withMargin.pull();
      expect(identical(appData.findMatch('r1'), first), isTrue);
      expect(store.writes, 0);
    });

    test('deletedAt manda el partido a la papelera (no lo borra), también si no existía acá', () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      final trashed = _match('m1', updatedAt: now.add(const Duration(hours: 1)), deletedAt: now.add(const Duration(hours: 1)));
      store.putRemote(SyncCollection.matches, _uidA, 'm1', MatchSyncService.matchToFirestoreJson(trashed));
      store.putRemote(SyncCollection.matches, _uidA, 'otro',
          MatchSyncService.matchToFirestoreJson(_match('otro', updatedAt: now, deletedAt: now)));
      await sync.pull();
      expect(appData.matches, isEmpty);
      expect(appData.trashedMatches.map((m) => m.id).toSet(), {'m1', 'otro'});
      expect(storage.loadMatches().length, 2, reason: 'siguen en Hive');
    });

    test('nunca borra lo que falta en la nube', () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      await appData.saveTeam(_team('t1'));
      store.removeRemote(SyncCollection.matches, _uidA, 'm1');
      store.removeRemote(SyncCollection.teams, _uidA, 't1');
      await sync.pull();
      expect(appData.findMatch('m1'), isNotNull);
      expect(appData.findMatch('m1')!.deletedAt, isNull);
      expect(appData.teams.map((t) => t.id), ['t1']);
    });

    test('gana el updatedAt más nuevo; el empate no toca nada; lo local más nuevo se vuelve a subir', () async {
      final t1 = DateTime(2026, 9, 1);
      final t2 = DateTime(2026, 9, 2);
      // remoto más nuevo -> reemplaza
      await appData.saveMatch(_match('a', updatedAt: t1, notes: 'local'), isPremium: true, syncToCloud: false);
      store.putRemote(SyncCollection.matches, _uidA, 'a',
          MatchSyncService.matchToFirestoreJson(_match('a', updatedAt: t2, notes: 'remoto')));
      // empate -> no se toca
      await appData.saveMatch(_match('b', updatedAt: t1, notes: 'local'), isPremium: true, syncToCloud: false);
      store.putRemote(SyncCollection.matches, _uidA, 'b',
          MatchSyncService.matchToFirestoreJson(_match('b', updatedAt: t1, notes: 'remoto')));
      // local más nuevo -> se queda y se vuelve a subir
      await appData.saveMatch(_match('c', updatedAt: t2, notes: 'local'), isPremium: true, syncToCloud: false);
      store.putRemote(SyncCollection.matches, _uidA, 'c',
          MatchSyncService.matchToFirestoreJson(_match('c', updatedAt: t1, notes: 'remoto')));
      // null cuenta como el más viejo
      await appData.saveMatch(_match('d', notes: 'local'), isPremium: true, syncToCloud: false);
      store.putRemote(SyncCollection.matches, _uidA, 'd',
          MatchSyncService.matchToFirestoreJson(_match('d', updatedAt: t1, notes: 'remoto')));

      final writesBefore = store.writes;
      await sync.pull();
      expect(appData.findMatch('a')!.notes, 'remoto');
      expect(appData.findMatch('b')!.notes, 'local');
      expect(appData.findMatch('c')!.notes, 'local');
      expect(appData.findMatch('d')!.notes, 'remoto');
      expect(store.writes, writesBefore + 1);
      expect(store.doc(SyncCollection.matches, _uidA, 'c')!['notes'], 'local');
    });

    test('saltea un partido abierto en un MatchController y lo aplica en el pull siguiente', () async {
      final local = _match('m1', status: MatchStatus.inProgress, updatedAt: DateTime(2026, 9, 1));
      await appData.saveMatch(local, isPremium: true, syncToCloud: false);
      // Terminado en otro dispositivo (había viajado con Exportar/Importar).
      store.putRemote(SyncCollection.matches, _uidA, 'm1',
          MatchSyncService.matchToFirestoreJson(_match('m1', updatedAt: DateTime(2026, 9, 2))));
      store.putRemote(SyncCollection.matches, _uidA, 'otro',
          MatchSyncService.matchToFirestoreJson(_match('otro', updatedAt: DateTime(2026, 9, 2))));
      final controller = MatchController(appData.findMatch('m1')!)..markOpen();

      await sync.pull();
      expect(appData.findMatch('m1')!.status, MatchStatus.inProgress, reason: 'abierto: no se toca');
      expect(appData.findMatch('otro'), isNotNull);

      controller.markClosed();
      await sync.pull();
      expect(appData.findMatch('m1')!.status, MatchStatus.finished);
    });

    test('si la nube se apagó desde otro dispositivo, deja de bajar', () async {
      store.flag = CloudSyncFlag.off;
      store.putRemote(SyncCollection.matches, _uidA, 'r1',
          MatchSyncService.matchToFirestoreJson(_match('r1', updatedAt: now)));
      await sync.pull();
      expect(appData.findMatch('r1'), isNull);
      expect(sync.enabled, isFalse);
    });
  });

  group('cuenta abierta', () {
    test('pull no escribe si mientras tanto cambió la cuenta abierta', () async {
      store.putRemote(SyncCollection.matches, _uidA, 'deA',
          MatchSyncService.matchToFirestoreJson(_match('deA', updatedAt: now)));
      store.fetchGate = Completer<void>();
      final pulling = sync.pull();
      await _settle();
      await appData.closeAccount();
      await openAs(_uidB);
      store.fetchGate!.complete();
      await pulling;
      expect(appData.matches, isEmpty, reason: 'nada de A cae en B');
      expect(storage.loadAccountValue(StorageService.cloudCursorMatchesKey, _uidB), isNull);
      await appData.closeAccount();
      await openAs(_uidA);
      expect(appData.findMatch('deA'), isNull, reason: 'el pull de A quedó cortado');
    });

    test('push y uploadAll no escriben para otra cuenta', () async {
      await appData.saveMatch(_match('m1'), isPremium: true, syncToCloud: false);
      store.fetchGate = Completer<void>();
      final uploading = sync.uploadAll();
      await _settle();
      await appData.closeAccount();
      await openAs(_uidB, cloud: false);
      store.fetchGate!.complete();
      await uploading;
      await appData.saveMatch(_match('deB'), isPremium: true);
      expect(store.count(SyncCollection.matches, _uidA), 0);
      expect(store.count(SyncCollection.matches, _uidB), 0);
    });
  });

  group('subida inicial', () {
    test('sube equipos y partidos terminados (sin tope) y es reanudable', () async {
      for (final id in ['t1', 't2']) {
        await appData.saveTeam(_team(id), syncToCloud: false);
      }
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await appData.saveMatch(_match(id), isPremium: true, syncToCloud: false);
      }
      await appData.saveMatch(_match('enCurso', status: MatchStatus.inProgress), isPremium: true, syncToCloud: false);

      store.failFromWrite = 3; // se corta la red después de 3 documentos
      await sync.uploadAll();
      expect(store.writes, 3);
      expect(sync.initialUploadDone, isFalse);

      store.failFromWrite = null;
      await sync.uploadAll();
      expect(store.writes, 6, reason: 'la segunda vez sube solo los 3 que faltaban');
      expect(store.count(SyncCollection.teams, _uidA), 2);
      expect(store.count(SyncCollection.matches, _uidA), 4, reason: 'el partido en curso no sube');
      expect(sync.initialUploadDone, isTrue);
      expect(sync.uploadDone, 6);
      expect(sync.uploadTotal, 6);
    });

    test('"Hacer una copia ahora" vuelve a subir todo; sin conexión avisa enseguida', () async {
      await appData.saveTeam(_team('t1'), syncToCloud: false);
      for (final id in ['m1', 'm2']) {
        await appData.saveMatch(_match(id), isPremium: true, syncToCloud: false);
      }
      await sync.uploadAll();
      expect(store.writes, 3);

      expect(await sync.backupNow(), isTrue);
      expect(store.writes, 6, reason: 'vuelve a subir los 3 aunque ya estaban');
      expect(sync.initialUploadDone, isTrue);

      store.flag = CloudSyncFlag.unknown; // sin red
      expect(await sync.backupNow(), isFalse);
      expect(store.writes, 6);

      await storage.saveAccountValue(StorageService.cloudSyncKey, _uidA, false);
      store.flag = CloudSyncFlag.on;
      expect(await sync.backupNow(), isFalse, reason: 'con la nube apagada no hace nada');
    });

    test('activar la nube guarda el consentimiento y lanza la subida; apagarla puede borrar la copia remota',
        () async {
      // Nunca se le preguntó a la cuenta (ni acá ni en la nube).
      await storage.saveAccountValue(StorageService.cloudSyncKey, _uidA, null);
      store.flag = CloudSyncFlag.unset;
      expect(await sync.refreshFlag(), CloudSyncFlag.unset);
      await appData.saveMatch(_match('m1'), isPremium: true);
      expect(store.count(SyncCollection.matches, _uidA), 0);

      await sync.setCloudSync(true);
      await sync.uploadAll();
      expect(store.flag, CloudSyncFlag.on);
      expect(store.consentVersion, isNotNull);
      expect(store.count(SyncCollection.matches, _uidA), 1);

      await sync.setCloudSync(false, deleteRemoteCopy: true);
      expect(store.flag, CloudSyncFlag.off);
      expect(store.count(SyncCollection.matches, _uidA), 0);
      expect(appData.findMatch('m1'), isNotNull, reason: 'nunca toca lo local');
    });
  });

  group('papelera', () {
    test('queda fuera de AppDataController.matches (archivo, temporada, comparador, fixture y tope)', () async {
      for (final id in ['m1', 'm2', 'm3']) {
        await appData.saveMatch(_match(id), isPremium: false);
      }
      await appData.saveFixtureEntry(
          FixtureEntry(id: 'f1', date: DateTime(2026, 6, 1), rivalTeamName: 'R', linkedMatchId: 'm1'));
      await appData.trashMatch('m1');
      expect(appData.matches.map((m) => m.id), isNot(contains('m1')));
      expect(appData.trashedMatches.map((m) => m.id), ['m1']);
      expect(appData.linkedMatchOf(appData.fixtureEntries.single), isNull, reason: 'cuenta como sin jugar');
      expect(appData.fixtureEntries.single.linkedMatchId, 'm1', reason: 'no toca el vínculo');
      // El tope cuenta solo el archivo: entra uno nuevo.
      await appData.saveMatch(_match('m4'), isPremium: false);
      expect(appData.matches.length, 3);
      // Con la nube, la papelera viaja como marca.
      final remote = store.doc(SyncCollection.matches, _uidA, 'm1')!;
      expect(remote['deletedAt'], isA<Timestamp>());
    });

    test('restaurar respeta el tope en free y re-vincula la fila del fixture', () async {
      for (final id in ['m1', 'm2', 'm3']) {
        await appData.saveMatch(_match(id), isPremium: false);
      }
      await appData.saveFixtureEntry(
          FixtureEntry(id: 'f1', date: DateTime(2026, 6, 1), rivalTeamName: 'R', linkedMatchId: 'm1'));
      await appData.trashMatch('m1');
      await appData.saveMatch(_match('m4'), isPremium: false);

      await expectLater(appData.restoreMatch('m1', isPremium: false), throwsA(isA<MatchArchiveLimitException>()));
      expect(appData.trashedMatches.map((m) => m.id), ['m1'], reason: 'sigue en la papelera');

      await appData.restoreMatch('m1', isPremium: true);
      expect(appData.findMatch('m1')!.deletedAt, isNull);
      expect(appData.linkedMatchOf(appData.fixtureEntries.single)!.id, 'm1');
    });

    test('eliminar definitivamente desvincula el fixture y borra en la nube', () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      await appData.saveFixtureEntry(
          FixtureEntry(id: 'f1', date: DateTime(2026, 6, 1), rivalTeamName: 'R', linkedMatchId: 'm1'));
      await appData.trashMatch('m1');
      await appData.deleteMatch('m1');
      expect(appData.findMatch('m1'), isNull);
      expect(appData.fixtureEntries.single.linkedMatchId, isNull);
      expect(store.doc(SyncCollection.matches, _uidA, 'm1'), isNull);
    });

    test('purga a los 30 días, local y remota (partidos y equipos)', () async {
      await appData.saveMatch(_match('viejo'), isPremium: true);
      await appData.saveMatch(_match('nuevo'), isPremium: true);
      await appData.saveTeam(_team('t1'));
      await appData.trashMatch('viejo');
      await appData.deleteTeam('t1');
      expect(appData.trashDaysLeft(appData.trashedMatches.single), 30);

      now = now.add(const Duration(days: 20));
      await appData.trashMatch('nuevo');
      now = now.add(const Duration(days: 11)); // "viejo" y "t1": 31 días; "nuevo": 11
      await appData.closeAccount();
      await appData.openAccount(_uidA); // la purga corre al abrir los datos
      await sync.purgeRemote();
      expect(appData.trashedMatches.map((m) => m.id), ['nuevo']);
      expect(appData.hiddenTeams, isEmpty);
      expect(storage.loadMatches().map((m) => m.id), ['nuevo']);
      expect(storage.loadTeams(), isEmpty);
      expect(store.doc(SyncCollection.matches, _uidA, 'viejo'), isNull);
      expect(store.doc(SyncCollection.teams, _uidA, 't1'), isNull);
      expect(store.doc(SyncCollection.matches, _uidA, 'nuevo'), isNotNull);
    });

    test('Exportar todo incluye la papelera; importar no la duplica', () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      await appData.trashMatch('m1');
      final json = appData.buildBackupJson();
      expect((json['matches'] as List).length, 1);
      final summary = await appData.importBackup(FullBackup.parse(json), applyFreeCap: false);
      expect(summary.alreadyExisted, 1);
      expect(appData.matches, isEmpty);
      expect(appData.trashedMatches.length, 1);
      // En otra cuenta entra directo a la papelera.
      await appData.closeAccount();
      await openAs(_uidB);
      await appData.importBackup(FullBackup.parse(json), applyFreeCap: true);
      expect(appData.trashedMatches.single.id, 'm1');
    });
  });

  group('equipos', () {
    test('el pull conserva la foto local de los jugadores que ya existen; los nuevos quedan sin foto', () async {
      final photo = File('${_dir.path}${Platform.pathSeparator}foto.jpg')..writeAsStringSync('x');
      await appData.saveTeam(_team('t1', players: [_p('a', photo: photo.path)]));
      final remote = _team('t1', updatedAt: now.add(const Duration(hours: 1)), players: [_p('a'), _p('nuevo')])
        ..name = 'Editado en otro';
      store.putRemote(SyncCollection.teams, _uidA, 't1', MatchSyncService.teamToFirestoreJson(remote));
      await sync.pull();
      final t = appData.teams.single;
      expect(t.name, 'Editado en otro');
      expect(t.players.firstWhere((p) => p.id == 'a').photoPath, photo.path);
      expect(t.players.firstWhere((p) => p.id == 'nuevo').photoPath, isNull);
      expect(store.doc(SyncCollection.teams, _uidA, 't1')!['players'].first['photoPath'], isNull);
    });

    test('gana el equipo entero con el updatedAt más nuevo', () async {
      await appData.saveTeam(_team('t1')..name = 'Local nuevo'); // updatedAt = now
      store.putRemote(SyncCollection.teams, _uidA, 't1',
          MatchSyncService.teamToFirestoreJson(_team('t1', updatedAt: now.subtract(const Duration(days: 1)))..name = 'Viejo'));
      store.putRemote(SyncCollection.teams, _uidA, 't2',
          MatchSyncService.teamToFirestoreJson(_team('t2', updatedAt: now)..name = 'Solo remoto'));
      await sync.pull();
      expect(appData.findTeam('t1')!.name, 'Local nuevo');
      expect(appData.findTeam('t2')!.name, 'Solo remoto');
    });

    test('deletedAt lo oculta sin borrarlo; no afecta a los partidos que lo usaron', () async {
      final team = _team('t1', players: [_p('pl_1')]);
      await appData.saveTeam(team);
      final match = _match('m1')..ownTeamSourceId = 't1';
      await appData.saveMatch(match, isPremium: true);
      store.putRemote(SyncCollection.teams, _uidA, 't1',
          MatchSyncService.teamToFirestoreJson(_team('t1', updatedAt: now.add(const Duration(hours: 1)),
              deletedAt: now.add(const Duration(hours: 1)))));
      await sync.pull();
      expect(appData.teams, isEmpty);
      expect(appData.hiddenTeams.map((t) => t.id), ['t1']);
      expect(storage.loadTeams().map((t) => t.id), ['t1'], reason: 'sigue en Hive hasta la purga');
      expect(appData.findMatch('m1')!.ownRoster.map((p) => p.id), ['pl_1']);
      expect(appData.matches.length, 1);
    });

    test('borrar un equipo acá lo oculta y sube la marca', () async {
      await appData.saveTeam(_team('t1'));
      await appData.deleteTeam('t1');
      expect(appData.teams, isEmpty);
      expect(store.doc(SyncCollection.teams, _uidA, 't1')!['deletedAt'], isA<Timestamp>());
    });

    test('equipo de ejemplo: id fijo, no sube hasta que se edita, no se carga dos veces', () async {
      expect(await appData.addSampleTeam(), isTrue);
      expect(await appData.addSampleTeam(), isFalse);
      expect(appData.teams.single.id, kSampleTeamId);
      expect(store.count(SyncCollection.teams, _uidA), 0);
      await sync.uploadAll();
      expect(store.count(SyncCollection.teams, _uidA), 0, reason: 'sin editar no viaja');

      await appData.saveTeam(appData.teams.single..headCoach = 'Otro DT');
      expect(store.doc(SyncCollection.teams, _uidA, kSampleTeamId), isNotNull);

      // Borrado y vuelto a cargar: se revive con updatedAt = ahora.
      await appData.deleteTeam(kSampleTeamId);
      now = now.add(const Duration(minutes: 1));
      expect(await appData.addSampleTeam(), isTrue);
      expect(appData.teams.single.updatedAt, now);
      expect(store.doc(SyncCollection.teams, _uidA, kSampleTeamId)!['deletedAt'], isNull);
    });
  });

  group('jugadas y fixture', () {
    Play play(String id, {DateTime? updatedAt, DateTime? deletedAt, String name = 'Jugada', int points = 3}) => Play(
          id: id,
          name: name,
          date: DateTime(2026, 9, 1),
          strokes: [
            PlayStroke(
              colorValue: 0xFFFF0000,
              arrow: true,
              pointsX: [for (var i = 0; i < points; i++) i / points],
              pointsY: [for (var i = 0; i < points; i++) 1 - i / points],
            ),
          ],
          tokens: const [PlacedToken(tokenId: 'A', label: 'A', colorValue: 0xFF000000, x: 0.5, y: 0.5)],
          updatedAt: updatedAt,
          deletedAt: deletedAt,
        );
    FixtureEntry entry(String id, {DateTime? updatedAt, String rival = 'R', String? linkedMatchId}) =>
        FixtureEntry(id: id, date: DateTime(2026, 11, 1), rivalTeamName: rival, linkedMatchId: linkedMatchId, updatedAt: updatedAt);

    test('conversiones: fechas como Timestamp, sin listas dentro de listas, ida y vuelta', () {
      final p = play('p1', updatedAt: now);
      final pj = MatchSyncService.playToFirestoreJson(p);
      expect(pj['date'], isA<Timestamp>());
      expect(pj['updatedAt'], isA<Timestamp>());
      expect(_hasNestedList(pj), isFalse);
      expect(MatchSyncService.playFromFirestoreJson({...pj, 'serverUpdatedAt': Timestamp.now()}).toJson(), p.toJson());

      final e = entry('f1', updatedAt: now, linkedMatchId: 'm1');
      final ej = MatchSyncService.fixtureToFirestoreJson(e);
      expect(ej['date'], isA<Timestamp>());
      expect(MatchSyncService.fixtureFromFirestoreJson(ej).toJson(), e.toJson());

      // Jugadas y filas guardadas antes de este cambio, sin las marcas.
      final oldPlay = p.toJson()..remove('updatedAt')..remove('deletedAt');
      expect(Play.fromJson(oldPlay).updatedAt, isNull);
      final oldEntry = e.toJson()..remove('updatedAt')..remove('deletedAt');
      expect(FixtureEntry.fromJson(oldEntry).deletedAt, isNull);
    });

    test('una jugada larga entra holgada en un documento', () {
      // 40 trazos de 400 puntos (16.000 puntos: varios minutos de dibujo).
      final big = Play(
        id: 'grande',
        name: 'Sistema completo',
        date: DateTime(2026, 9, 1),
        strokes: [
          for (var s = 0; s < 40; s++)
            PlayStroke(
              colorValue: 0xFF00FF00,
              arrow: s.isEven,
              pointsX: [for (var i = 0; i < 400; i++) (i * 0.0024913 + s * 0.013) % 1],
              pointsY: [for (var i = 0; i < 400; i++) (i * 0.0017331 + s * 0.021) % 1],
            ),
        ],
      );
      // Mide ~444 KB (el límite de Firestore es 1 MiB; el nuestro, 700 KB).
      expect(MatchSyncService.playBytes(big), lessThan(MatchSyncService.maxDocumentBytes));
    });

    test('guardar y borrar suben solos; el borrado deja la jugada oculta, no la borra', () async {
      await appData.savePlay(play('p1'));
      expect(appData.plays.single.updatedAt, now);
      expect(store.doc(SyncCollection.plays, _uidA, 'p1')!['name'], 'Jugada');

      await appData.saveFixtureEntry(entry('f1'));
      expect(store.doc(SyncCollection.fixture, _uidA, 'f1'), isNotNull);

      now = now.add(const Duration(minutes: 1));
      await appData.deletePlay('p1');
      await appData.deleteFixtureEntry('f1');
      expect(appData.plays, isEmpty);
      expect(appData.hiddenPlays.single.id, 'p1');
      expect(appData.fixtureEntries, isEmpty);
      expect(store.doc(SyncCollection.plays, _uidA, 'p1')!['deletedAt'], isA<Timestamp>());
      expect(store.doc(SyncCollection.fixture, _uidA, 'f1')!['deletedAt'], isA<Timestamp>());
    });

    test('pull: gana el updatedAt más nuevo, deletedAt oculta y el fixture apunta a partidos que bajan', () async {
      await appData.savePlay(play('p1', name: 'Local nueva'));
      store.putRemote(SyncCollection.plays, _uidA, 'p1',
          MatchSyncService.playToFirestoreJson(play('p1', name: 'Vieja', updatedAt: now.subtract(const Duration(days: 1)))));
      store.putRemote(SyncCollection.plays, _uidA, 'p2',
          MatchSyncService.playToFirestoreJson(play('p2', name: 'Solo remota', updatedAt: now)));
      store.putRemote(SyncCollection.plays, _uidA, 'p3',
          MatchSyncService.playToFirestoreJson(play('p3', updatedAt: now, deletedAt: now)));
      // Un partido y su fila del fixture, cargados en otro dispositivo.
      store.putRemote(SyncCollection.matches, _uidA, 'm1',
          MatchSyncService.matchToFirestoreJson(_match('m1', updatedAt: now)));
      store.putRemote(SyncCollection.fixture, _uidA, 'f1',
          MatchSyncService.fixtureToFirestoreJson(entry('f1', updatedAt: now, linkedMatchId: 'm1')));

      await sync.pull();
      expect(appData.findPlay('p1')!.name, 'Local nueva');
      expect(store.doc(SyncCollection.plays, _uidA, 'p1')!['name'], 'Local nueva', reason: 'lo local más nuevo se re-sube');
      expect(appData.plays.map((p) => p.id), containsAll(['p1', 'p2']));
      expect(appData.hiddenPlays.map((p) => p.id), ['p3']);
      expect(appData.linkedMatchOf(appData.fixtureEntries.single)!.id, 'm1', reason: 'figura como jugada');
      expect(appData.findPlay('p2')!.updatedAt, now, reason: 'conserva el updatedAt remoto');
    });

    test('vincular y desvincular un partido viaja como edición de la fila', () async {
      await appData.saveMatch(_match('m1'), isPremium: true);
      await appData.saveFixtureEntry(entry('f1'));
      await appData.linkFixtureEntryToMatch('f1', 'm1');
      expect(store.doc(SyncCollection.fixture, _uidA, 'f1')!['linkedMatchId'], 'm1');
      await appData.trashMatch('m1');
      await appData.deleteMatch('m1');
      expect(store.doc(SyncCollection.fixture, _uidA, 'f1')!['linkedMatchId'], isNull);
    });

    test('con el consentimiento 2.0 no viajan hasta aceptar la 2.1; después sube lo que faltaba', () async {
      await appData.closeAccount();
      await openAs(_uidA, consent: '2.0');
      expect(kPrivacyPolicyVersion, '2.1');
      expect(sync.needsPolicyUpdate, isTrue);

      await appData.saveMatch(_match('m1'), isPremium: true);
      await appData.savePlay(play('p1'));
      await appData.saveFixtureEntry(entry('f1'));
      store.putRemote(SyncCollection.plays, _uidA, 'remota',
          MatchSyncService.playToFirestoreJson(play('remota', updatedAt: now)));
      await sync.uploadAll();
      expect(store.doc(SyncCollection.matches, _uidA, 'm1'), isNotNull, reason: 'partidos y equipos siguen igual');
      expect(store.doc(SyncCollection.plays, _uidA, 'p1'), isNull);
      expect(store.count(SyncCollection.fixture, _uidA), 0);
      expect(appData.findPlay('remota'), isNull, reason: 'tampoco baja');

      // Aceptó la 2.1 en otro dispositivo: refreshConsent lo trae del servidor.
      store.consentVersion = '2.1';
      expect(await sync.refreshConsent(), isFalse);
      expect(sync.coversPlaysAndFixture, isTrue);
      await storage.saveAccountValue(StorageService.cloudConsentVersionKey, _uidA, '2.0');
      store.consentVersion = '2.0';
      expect(await sync.refreshConsent(), isTrue);

      // "Entendido" en este dispositivo.
      final writesBefore = store.writes;
      await sync.acceptCurrentPolicy();
      await sync.uploadAll();
      expect(store.consentVersion, '2.1');
      expect(sync.needsPolicyUpdate, isFalse);
      expect(store.doc(SyncCollection.plays, _uidA, 'p1'), isNotNull);
      expect(store.doc(SyncCollection.fixture, _uidA, 'f1'), isNotNull);
      expect(appData.findPlay('remota'), isNotNull);
      expect(store.writes - writesBefore, 3,
          reason: 'las dos jugadas (también la que bajó) y la fila; el partido ya estaba');
    });

    test('activar la nube desde cero acepta la política vigente', () async {
      await storage.saveAccountValue(StorageService.cloudSyncKey, _uidA, null);
      await storage.saveAccountValue(StorageService.cloudConsentVersionKey, _uidA, null);
      await appData.savePlay(play('p1'));
      await sync.setCloudSync(true);
      await sync.uploadAll();
      expect(sync.coversPlaysAndFixture, isTrue);
      expect(store.consentVersion, kPrivacyPolicyVersion);
      expect(store.doc(SyncCollection.plays, _uidA, 'p1'), isNotNull);
      expect(MatchSyncService.compareVersions('2.10', '2.9'), 1);
      expect(MatchSyncService.compareVersions('2.0', '2.1'), -1);
    });

    test('subida inicial, purga a los 30 días, copia completa y borrar la copia remota', () async {
      await appData.savePlay(play('p1'), syncToCloud: false);
      await appData.saveFixtureEntry(entry('f1'), syncToCloud: false);
      await appData.saveFixtureEntry(entry('f2'), syncToCloud: false);
      await appData.deleteFixtureEntry('f2');
      await sync.uploadAll();
      expect(store.count(SyncCollection.plays, _uidA), 1);
      expect(store.count(SyncCollection.fixture, _uidA), 2, reason: 'la borrada viaja con su marca');
      expect(sync.uploadTotal, 3);

      // Exportar todo incluye las ocultas; importar no las duplica.
      final json = appData.buildBackupJson();
      expect((json['fixture'] as List).length, 2);
      final summary = await appData.importBackup(FullBackup.parse(json), applyFreeCap: false);
      expect(summary.alreadyExisted, 3);
      expect(appData.hiddenFixtureEntries.single.id, 'f2');

      now = now.add(const Duration(days: 31));
      await appData.closeAccount();
      await appData.openAccount(_uidA);
      await sync.purgeRemote();
      expect(appData.hiddenFixtureEntries, isEmpty);
      expect(storage.loadFixtureEntries().map((e) => e.id), ['f1']);
      expect(store.doc(SyncCollection.fixture, _uidA, 'f2'), isNull);

      await sync.deleteAllRemote(_uidA);
      expect(store.count(SyncCollection.plays, _uidA), 0);
      expect(store.count(SyncCollection.fixture, _uidA), 0);
      expect(appData.plays.single.id, 'p1', reason: 'nunca toca lo local');
    });
  });

  test('borrar los datos de una cuenta (al eliminarla) solo toca esa cuenta', () async {
    await appData.saveMatch(_match('deA'), isPremium: true);
    await appData.closeAccount();
    await openAs(_uidB);
    await appData.saveMatch(_match('deB'), isPremium: true);
    await appData.closeAccount();
    await storage.deleteUserData(_uidB);
    await openAs(_uidB);
    expect(appData.matches, isEmpty);
    expect(storage.loadAccountValue(StorageService.cloudCursorMatchesKey, _uidB), isNull);
    await appData.closeAccount();
    await openAs(_uidA);
    expect(appData.matches.map((m) => m.id), ['deA']);
  });
}
