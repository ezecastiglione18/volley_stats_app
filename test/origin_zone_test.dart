// Pruebas de la zona de salida del ataque y la contra (RallyEvent.originZone):
// carga, guardado, mapas de dirección, gráfico "Ataque por zona de salida" y
// la opción de la formación (premium, destildada por defecto).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/match_set.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/visual_stats.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/live/widgets/touch_dialog.dart';
import 'package:rally_stats/screens/new_match/lineup_screen.dart';
import 'package:rally_stats/services/stats_engine.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
import 'package:rally_stats/utils/grade_labels.dart';
import 'package:rally_stats/utils/theme.dart';

Player _p(String id, int number, PlayerPosition pos) =>
    Player(id: id, firstName: id, lastName: id, number: number, position: pos);

final _roster = [
  _p('A1', 1, PlayerPosition.armador),
  _p('P1', 2, PlayerPosition.puntaReceptor),
  _p('C1', 3, PlayerPosition.central),
  _p('O1', 4, PlayerPosition.opuesto),
  _p('P2', 5, PlayerPosition.puntaReceptor),
  _p('C2', 6, PlayerPosition.central),
];

const _order = ['A1', 'P1', 'C1', 'O1', 'P2', 'C2'];

MatchController _newController({bool trackOrigin = true, bool trackZones = true}) {
  final match = VolleyMatch(
    id: 'match_origin_${DateTime.now().microsecondsSinceEpoch}',
    date: DateTime(2026, 10, 26),
    ownTeamName: 'Propio',
    ownRoster: _roster,
    rivalTeamName: 'Rival',
    config: MatchConfig(),
  );
  final c = MatchController(match);
  c.startSet(
    setNumber: 1,
    startingOrderOwn: List.of(_order),
    startingServer: TeamSide.rival,
    trackHitZones: trackZones,
    trackOriginZone: trackOrigin,
  );
  return c;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_origin_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();
    await StorageService.instance.openUserBoxes('test-uid');
  });

  group('Modelo y carga', () {
    test('JSON con y sin los campos nuevos', () {
      final ev = RallyEvent(
        id: 'e1',
        setNumber: 1,
        rallyNumber: 1,
        phase: RallyPhase.attack,
        team: TeamSide.own,
        playerIds: const ['O1'],
        grade: Grade.pp,
        endsRally: true,
        pointWinner: TeamSide.own,
        servingTeamBefore: TeamSide.rival,
        ownScoreAfter: 1,
        rivalScoreAfter: 0,
        timestamp: DateTime(2026, 10, 26),
        originZone: 2,
      );
      expect(RallyEvent.fromJson(ev.toJson()).originZone, 2);
      expect(RallyEvent.fromJson(ev.toJson()..remove('originZone')).originZone, isNull);

      final set = MatchSet(setNumber: 1, startingOrderOwn: _order, startingServer: TeamSide.own, trackOriginZone: true);
      expect(MatchSet.fromJson(set.toJson()).trackOriginZone, isTrue);
      expect(MatchSet.fromJson(set.toJson()..remove('trackOriginZone')).trackOriginZone, isFalse);
    });

    test('se guarda solo en ataque y contra, con el registro activo, también en un rejuego', () {
      final c = _newController(trackZones: false); // independiente de la zona de destino
      c.logReception('P1', Grade.p);
      c.logAttack('O1', Grade.p, replay: true, originZone: 2);
      expect(c.currentSet.events.last.originZone, 2);
      expect(c.currentSet.events.last.replay, isTrue);
      c.logCounter('P2', Grade.pp, originZone: 5);
      expect(c.currentSet.events.last.originZone, 5);
      c.logServe('P1', Grade.n); // un saque nunca lleva zona de salida
      expect(c.currentSet.events.last.originZone, isNull);

      final off = _newController(trackOrigin: false);
      off.logReception('P1', Grade.p);
      off.logAttack('O1', Grade.pp, originZone: 2);
      expect(off.currentSet.events.last.originZone, isNull);
    });
  });

  group('Estadística', () {
    test('la flecha del mapa arranca en la zona de salida registrada', () {
      final c = _newController();
      c.logReception('P1', Grade.p);
      c.logAttack('O1', Grade.pp, targetZone: 5, originZone: 1); // ataque desde el fondo
      c.logReception('P1', Grade.p);
      c.logAttack('O1', Grade.pp, targetZone: 5); // sin zona de salida: se deduce
      final shots = StatsEngine.computeShots(c.match).shots;
      expect(shots, hasLength(2));
      expect((shots[0].originX, shots[0].originY), StatsEngine.originZoneCenter(1));
      expect((shots[1].originX, shots[1].originY), isNot(StatsEngine.originZoneCenter(1)));
      // Zona 1 = fondo derecha, zona 4 = red izquierda.
      final (x1, y1) = StatsEngine.originZoneCenter(1)!;
      final (x4, y4) = StatsEngine.originZoneCenter(4)!;
      expect(x1, greaterThan(x4));
      expect(y1, greaterThan(y4));
    });

    test('ataques y contras por zona de salida, con los que quedaron sin zona aparte', () {
      final c = _newController();
      c.logReception('P1', Grade.p);
      c.logAttack('O1', Grade.pp, originZone: 2);
      c.logReception('P1', Grade.p);
      c.logAttack('O1', Grade.nn, originZone: 2);
      c.logReception('P1', Grade.p);
      c.logAttack('P2', Grade.p, originZone: 4);
      c.logCounter('P2', Grade.pp, originZone: 4);
      c.logReception('P1', Grade.p);
      c.logAttack('C1', Grade.pp); // sin zona
      final origin = StatsEngine.computeOriginZones(c.match);
      expect(origin.attackByZone[2]!.total, 2);
      expect(origin.attackByZone[2]!.pp, 1);
      expect(origin.attackByZone[4]!.total, 1);
      expect(origin.counterByZone[4]!.pp, 1);
      expect(origin.combinedByZone[4]!.total, 2);
      expect(origin.missingZone, 1);
      expect(origin.hasAnyData, isTrue);
      expect(StatsEngine.computeOriginZones(_newController().match).hasAnyData, isFalse);
    });

    test('un set simulado con el registro activo carga zonas de salida y no rompe la estadística', () {
      final c = _newController();
      c.simulateRestOfSet();
      expect(c.currentSet.finished, isTrue);
      final origin = StatsEngine.computeOriginZones(c.match);
      expect(origin.hasAnyData, isTrue);
      final stats = StatsEngine.compute(c.match);
      final attacks = stats.team.ataque.total + stats.team.contra.total;
      var withZone = 0;
      for (final s in origin.combinedByZone.values) {
        withZone += s.total;
      }
      expect(withZone + origin.missingZone, attacks);
    });
  });

  group('Pantallas', () {
    testWidgets('la fila 1-6 aparece solo con el registro activo y se manda en onConfirm', (tester) async {
      int? gotOrigin = -1;
      Future<void> open(bool trackOrigin) async {
        await tester.pumpWidget(MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTouchDialog(
                    context: context,
                    title: 'Ataque',
                    players: [_roster[3]],
                    fixedPlayerId: _roster[3].id,
                    grades: attackCounterGrades,
                    trackOrigin: trackOrigin,
                    onConfirm: (player, grade, zone, miss, replay, origin) => gotOrigin = origin,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
      }

      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);

      await open(false);
      expect(find.text('¿Desde qué zona? (opcional)'), findsNothing);
      await tester.tap(find.text('P\nPositiva'));
      await tester.pumpAndSettle();
      expect(gotOrigin, isNull);

      await open(true);
      expect(find.text('¿Desde qué zona? (opcional)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('origin-zone-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P\nPositiva'));
      await tester.pumpAndSettle();
      expect(gotOrigin, 2);
    });

    Future<void> pumpLineup(WidgetTester tester, {required bool premium}) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final subs = SubscriptionController()..isPremium = premium;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppDataController()),
          ChangeNotifierProvider.value(value: ThemeController()),
          ChangeNotifierProvider<SubscriptionController>.value(value: subs),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: LineupScreen(
            ownTeamName: 'Propio',
            ownTeamSourceId: null,
            rivalTeamName: 'Rival',
            rivalTeamSourceId: null,
            tournament: '',
            round: '',
            court: '',
            category: '',
            date: DateTime(2026, 10, 26),
            config: MatchConfig(),
            roster: _roster,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    CheckboxListTile originTile(WidgetTester tester) =>
        tester.widget<CheckboxListTile>(find.byKey(const ValueKey('track-origin-zone')));

    testWidgets('formación: "Registrar zona de salida" arranca destildado y es premium', (tester) async {
      await pumpLineup(tester, premium: true);
      await tester.ensureVisible(find.byKey(const ValueKey('track-origin-zone')));
      expect(originTile(tester).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('track-origin-zone')));
      await tester.pumpAndSettle();
      expect(originTile(tester).value, isTrue);

      await pumpLineup(tester, premium: false);
      await tester.ensureVisible(find.byKey(const ValueKey('track-origin-zone')));
      expect(originTile(tester).value, isFalse);
      expect(
          find.descendant(of: find.byKey(const ValueKey('track-origin-zone')), matching: find.byIcon(Icons.lock_outline)),
          findsOneWidget);
    });
  });

  test('preferencias: el gráfico nuevo aparece aunque ya hubiera una selección guardada', () async {
    final storage = StorageService.instance;
    // Una selección guardada antes de que existiera el gráfico (sin "_known").
    await storage.saveScreenVisualCharts({VisualChart.dashboard});
    expect(storage.loadScreenVisualCharts(), {VisualChart.dashboard});
    // Simula la versión anterior: sin la lista de conocidos.

    await storage.debugRemoveSetting('screen_visual_charts_known');
    expect(storage.loadScreenVisualCharts(), {VisualChart.dashboard, VisualChart.attackOrigin});
    // Si el usuario lo saca, queda sacado.
    await storage.saveScreenVisualCharts({VisualChart.dashboard});
    expect(storage.loadScreenVisualCharts(), {VisualChart.dashboard});
  });
}
