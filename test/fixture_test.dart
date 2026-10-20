// Fixture con autocompletado (issue #50): JSON de FixtureEntry, JSON viejo de
// VolleyMatch sin fixtureEntryId, vínculo y desvínculo en AppDataController y
// las pantallas del fixture / "Elegir del fixture" en Nuevo Partido.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/models/fixture_entry.dart';
import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/team.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/fixture/fixture_screen.dart';
import 'package:rally_stats/screens/new_match/new_match_screen.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
import 'package:rally_stats/utils/theme.dart';

Player _p(String id, int number, PlayerPosition pos) =>
    Player(id: id, firstName: id, lastName: 'Test', number: number, position: pos);

final _roster = [
  _p('A1', 1, PlayerPosition.armador),
  _p('P1', 2, PlayerPosition.puntaReceptor),
  _p('C1', 3, PlayerPosition.central),
  _p('O1', 4, PlayerPosition.opuesto),
  _p('P2', 5, PlayerPosition.puntaReceptor),
  _p('C2', 6, PlayerPosition.central),
];

/// Partido de un set simulado hasta el final, vinculado (o no) a una fila.
VolleyMatch _playedMatch(String id, {String? fixtureEntryId}) {
  final match = VolleyMatch(
    id: id,
    date: DateTime(2026, 5, 1),
    ownTeamName: 'Propio',
    ownTeamSourceId: 'team-1',
    ownRoster: _roster,
    rivalTeamName: 'Rival',
    config: MatchConfig(),
    fixtureEntryId: fixtureEntryId,
  );
  MatchController(match)
    ..startSet(
      setNumber: 1,
      startingOrderOwn: [for (final p in _roster) p.id],
      startingServer: TeamSide.own,
      trackHitZones: false,
    )
    ..simulateRestOfSet();
  match.status = MatchStatus.finished;
  return match;
}

FixtureEntry _entry(String id, DateTime date, {String rival = 'Los Andes', String tournament = 'Liga'}) =>
    FixtureEntry(id: id, date: date, rivalTeamName: rival, tournament: tournament, round: 'Fecha 3');

void main() {
  late AppDataController appData;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_fixture_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();
    appData = AppDataController();
    await appData.loadAll();
  });

  group('JSON', () {
    test('FixtureEntry: ida y vuelta con todos los campos', () {
      final e = FixtureEntry(
        id: 'fixture_1',
        date: DateTime(2026, 9, 12, 18, 30),
        tournament: 'Liga Metropolitana',
        round: 'Cuartos',
        court: 'Club Norte',
        category: 'Mayores',
        rivalTeamName: 'Los Andes',
        rivalTeamSourceId: 'team-9',
        notes: 'Llevar pelotas',
        linkedMatchId: 'match_7',
      );
      final back = FixtureEntry.fromJson(e.toJson());

      expect(back.id, 'fixture_1');
      expect(back.date, DateTime(2026, 9, 12, 18, 30));
      expect(back.tournament, 'Liga Metropolitana');
      expect(back.round, 'Cuartos');
      expect(back.court, 'Club Norte');
      expect(back.category, 'Mayores');
      expect(back.rivalTeamName, 'Los Andes');
      expect(back.rivalTeamSourceId, 'team-9');
      expect(back.notes, 'Llevar pelotas');
      expect(back.linkedMatchId, 'match_7');
    });

    test('FixtureEntry: los opcionales vuelven null y los textos faltantes, vacíos', () {
      final back = FixtureEntry.fromJson({
        'id': 'f',
        'date': DateTime(2026, 1, 1).toIso8601String(),
        'rivalTeamName': 'X',
      });
      expect(back.rivalTeamSourceId, isNull);
      expect(back.notes, isNull);
      expect(back.linkedMatchId, isNull);
      expect(back.tournament, '');
      expect(back.round, '');
    });

    test('VolleyMatch viejo (sin fixtureEntryId) se lee con null', () {
      final json = _playedMatch('old').toJson()..remove('fixtureEntryId');
      expect(VolleyMatch.fromJson(json).fixtureEntryId, isNull);
    });

    test('VolleyMatch: el fixtureEntryId se guarda y se lee', () {
      final m = _playedMatch('linked', fixtureEntryId: 'fixture_5');
      expect(m.toJson()['fixtureEntryId'], 'fixture_5');
      expect(VolleyMatch.fromJson(m.toJson()).fixtureEntryId, 'fixture_5');
    });
  });

  group('AppDataController: fixture', () {
    test('queda ordenado por fecha ascendente y persiste', () async {
      await appData.saveFixtureEntry(_entry('o3', DateTime(2027, 3, 1)));
      await appData.saveFixtureEntry(_entry('o1', DateTime(2027, 1, 1)));
      await appData.saveFixtureEntry(_entry('o2', DateTime(2027, 2, 1)));

      final mine = appData.fixtureEntries.where((e) => e.id.startsWith('o')).map((e) => e.id).toList();
      expect(mine, ['o1', 'o2', 'o3']);

      final fromHive = StorageService.instance.loadFixtureEntries().where((e) => e.id.startsWith('o'));
      expect(fromHive.map((e) => e.id).toList(), ['o1', 'o2', 'o3']);
    });

    test('editar una fila no la duplica', () async {
      await appData.saveFixtureEntry(_entry('ed', DateTime(2027, 4, 1)));
      final e = appData.fixtureEntries.firstWhere((x) => x.id == 'ed')..rivalTeamName = 'Cambiado';
      await appData.saveFixtureEntry(e);

      expect(appData.fixtureEntries.where((x) => x.id == 'ed'), hasLength(1));
      expect(appData.fixtureEntries.firstWhere((x) => x.id == 'ed').rivalTeamName, 'Cambiado');
    });

    test('eliminar una fila la saca de la lista y de Hive', () async {
      await appData.saveFixtureEntry(_entry('del', DateTime(2027, 5, 1)));
      await appData.deleteFixtureEntry('del');

      expect(appData.fixtureEntries.any((e) => e.id == 'del'), isFalse);
      expect(StorageService.instance.loadFixtureEntries().any((e) => e.id == 'del'), isFalse);
    });

    test('vínculo: al vincular, la fila queda "jugada" con ese partido', () async {
      final match = _playedMatch('m-link', fixtureEntryId: 'lk');
      await appData.saveMatch(match, isPremium: true);
      await appData.saveFixtureEntry(_entry('lk', DateTime(2027, 6, 1)));
      final entry = appData.fixtureEntries.firstWhere((e) => e.id == 'lk');
      expect(appData.linkedMatchOf(entry), isNull, reason: 'antes de vincular: sin jugar');

      await appData.linkFixtureEntryToMatch('lk', 'm-link');

      expect(entry.linkedMatchId, 'm-link');
      expect(appData.linkedMatchOf(entry)?.id, 'm-link');
      expect(
        StorageService.instance.loadFixtureEntries().firstWhere((e) => e.id == 'lk').linkedMatchId,
        'm-link',
        reason: 'el vínculo se persiste',
      );
    });

    test('desvínculo: borrar el partido deja la fila (sin jugar), no la borra', () async {
      final match = _playedMatch('m-unlink', fixtureEntryId: 'ul');
      await appData.saveMatch(match, isPremium: true);
      await appData.saveFixtureEntry(_entry('ul', DateTime(2027, 7, 1)));
      await appData.linkFixtureEntryToMatch('ul', 'm-unlink');

      await appData.deleteMatch('m-unlink');

      final entry = appData.fixtureEntries.firstWhere((e) => e.id == 'ul');
      expect(entry.linkedMatchId, isNull);
      expect(appData.linkedMatchOf(entry), isNull);
      expect(
        StorageService.instance.loadFixtureEntries().firstWhere((e) => e.id == 'ul').linkedMatchId,
        isNull,
        reason: 'el desvínculo también se persiste',
      );
    });

    test('borrar un partido que no estaba vinculado no toca otras filas', () async {
      await appData.saveFixtureEntry(_entry('keep', DateTime(2027, 8, 1)));
      final other = _playedMatch('m-other');
      await appData.saveMatch(other, isPremium: true);
      await appData.linkFixtureEntryToMatch('keep', 'otro-id-distinto');

      await appData.deleteMatch('m-other');

      expect(appData.fixtureEntries.firstWhere((e) => e.id == 'keep').linkedMatchId, 'otro-id-distinto');
    });

    test('un vínculo a un partido que ya no existe cuenta como "sin jugar"', () async {
      await appData.saveFixtureEntry(_entry('dangling', DateTime(2027, 9, 1)));
      await appData.linkFixtureEntryToMatch('dangling', 'no-existe');
      final entry = appData.fixtureEntries.firstWhere((e) => e.id == 'dangling');

      expect(appData.linkedMatchOf(entry), isNull);
    });

    test('vincular una fila que ya no existe no hace nada ni falla', () async {
      await appData.linkFixtureEntryToMatch('fantasma', 'm-x');
      expect(appData.fixtureEntries.any((e) => e.id == 'fantasma'), isFalse);
    });
  });

  group('UI', () {
    late AppDataController ui;

    Widget app(Widget home) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ui),
            ChangeNotifierProvider.value(value: ThemeController()),
            ChangeNotifierProvider.value(value: SubscriptionController()),
          ],
          child: MaterialApp(theme: buildLightTheme(), home: home),
        );

    setUp(() {
      ui = AppDataController();
    });

    testWidgets('sin filas: mensaje de fixture vacío', (tester) async {
      await tester.pumpWidget(app(const FixtureScreen()));
      expect(find.textContaining('Todavía no cargaste partidos en el fixture'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('muestra el próximo y el jugado con su resultado', (tester) async {
      final future = DateTime.now().add(const Duration(days: 10));
      final played = _playedMatch('ui-played');
      ui.matches = [played];
      ui.fixtureEntries = [
        _entry('ui-1', DateTime(2025, 1, 1), rival: 'Rival Jugado')..linkedMatchId = 'ui-played',
        _entry('ui-2', future, rival: 'Rival Proximo'),
        _entry('ui-3', future.add(const Duration(days: 7)), rival: 'Rival Lejano'),
      ];

      await tester.pumpWidget(app(const FixtureScreen()));

      expect(find.text('vs Rival Jugado'), findsOneWidget);
      expect(find.text('Jugado ${played.ownSetsWon}-${played.rivalSetsWon}'), findsOneWidget);
      expect(find.text('Próximo'), findsOneWidget, reason: 'solo la primera fila futura sin jugar');
      expect(find.text('vs Rival Proximo'), findsOneWidget);
      expect(find.text('vs Rival Lejano'), findsOneWidget);
    });

    testWidgets('pickMode: solo filas sin jugar, y tocar una la devuelve', (tester) async {
      final played = _playedMatch('ui-played2');
      ui.matches = [played];
      final pending = _entry('pick-2', DateTime(2027, 3, 14), rival: 'Rival Pendiente');
      ui.fixtureEntries = [
        _entry('pick-1', DateTime(2025, 1, 1), rival: 'Rival Ya Jugado')..linkedMatchId = 'ui-played2',
        pending,
      ];

      FixtureEntry? picked;
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => picked = await Navigator.push<FixtureEntry>(
                context,
                MaterialPageRoute(builder: (_) => const FixtureScreen(pickMode: true)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('vs Rival Ya Jugado'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing, reason: 'en pickMode no se agrega');

      await tester.tap(find.text('vs Rival Pendiente'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'pick-2');
    });

    testWidgets('Nuevo Partido: "Elegir del fixture" autocompleta los campos', (tester) async {
      ui.teams = [Team(id: 'rival-team', name: 'Los Andes FC')];
      ui.fixtureEntries = [
        FixtureEntry(
          id: 'nm-1',
          date: DateTime(2027, 3, 14),
          tournament: 'Liga Norte',
          round: 'Fecha 7',
          court: 'Estadio Sur',
          category: 'Mayores',
          rivalTeamName: 'Los Andes FC',
          rivalTeamSourceId: 'rival-team',
        ),
      ];

      await tester.pumpWidget(app(const NewMatchScreen()));
      await tester.tap(find.text('Elegir del fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('vs Los Andes FC'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Los Andes FC'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Liga Norte'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Fecha 7'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mayores'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Estadio Sur'), findsOneWidget);
      expect(find.text('Fecha: 14/3/2027'), findsOneWidget);
      expect(find.text('Elegido del fixture (tocá para cambiar)'), findsOneWidget);
    });
  });
}
