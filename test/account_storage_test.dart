// Datos locales por cuenta (sección 3, Etapa 1 de
// documents/RallyStats-Funcionalidades-Pendientes.pdf): cajones por cuenta con
// dueño legacy, copia previa, cierre sin borrar, sufijo de los cajones, caché
// de la suscripción y cupo free por cuenta (con un fake de Firestore), copia
// completa (Exportar todo / Importar / Restaurar) y el error claro con los
// cajones cerrados.
//
// Cada test arranca con un directorio temporal propio y StorageService
// reseteado (`resetForTest`), igual que la app recién instalada, salvo lo que
// el test siembre antes en los cajones de siempre (como una versión vieja).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:rally_stats/models/fixture_entry.dart';
import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/play.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/team.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/services/free_stats_quota_store.dart';
import 'package:rally_stats/services/full_backup.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';

/// `account_devices/{uid}.freeStatsMatchId` en memoria.
class _FakeQuotaStore implements FreeStatsQuotaStore {
  final Map<String, String> registered = {};
  bool online = true;
  int writes = 0;

  @override
  Future<String?> read(String uid) async {
    if (!online) throw FreeStatsOfflineException('sin red');
    return registered[uid];
  }

  @override
  Future<String> claimIfAbsent(String uid, String matchId) async {
    if (!online) throw FreeStatsOfflineException('sin red');
    final existing = registered[uid];
    if (existing != null) return existing;
    writes++;
    return registered[uid] = matchId;
  }
}

Team _team(String id, [String? name]) => Team(id: id, name: name ?? 'Equipo $id');

VolleyMatch _match(String id, {DateTime? date}) => VolleyMatch(
      id: id,
      date: date ?? DateTime(2026, 5, 1),
      ownTeamName: 'Propio',
      ownRoster: const [],
      rivalTeamName: 'Rival $id',
      config: MatchConfig(),
    );

Play _play(String id) => Play(id: id, name: 'Jugada $id', date: DateTime(2026, 4, 1), strokes: const []);

FixtureEntry _fixture(String id, {String? linkedMatchId}) =>
    FixtureEntry(id: id, date: DateTime(2026, 6, 1), rivalTeamName: 'Rival', linkedMatchId: linkedMatchId);

const _uidA = 'UidDeLaCuentaA00000000000001';
const _uidB = 'UidDeLaCuentaB00000000000002';

late Directory _dir;

/// Datos guardados por una versión anterior, en los cajones de siempre.
Future<void> _seedLegacyData() async {
  Hive.init(_dir.path);
  final teams = await Hive.openBox('teams_box');
  await teams.put('t1', _team('t1', 'Legacy').toJson());
  final matches = await Hive.openBox('matches_box');
  await matches.put('m1', _match('m1').toJson());
  await matches.put('m2', _match('m2', date: DateTime(2026, 5, 2)).toJson());
  final plays = await Hive.openBox('plays_box');
  await plays.put('p1', _play('p1').toJson());
  final fixture = await Hive.openBox('fixture_box');
  await fixture.put('f1', _fixture('f1', linkedMatchId: 'm1').toJson());
  await Hive.close();
}

File _todayBackupFile() => File(
    '${_dir.path}${Platform.pathSeparator}rallystats_backups${Platform.pathSeparator}'
    'rallystats_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json');

Box get _settings => Hive.box('settings_box');

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? _dir.path : null,
    );
  });

  setUp(() async {
    await StorageService.instance.resetForTest();
    _dir = Directory.systemTemp.createTempSync('rally_stats_account_test');
  });

  tearDownAll(() => StorageService.instance.resetForTest());

  final storage = StorageService.instance;

  group('dueño de los datos de siempre', () {
    test('(a) datos existentes con sesión abierta: el dueño es esa cuenta y ve todo, fixture incluido', () async {
      await _seedLegacyData();
      await storage.init();
      // main(): había sesión abierta en el primer arranque de esta versión.
      await storage.ensureLegacyOwner(_uidA);
      // Aunque esa sesión no pase la revalidación, el dueño no cambia.
      await storage.ensureLegacyOwner(_uidB);
      expect(storage.legacyOwnerUid, _uidA);

      final data = AppDataController();
      await data.openAccount(_uidA);
      expect(data.teams.map((t) => t.id), ['t1']);
      expect(data.matches.map((m) => m.id).toSet(), {'m1', 'm2'});
      expect(data.plays.map((p) => p.id), ['p1']);
      expect(data.fixtureEntries.map((e) => e.id), ['f1']);
      expect(data.linkedMatchOf(data.fixtureEntries.single)?.id, 'm1');
    });

    test('(b) datos existentes sin sesión: el primer login es el dueño', () async {
      await _seedLegacyData();
      await storage.init();
      expect(storage.legacyOwnerUid, isNull);

      final data = AppDataController();
      await data.openAccount(_uidB);
      expect(storage.legacyOwnerUid, _uidB);
      expect(data.matches, hasLength(2));
      expect(data.fixtureEntries, hasLength(1));

      await data.closeAccount();
      await data.openAccount(_uidA);
      expect(storage.legacyOwnerUid, _uidB);
      expect(data.matches, isEmpty);
    });

    test('(c) una segunda cuenta ve el archivo y el fixture vacíos, crea un partido, y el dueño ve solo lo suyo',
        () async {
      await _seedLegacyData();
      await storage.init();
      await storage.ensureLegacyOwner(_uidA);
      final data = AppDataController();

      await data.openAccount(_uidB);
      expect(data.teams, isEmpty);
      expect(data.matches, isEmpty);
      expect(data.plays, isEmpty);
      expect(data.fixtureEntries, isEmpty);
      await data.saveMatch(_match('deB'), isPremium: false);
      await data.saveFixtureEntry(_fixture('filaB'));
      await data.closeAccount();

      await data.openAccount(_uidA);
      expect(data.matches.map((m) => m.id).toSet(), {'m1', 'm2'});
      expect(data.fixtureEntries.map((e) => e.id), ['f1']);
      await data.closeAccount();

      await data.openAccount(_uidB);
      expect(data.matches.map((m) => m.id), ['deB']);
      expect(data.fixtureEntries.map((e) => e.id), ['filaB']);
      // La segunda cuenta tiene sus propios cajones, con el sufijo.
      expect(await Hive.boxExists('matches_box_${boxSuffixFor(_uidB)}'), isTrue);
    });

    test('el tope de 3 partidos free es por cuenta', () async {
      await storage.init();
      final data = AppDataController();
      await data.openAccount(_uidA);
      for (final id in ['a1', 'a2', 'a3']) {
        await data.saveMatch(_match(id), isPremium: false);
      }
      expect(() => data.saveMatch(_match('a4'), isPremium: false), throwsA(isA<MatchArchiveLimitException>()));
      await data.closeAccount();

      await data.openAccount(_uidB);
      await data.saveMatch(_match('b1'), isPremium: false);
      expect(data.matches, hasLength(1));
    });
  });

  group('(d) copia previa', () {
    test('contiene los 4 cajones con el formato de la copia completa y se hace una sola vez', () async {
      await _seedLegacyData();
      await storage.init();

      final file = _todayBackupFile();
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['format'], 'rallystats_backup');
      expect(json['version'], 1);
      expect(DateTime.tryParse(json['createdAt'] as String), isNotNull);
      expect(json['appVersion'], isNotEmpty);
      final backup = FullBackup.parse(json);
      expect(backup.teams.map((t) => t.id), ['t1']);
      expect(backup.matches.map((m) => m.id).toSet(), {'m1', 'm2'});
      expect(backup.plays.map((p) => p.id), ['p1']);
      expect(backup.fixture.map((e) => e.id), ['f1']);
      // La copia no movió nada: los cajones de siempre siguen intactos.
      await storage.ensureLegacyOwner(_uidA);
      final data = AppDataController();
      await data.openAccount(_uidA);
      expect(data.matches, hasLength(2));
      await data.closeAccount();

      // Segundo arranque: no se repite.
      file.deleteSync();
      await storage.resetForTest();
      await storage.init();
      expect(file.existsSync(), isFalse);
    });

    test('si falla, el arranque sigue y se reintenta en el próximo', () async {
      await _seedLegacyData();
      storage.backupsDirectoryResolver = () async => throw const FileSystemException('disco simulado');
      await storage.init();
      expect(_todayBackupFile().existsSync(), isFalse);
      // El arranque siguió: se pueden abrir los datos.
      final data = AppDataController();
      await data.openAccount(_uidA);
      expect(data.matches, hasLength(2));
      await data.closeAccount();

      await storage.resetForTest(); // también vuelve al directorio normal
      await storage.init();
      expect(_todayBackupFile().existsSync(), isTrue);
    });

    test('instalación nueva (sin datos): no escribe archivo', () async {
      await storage.init();
      expect(_todayBackupFile().existsSync(), isFalse);
    });
  });

  test('(e) cerrar sesión no borra nada', () async {
    await _seedLegacyData();
    await storage.init();
    final data = AppDataController();
    await data.openAccount(_uidA);
    await data.closeAccount();
    await data.openAccount(_uidB);
    await data.saveTeam(_team('tb'));
    await data.closeAccount();

    expect(data.teams, isEmpty);
    expect(data.matches, isEmpty);
    expect(storage.openUid, isNull);
    for (final name in ['teams_box', 'matches_box', 'plays_box', 'fixture_box']) {
      expect(await Hive.boxExists(name), isTrue, reason: name);
    }
    await data.openAccount(_uidA);
    expect(data.matches, hasLength(2));
    expect(data.fixtureEntries, hasLength(1));
    await data.openAccount(_uidB);
    expect(data.teams.map((t) => t.id), ['tb']);
  });

  group('(f) boxSuffixFor', () {
    test('dos uid que solo difieren en mayúsculas dan sufijos distintos', () {
      expect(boxSuffixFor('abcDEF123'), isNot(boxSuffixFor('abcdef123')));
      expect(boxSuffixFor('Ab'), isNot(boxSuffixFor('aB')));
    });

    test('es puro, solo usa minúsculas y dígitos 2-7, y no choca entre uids distintos', () {
      expect(boxSuffixFor(_uidA), boxSuffixFor(_uidA));
      expect(boxSuffixFor(_uidA), matches(RegExp(r'^[a-z2-7]+$')));
      expect(boxSuffixFor(_uidA), boxSuffixFor(_uidA).toLowerCase());
      final suffixes = {for (var i = 0; i < 500; i++) boxSuffixFor('uid$i'), boxSuffixFor('UID1')};
      expect(suffixes, hasLength(501));
      expect(() => boxSuffixFor(''), throwsArgumentError);
    });

    test('el nombre entra en el límite de Hive (255) aun con un uid de 128 caracteres', () {
      final longest = ['teams_box', 'matches_box', 'plays_box', 'fixture_box']
          .map((b) => b.length)
          .reduce((a, b) => a > b ? a : b);
      expect(longest + 1 + boxSuffixFor('x' * 128).length, lessThanOrEqualTo(255));
      // Uid de email/contraseña de Firebase (28 caracteres).
      expect('fixture_box_${boxSuffixFor(_uidA)}'.length, 57);
    });
  });

  group('(g) claves por cuenta', () {
    test('subscription_cache es por cuenta; el dueño legacy conserva la clave de siempre', () async {
      await storage.init();
      await storage.ensureLegacyOwner(_uidA);
      await storage.saveSubscriptionCache(_uidA, {'isPremium': true, 'deviceLimit': 2});
      expect(storage.loadSubscriptionCache(_uidA), {'isPremium': true, 'deviceLimit': 2});
      expect(storage.loadSubscriptionCache(_uidB), isNull);
      expect(_settings.get('subscription_cache'), isNotNull);

      await storage.saveSubscriptionCache(_uidB, {'isPremium': false, 'deviceLimit': 1});
      expect(_settings.get('subscription_cache_${boxSuffixFor(_uidB)}'), isNotNull);
      expect(storage.loadSubscriptionCache(_uidA)!['isPremium'], isTrue);
    });

    test('el cupo free registrado se conserva aunque se borre el partido', () async {
      await storage.init();
      final quota = _FakeQuotaStore();
      final data = AppDataController(quotaStore: quota);
      await data.openAccount(_uidA);
      await data.saveMatch(_match('m1'), isPremium: false);
      await data.registerFreeStatsUsage('m1');
      await data.deleteMatch('m1');
      expect(data.freeStatsMatchId, 'm1');

      await data.closeAccount();
      quota.online = false;
      await data.openAccount(_uidA);
      await data.syncFreeStatsQuota();
      expect(data.freeStatsMatchId, 'm1');
      // La caché del dueño legacy es la clave de siempre.
      expect(_settings.get('free_stats_match_id'), 'm1');
    });
  });

  group('(g2) cupo free contra Firestore (fake)', () {
    late _FakeQuotaStore quota;
    late AppDataController data;

    setUp(() async {
      await storage.init();
      await storage.ensureLegacyOwner(_uidA);
      quota = _FakeQuotaStore();
      data = AppDataController(quotaStore: quota);
    });

    test('registrar escribe solo si no existe', () async {
      await data.openAccount(_uidB);
      await data.registerFreeStatsUsage('m1');
      expect(quota.registered[_uidB], 'm1');
      expect(data.freeStatsMatchId, 'm1');
      // Ya gastado: no se vuelve a escribir.
      await data.registerFreeStatsUsage('m2');
      expect(quota.registered[_uidB], 'm1');
      expect(quota.writes, 1);
      expect(storage.loadFreeStatsMatchId(_uidB), 'm1');
    });

    test('si otro dispositivo ya registró otro partido, gana el que estaba', () async {
      quota.registered[_uidB] = 'otroDispositivo';
      await data.openAccount(_uidB); // sin sincronizar todavía: la caché local está vacía
      expect(data.freeStatsMatchId, isNull);
      await data.registerFreeStatsUsage('m1');
      expect(data.freeStatsMatchId, 'otroDispositivo');
      expect(quota.registered[_uidB], 'otroDispositivo');
      expect(storage.loadFreeStatsMatchId(_uidB), 'otroDispositivo');
    });

    test('sin red no registra nada', () async {
      quota.online = false;
      await data.openAccount(_uidB);
      await expectLater(data.registerFreeStatsUsage('m1'), throwsA(isA<FreeStatsOfflineException>()));
      expect(data.freeStatsMatchId, isNull);
      expect(storage.loadFreeStatsMatchId(_uidB), isNull);
      expect(quota.registered, isEmpty);
    });

    test('al loguearse se trae el registrado y se actualiza la caché', () async {
      quota.registered[_uidB] = 'mRemoto';
      await data.openAccount(_uidB);
      await data.syncFreeStatsQuota();
      expect(data.freeStatsMatchId, 'mRemoto');
      expect(storage.loadFreeStatsMatchId(_uidB), 'mRemoto');
      expect(quota.writes, 0);
    });

    test('migración: la caché local se sube solo si el campo no existe', () async {
      // Instalación vieja: el cupo se gastó cuando era por dispositivo.
      await storage.saveFreeStatsMatchId(_uidA, 'mLocal');
      await data.openAccount(_uidA);
      await data.syncFreeStatsQuota();
      expect(quota.registered[_uidA], 'mLocal');
      await data.closeAccount();

      // Si el campo ya existe, gana el del servidor y la caché se corrige.
      quota.registered[_uidB] = 'mServidor';
      await storage.saveFreeStatsMatchId(_uidB, 'mLocalB');
      await data.openAccount(_uidB);
      await data.syncFreeStatsQuota();
      expect(quota.registered[_uidB], 'mServidor');
      expect(data.freeStatsMatchId, 'mServidor');
      expect(storage.loadFreeStatsMatchId(_uidB), 'mServidor');
      expect(quota.writes, 1);
    });
  });

  group('(h) copia completa', () {
    late AppDataController data;

    FullBackup backupWith({List<Team>? teams, List<VolleyMatch>? matches, List<Play>? plays, List<FixtureEntry>? fixture}) =>
        FullBackup.parse(jsonDecode(jsonEncode(FullBackup.buildJson(
          teams: teams ?? const [],
          matches: matches ?? const [],
          plays: plays ?? const [],
          fixture: fixture ?? const [],
          createdAt: DateTime(2026, 10, 23),
          appVersion: '1.2.0+16',
        ))));

    setUp(() async {
      await storage.init();
      data = AppDataController();
      await data.openAccount(_uidA);
    });

    test('Exportar todo e Importar: ida y vuelta entre cuentas', () async {
      await data.saveTeam(_team('t1'));
      await data.saveMatch(_match('m1'), isPremium: true);
      await data.savePlay(_play('p1'));
      await data.saveFixtureEntry(_fixture('f1', linkedMatchId: 'm1'));
      final exported = FullBackup.parse(jsonDecode(jsonEncode(data.buildBackupJson())));
      await data.closeAccount();

      await data.openAccount(_uidB);
      final summary = await data.importBackup(exported, applyFreeCap: true);
      expect(summary.imported, 4);
      expect(data.linkedMatchOf(data.fixtureEntries.single)?.id, 'm1');
    });

    test('agrega por id sin pisar lo que ya existe', () async {
      await data.saveTeam(_team('t1', 'Original'));
      final summary = await data.importBackup(
        backupWith(teams: [_team('t1', 'De la copia'), _team('t2')], plays: [_play('p1')], fixture: [_fixture('f1')]),
        applyFreeCap: true,
      );
      expect(summary.teams, 1);
      expect(summary.plays, 1);
      expect(summary.fixture, 1);
      expect(summary.alreadyExisted, 1);
      expect(data.teams.firstWhere((t) => t.id == 't1').name, 'Original');
      expect(storage.loadTeams().firstWhere((t) => t.id == 't1').name, 'Original');
      expect(storage.loadTeams(), hasLength(2));
    });

    test('Importar en free aplica el tope de 3 partidos (entran los más recientes)', () async {
      await data.saveMatch(_match('propio1'), isPremium: false);
      await data.saveMatch(_match('propio2'), isPremium: false);
      final summary = await data.importBackup(
        backupWith(matches: [
          _match('viejo', date: DateTime(2025, 1, 1)),
          _match('nuevo', date: DateTime(2026, 9, 1)),
          _match('medio', date: DateTime(2026, 1, 1)),
          _match('propio1'),
        ]),
        applyFreeCap: true,
      );
      expect(summary.matches, 1);
      expect(summary.matchesSkippedByCap, 2);
      expect(summary.alreadyExisted, 1);
      expect(data.matches.map((m) => m.id).toSet(), {'propio1', 'propio2', 'nuevo'});
      expect(storage.loadMatches(), hasLength(3));
      expect(summary.describe(), contains('2 partidos quedaron afuera por el tope'));
    });

    test('Restaurar copia automática no aplica el tope', () async {
      final summary = await data.importBackup(
        backupWith(matches: [for (var i = 0; i < 5; i++) _match('m$i')]),
        applyFreeCap: false,
      );
      expect(summary.matches, 5);
      expect(summary.matchesSkippedByCap, 0);
      expect(storage.loadMatches(), hasLength(5));
    });

    test('rechaza otro format y una version mayor', () {
      final ok = FullBackup.buildJson(
          teams: const [], matches: const [], plays: const [], fixture: const [],
          createdAt: DateTime(2026), appVersion: '1.2.0+16');
      expect(() => FullBackup.parse({...ok, 'format': 'otra_cosa'}), throwsA(isA<FullBackupFormatException>()));
      expect(() => FullBackup.parse(_match('suelto').toJson()), throwsA(isA<FullBackupFormatException>()));
      expect(() => FullBackup.parse({...ok, 'version': 2}), throwsA(isA<FullBackupFormatException>()));
      expect(() => FullBackup.parse('texto'), throwsA(isA<FullBackupFormatException>()));
      expect(FullBackup.parse(ok).matches, isEmpty);
    });

    test('una foto que no existe en este dispositivo no viaja', () async {
      final team = Team(id: 'tf', name: 'Con foto', players: [
        Player(id: 'p', firstName: 'A', lastName: 'B', number: 1, position: PlayerPosition.armador,
            photoPath: '${_dir.path}/no_existe.jpg'),
      ]);
      await data.importBackup(backupWith(teams: [team]), applyFreeCap: true);
      expect(storage.loadTeams().single.players.single.photoPath, isNull);
    });
  });

  group('(i) con los cajones cerrados', () {
    test('un guardado falla con el error claro (StateError), no con LateInitializationError', () async {
      await storage.init();
      final data = AppDataController();
      await expectLater(data.saveMatch(_match('x'), isPremium: true), throwsA(isA<UserDataClosedError>()));
      await expectLater(data.saveTeam(_team('x')), throwsA(isA<StateError>()));
      expect(() => storage.loadFixtureEntries(), throwsA(isA<UserDataClosedError>()));
      expect(() => storage.loadPlays(), throwsA(predicate((e) => e.toString().contains('iniciar sesión'))));

      await data.openAccount(_uidA);
      await data.closeAccount();
      await expectLater(storage.saveFixtureEntry(_fixture('x')), throwsA(isA<UserDataClosedError>()));
    });

    test('un guardado tardío de la carga en vivo nunca cae en el cajón de otra cuenta', () async {
      await storage.init();
      final data = AppDataController();
      await data.openAccount(_uidA);
      final roster = [
        for (var i = 1; i <= 6; i++)
          Player(id: 'P$i', firstName: 'J$i', lastName: 'T', number: i, position: PlayerPosition.puntaReceptor),
      ];
      final match = VolleyMatch(
        id: 'enVivo',
        date: DateTime(2026, 5, 1),
        ownTeamName: 'Propio',
        ownRoster: roster,
        rivalTeamName: 'Rival',
        config: MatchConfig(),
      );
      await data.saveMatch(match, isPremium: true);
      final controller = MatchController(match)
        ..startSet(
          setNumber: 1,
          startingOrderOwn: [for (final p in roster) p.id],
          startingServer: TeamSide.own,
          trackHitZones: false,
        );

      // Se cierra la sesión con la carga abierta y entra otra cuenta.
      await data.closeAccount();
      await data.openAccount(_uidB);
      controller.simulateRestOfSet(); // cada acción intenta guardar
      await pumpEventQueue();

      expect(storage.loadMatches(), isEmpty);
      await data.closeAccount();
      await data.openAccount(_uidA);
      // En el de su cuenta quedó tal como estaba al cerrar la sesión.
      expect(storage.loadMatches().single.sets, isEmpty);
    });
  });
}
