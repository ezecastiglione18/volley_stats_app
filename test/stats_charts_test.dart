// Pruebas de la estadística visual (pestaña "Gráficos" de Estadísticas y su
// sección en el PDF): rotaciones P1-P6, side-out/break, evolución del
// marcador, origen de los puntos, el PDF con gráficos y la preferencia de
// qué gráficos lleva el PDF. Reglas en documents/spec-estadistica-visual.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/sanction_event.dart';
import 'package:rally_stats/models/visual_stats.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/live/widgets/touch_dialog.dart';
import 'package:rally_stats/screens/matches/match_summary_screen.dart';
import 'package:rally_stats/screens/settings/visual_stats_settings_screen.dart';
import 'package:rally_stats/services/pdf_report_service.dart';
import 'package:rally_stats/services/stats_engine.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/services/visual_stats_preferences.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
import 'package:rally_stats/utils/court_geometry.dart';
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
  _p('U1', 9, PlayerPosition.universal),
  _p('L1', 7, PlayerPosition.libero),
];

// Slot 0 = posición 1 al arrancar: el armador A1 arranca en zona 1 (P1).
const _order = ['A1', 'P1', 'C1', 'O1', 'P2', 'C2'];

// Sin ningún armador en la formación inicial.
const _orderWithoutSetter = ['U1', 'P1', 'C1', 'O1', 'P2', 'C2'];

MatchController _newController({
  List<String> order = _order,
  TeamSide startingServer = TeamSide.own,
  bool nineHitZones = false,
}) {
  final match = VolleyMatch(
    id: 'match_charts_${DateTime.now().microsecondsSinceEpoch}',
    date: DateTime(2026, 10, 2),
    ownTeamName: 'Propio',
    ownRoster: _roster,
    rivalTeamName: 'Rival',
    config: MatchConfig(allowManualRotation: true),
  );
  final controller = MatchController(match);
  controller.startSet(
    setNumber: 1,
    startingOrderOwn: List.of(order),
    startingServer: startingServer,
    trackHitZones: true,
    nineHitZones: nineHitZones,
  );
  return controller;
}

/// Partido de [sets] sets simulados al azar (con "Simular resto del set").
MatchController _simulatedMatch({int sets = 3, bool nineHitZones = false}) {
  final c = _newController(nineHitZones: nineHitZones);
  c.simulateRestOfSet();
  for (var n = 2; n <= sets && !c.match.isMatchOver; n++) {
    c.confirmSetFinished();
    c.startSet(
      setNumber: n,
      startingOrderOwn: List.of(_order),
      startingServer: n.isEven ? TeamSide.rival : TeamSide.own,
      trackHitZones: true,
      nineHitZones: nineHitZones,
    );
    c.simulateRestOfSet();
  }
  return c;
}

/// Vuelve las cuatro preferencias de estadística visual a "todo".
Future<void> _resetVisualPrefs() async {
  final s = StorageService.instance;
  await s.savePdfVisualCharts(VisualChart.values.toSet());
  await s.savePdfCourtMaps(ShotKind.values.toSet());
  await s.saveScreenVisualCharts(VisualChart.values.toSet());
  await s.saveScreenCourtMaps(ShotKind.values.toSet());
}

CourtShot _shotOf(ShotMapData d, String playerId, ShotKind kind) =>
    d.shots.firstWhere((s) => s.playerId == playerId && s.kind == kind);

RotationRow _row(RotationStats s, String label) =>
    [...s.setterRows, ...s.fallbackRows].firstWhere((r) => r.label == label);

void main() {
  // Mismo truco que match_controller_test.dart: MatchController persiste en
  // Hive en cada acción, y Hive necesita path_provider, que no existe en test.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_charts_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();
  });

  group('Rotaciones', () {
    test('P1 con el armador en zona 1; cada side-out ganado pasa a P6 y después a P5', () {
      final c = _newController();
      c.logServe('A1', Grade.pp); // rally 1: break ganado en P1
      c.logServe('A1', Grade.nn); // rally 2: perdido en P1, saca el rival
      c.logOpponentError(); // rally 3: side-out ganado en P1 -> rota
      c.logServe(c.playerAtPosition(1), Grade.nn); // rally 4: perdido en P6
      c.logOpponentError(); // rally 5: side-out ganado en P6 -> rota
      c.logServe(c.playerAtPosition(1), Grade.pp); // rally 6: ganado en P5

      final s = StatsEngine.computeRotations(c.match);
      expect(_row(s, 'P1').rallies, 3);
      expect(_row(s, 'P1').won, 2);
      expect(_row(s, 'P1').servePts, 1);
      expect(_row(s, 'P1').serveErr, 1);
      expect(_row(s, 'P1').rivalErr, 1);
      expect(_row(s, 'P6').rallies, 2);
      expect(_row(s, 'P5').rallies, 1);
      expect(_row(s, 'P5').won, 1);
      expect(s.fallbackSets, isEmpty);
    });

    test('side-out y break-point se cuentan según quién sacaba', () {
      final c = _newController();
      c.logServe('A1', Grade.pp);
      c.logServe('A1', Grade.nn);
      c.logOpponentError();
      c.logServe(c.playerAtPosition(1), Grade.nn);
      c.logOpponentError();
      c.logServe(c.playerAtPosition(1), Grade.pp);

      final t = StatsEngine.computeRotations(c.match).total;
      expect(t.servingRallies, 4);
      expect(t.breakWon, 2);
      expect(t.receivingRallies, 2);
      expect(t.sideOutWon, 2);
      expect(t.breakPct, 0.5);
      expect(t.sideOutPct, 1.0);
    });

    test('una rotación manual cuenta recién desde su rally, no para los anteriores', () {
      final c = _newController();
      c.logServe('A1', Grade.pp); // rally 1 en P1
      c.rotateManually(); // a partir del rally 2: armador pasa a zona 6
      c.logServe(c.playerAtPosition(1), Grade.pp); // rally 2 en P6

      final s = StatsEngine.computeRotations(c.match);
      expect(_row(s, 'P1').rallies, 1);
      expect(_row(s, 'P6').rallies, 1);
    });

    test('invariante: G-P = (+Pts + Adv+Err) - (Adv-Pts + -Err), y suma la diferencia del set', () {
      for (var i = 0; i < 5; i++) {
        final c = _simulatedMatch(sets: 1);
        final s = StatsEngine.computeRotations(c.match);
        for (final r in [...s.setterRows, s.total]) {
          expect(r.diff, (r.ownPts + r.rivalErr) - (r.rivalPts + r.ownErr), reason: 'fila ${r.label}');
        }
        final set = c.match.sets.first;
        expect(s.total.diff, set.ownScore - set.rivalScore);
        expect(s.total.rallies, set.ownScore + set.rivalScore);
        expect(s.setterRows.fold<int>(0, (a, r) => a + r.rallies), s.total.rallies);
      }
    });

    test('un set sin un único armador se cuenta como R1-R6 desde la formación inicial', () {
      final c = _newController(order: _orderWithoutSetter);
      c.logServe('U1', Grade.pp);
      c.logServe('U1', Grade.nn);
      c.logOpponentError(); // side-out: rota

      c.logServe(c.playerAtPosition(1), Grade.pp);

      final s = StatsEngine.computeRotations(c.match);
      expect(s.fallbackSets, [1]);
      expect(s.hasSetterData, isFalse);
      expect(s.mainRows.first.label, 'R1');
      expect(_row(s, 'R1').rallies, 3);
      expect(_row(s, 'R2').rallies, 1);
    });

    test('el filtro de set cuenta solo ese set', () {
      final c = _simulatedMatch(sets: 2);
      final set2 = c.match.sets[1];
      final s = StatsEngine.computeRotations(c.match, setNumber: 2);
      expect(s.total.rallies, set2.ownScore + set2.rivalScore);
      expect(s.total.diff, set2.ownScore - set2.rivalScore);
    });
  });

  group('Clasificación de cada rally', () {
    test('sanción con punto: a favor cuenta como error rival, en contra como error genérico', () {
      final c = _newController();
      c.registerSanction(team: TeamSide.rival, targetKind: SanctionTargetKind.staff, category: SanctionCategory.grosera);
      c.registerSanction(team: TeamSide.own, targetKind: SanctionTargetKind.staff, category: SanctionCategory.grosera);

      final origin = StatsEngine.computePointOrigin(c.match);
      expect(origin.count(RallyCategory.rivalError), 1);
      expect(origin.count(RallyCategory.genericError), 1);
      final t = StatsEngine.computeRotations(c.match).total;
      expect(t.rivalErr, 1);
      expect(t.genErr, 1);
    });

    test('origen de los puntos: ganados y perdidos suman el marcador', () {
      final c = _simulatedMatch(sets: 1);
      final origin = StatsEngine.computePointOrigin(c.match);
      final set = c.match.sets.first;
      expect(origin.won, set.ownScore);
      expect(origin.lost, set.rivalScore);
      expect(origin.count(RallyCategory.otherWon) + origin.count(RallyCategory.otherLost), 0);
    });
  });

  group('Evolución del marcador', () {
    test('la diferencia sigue al marcador y detecta una racha de 4', () {
      final c = _newController();
      for (var i = 0; i < 4; i++) {
        c.logServe(c.playerAtPosition(1), Grade.pp);
      }
      c.logServe(c.playerAtPosition(1), Grade.nn);

      final t = StatsEngine.computeTimelines(c.match).single;
      expect([for (final p in t.points) p.diff], [1, 2, 3, 4, 3]);
      expect(t.ownScore, 4);
      expect(t.rivalScore, 1);
      final runs = t.runs();
      expect(runs, hasLength(1));
      expect(runs.single.length, 4);
      expect(runs.single.team, TeamSide.own);
    });

    test('un set simulado: un punto por rally cerrado, terminando en el resultado del set', () {
      final c = _simulatedMatch(sets: 1);
      final t = StatsEngine.computeTimelines(c.match).single;
      final set = c.match.sets.first;
      expect(t.points, hasLength(set.ownScore + set.rivalScore));
      expect(t.ownScore, set.ownScore);
      expect(t.rivalScore, set.rivalScore);
    });
  });

  group('Eficiencia de ataque', () {
    test('(PP - NN - BLOQ) / total sobre ataque + contra, de mayor a menor', () {
      final c = _newController(startingServer: TeamSide.rival);
      c.logReception('P1', Grade.pp);
      c.logAttack('O1', Grade.pp); // O1: 1 punto
      c.logServe(c.playerAtPosition(1), Grade.p);
      c.logCounter('O1', Grade.bloq); // O1: 1 bloqueado
      c.logReception('P1', Grade.pp);
      c.logAttack('P2', Grade.pp); // P2: 1 punto

      final ranking = StatsEngine.attackRanking(StatsEngine.compute(c.match));
      expect([for (final (l, _) in ranking) l.playerId], ['P2', 'O1']);
      expect(ranking.first.$2.efficiency, 1.0);
      expect(ranking.last.$2.efficiency, 0.0);
    });
  });

  group('Mapas: origen deducido', () {
    test('saque desde el fondo; punta, opuesto y central según estén adelante o atrás', () {
      final c = _newController();
      // Rally 1, formación inicial: A1 en 1, P1 en 2, C1 en 3, O1 en 4, P2 en 5, C2 en 6.
      c.logServe('A1', Grade.p, targetZone: 5);
      c.logCounter('P1', Grade.p, targetZone: 1); // punta adelante (zona 2)
      c.logCounter('O1', Grade.p, targetZone: 5); // opuesto adelante (zona 4)
      c.logCounter('C1', Grade.p, targetZone: 6); // central adelante
      c.logCounter('P2', Grade.p, targetZone: 2); // punta atrás (zona 5) -> pipe
      c.logCounter('C2', Grade.pp, targetZone: 3); // central atrás (zona 6)

      final d = StatsEngine.computeShots(c.match);
      (double, double) origin(String id, ShotKind k) => (_shotOf(d, id, k).originX, _shotOf(d, id, k).originY);
      expect(origin('A1', ShotKind.serve), (0.82, 1.06));
      expect(origin('P1', ShotKind.counter), (0.13, 0.60));
      expect(origin('O1', ShotKind.counter), (0.87, 0.60));
      expect(origin('C1', ShotKind.counter), (0.50, 0.59));
      expect(origin('P2', ShotKind.counter), (0.50, 0.77));
      expect(origin('C2', ShotKind.counter), (0.50, 0.77));
    });

    test('la rotación y los cambios del set cambian el origen', () {
      final c = _newController();
      c.logServe('A1', Grade.pp); // rally 1
      for (var i = 0; i < 3; i++) {
        c.rotateManually(); // O1 (slot 3) pasa a zona 1: opuesto atrás
      }
      c.logServe(c.playerAtPosition(1), Grade.p);
      c.logCounter('O1', Grade.pp, targetZone: 1); // rally 2
      c.substitutePlayer(playerOutId: 'P1', playerInId: 'U1'); // U1 (universal) entra por P1, que está en zona 5
      c.logServe(c.playerAtPosition(1), Grade.p);
      c.logCounter('U1', Grade.p, targetZone: 2);
      c.logOpponentError(); // rally 3

      final d = StatsEngine.computeShots(c.match);
      final o1 = _shotOf(d, 'O1', ShotKind.counter);
      expect((o1.originX, o1.originY), (0.85, 0.76));
      final u1 = _shotOf(d, 'U1', ShotKind.counter);
      expect((u1.originX, u1.originY), (0.15, 0.76)); // universal: según su lugar (zona 5)
    });
  });

  group('Mapas: destino y trazo', () {
    test('centros de zona con 6 y 9 zonas', () {
      expect(StatsEngine.zoneCenter(5, nineZones: false), (5 / 6, 1 / 6));
      expect(StatsEngine.zoneCenter(2, nineZones: false), (1 / 6, 5 / 12));
      expect(StatsEngine.zoneCenter(8, nineZones: true), (0.5, 0.25));
      expect(StatsEngine.zoneCenter(1, nineZones: true), (1 / 6, 1 / 12));
      expect(StatsEngine.zoneCenter(8, nineZones: false), isNull);
    });

    test('el destino es el centro de la zona con un desvío chico y siempre igual', () {
      final c = _simulatedMatch(sets: 1);
      final a = StatsEngine.computeShots(c.match);
      final b = StatsEngine.computeShots(c.match);
      expect(a.shots, isNotEmpty);
      for (var i = 0; i < a.shots.length; i++) {
        final s = a.shots[i];
        expect((s.targetX, s.targetY), (b.shots[i].targetX, b.shots[i].targetY));
        // Bloqueado, a la red y afuera no terminan en la zona (ver sus propios tests).
        if (const {ShotResult.blocked, ShotResult.net, ShotResult.out}.contains(s.result)) continue;
        final center = StatsEngine.zoneCenter(s.event.targetZone!, nineZones: false)!;
        expect((s.targetX - center.$1).abs(), lessThanOrEqualTo(0.05));
        expect((s.targetY - center.$2).abs(), lessThanOrEqualTo(0.05));
      }
    });

    test('calificación a trazo: NN sin detalle es "error"; bloqueado termina en la red aunque no tenga zona', () {
      expect(StatsEngine.shotResultOf(Grade.pp), ShotResult.point);
      expect(StatsEngine.shotResultOf(Grade.p), ShotResult.inPlay);
      expect(StatsEngine.shotResultOf(Grade.n), ShotResult.inPlay);
      expect(StatsEngine.shotResultOf(Grade.bloq), ShotResult.blocked);
      expect(StatsEngine.shotResultOf(Grade.nn), ShotResult.error);

      final c = _newController();
      c.logServe('A1', Grade.p);
      c.logCounter('O1', Grade.bloq); // sin zona
      c.logServe('A1', Grade.p);
      c.logCounter('P1', Grade.nn); // sin zona: no se dibuja
      final d = StatsEngine.computeShots(c.match);
      final blocked = _shotOf(d, 'O1', ShotKind.counter);
      expect(blocked.result, ShotResult.blocked);
      expect(blocked.targetY, 0.52);
      expect(d.where(ShotKind.counter, playerId: 'P1'), isEmpty);
      expect(d.missingZone(ShotKind.counter, playerId: 'P1'), 1);
      expect(d.missingZone(ShotKind.serve), 2);
    });

    test('distancia a un segmento (para tocar una flecha)', () {
      expect(distanceToSegment(5, 5, 0, 0, 10, 0), 5);
      expect(distanceToSegment(-3, 4, 0, 0, 10, 0), 5); // antes del inicio
    });
  });

  group('Errores: afuera o a la red', () {
    test('se guarda solo en un NN, y un partido viejo lo lee como sin detalle', () {
      final c = _newController();
      c.logServe('A1', Grade.p, targetZone: 1, missType: MissType.out); // no es NN: se ignora
      c.logCounter('O1', Grade.nn, targetZone: 5, missType: MissType.out);
      c.logServe(c.playerAtPosition(1), Grade.nn, missType: MissType.net);
      final events = c.match.sets.first.events;
      expect(events[0].missType, isNull);
      expect(events[1].missType, MissType.out);
      expect(events[2].missType, MissType.net);

      final json = jsonDecode(jsonEncode(c.match.toJson())) as Map<String, dynamic>;
      final reloaded = VolleyMatch.fromJson(json);
      expect(reloaded.sets.first.events[1].missType, MissType.out);
      for (final ev in (json['sets'] as List).first['events'] as List) {
        (ev as Map).remove('missType');
      }
      expect(VolleyMatch.fromJson(json).sets.first.events[1].missType, isNull);
    });

    test('sin registro de zona no se guarda (no hay mapa que lo use)', () {
      final match = VolleyMatch(
        id: 'sin_zona',
        date: DateTime(2026, 10, 2),
        ownTeamName: 'Propio',
        ownRoster: _roster,
        rivalTeamName: 'Rival',
        config: MatchConfig(),
      );
      final c = MatchController(match)
        ..startSet(setNumber: 1, startingOrderOwn: List.of(_order), startingServer: TeamSide.own, trackHitZones: false);
      c.logServe('A1', Grade.nn, missType: MissType.out);
      expect(c.match.sets.first.events.single.missType, isNull);
    });

    test('trazos: afuera sigue la dirección hasta salir de la cancha; a la red termina en la red', () {
      expect(StatsEngine.shotResultOf(Grade.nn, MissType.out), ShotResult.out);
      expect(StatsEngine.shotResultOf(Grade.nn, MissType.net), ShotResult.net);
      expect(StatsEngine.shotResultOf(Grade.p, MissType.out), ShotResult.inPlay);

      final c = _newController();
      c.logServe('A1', Grade.p);
      c.logCounter('O1', Grade.nn, targetZone: 5, missType: MissType.out); // opuesto adelante, hacia zona 5
      c.logServe('A1', Grade.p);
      c.logCounter('P1', Grade.nn, missType: MissType.net); // sin zona: igual se dibuja
      final d = StatsEngine.computeShots(c.match);

      final out = _shotOf(d, 'O1', ShotKind.counter);
      expect(out.result, ShotResult.out);
      final outside = out.targetX < 0 || out.targetX > 1 || out.targetY < 0;
      expect(outside, isTrue, reason: 'destino (${out.targetX}, ${out.targetY})');
      // Misma dirección que la zona 5 (fondo derecha, vista desde el banco).
      final center = StatsEngine.zoneCenter(5, nineZones: false)!;
      final dot = (out.targetX - out.originX) * (center.$1 - out.originX) +
          (out.targetY - out.originY) * (center.$2 - out.originY);
      expect(dot, greaterThan(0));

      final net = _shotOf(d, 'P1', ShotKind.counter);
      expect(net.result, ShotResult.net);
      expect(net.targetY, 0.503);
    });

    testWidgets('en el diálogo, "Afuera" se elige antes de NN y no suma un toque obligatorio', (tester) async {
      String? gotGrade;
      String? gotMiss;
      Future<void> open(bool trackZone) async {
        await tester.pumpWidget(MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTouchDialog(
                    context: context,
                    title: 'Ataque',
                    players: [_roster.first],
                    fixedPlayerId: _roster.first.id,
                    grades: attackCounterGrades,
                    trackZone: trackZone,
                    onConfirm: (player, grade, zone, miss) {
                      gotGrade = grade;
                      gotMiss = miss;
                    },
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

      await open(true);
      expect(find.text('Afuera'), findsOneWidget);
      await tester.tap(find.text('Afuera'));
      await tester.pumpAndSettle();
      expect(find.text('NN\nError · afuera'), findsOneWidget);
      await tester.tap(find.text('NN\nError · afuera'));
      await tester.pumpAndSettle();
      expect((gotGrade, gotMiss), (Grade.nn, MissType.out));

      // Con otra calificación, el detalle elegido se ignora.
      await open(true);
      await tester.tap(find.text('A la red'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('PP\n'));
      await tester.pumpAndSettle();
      expect((gotGrade, gotMiss), (Grade.pp, null));

      // Sin registro de zona, no aparece.
      await open(false);
      expect(find.text('Afuera'), findsNothing);
    });
  });

  group('Partidos archivados antes de la estadística visual', () {
    test('un partido guardado y vuelto a leer da los mismos gráficos y mapas', () {
      final c = _simulatedMatch(sets: 2);
      final reloaded = VolleyMatch.fromJson(jsonDecode(jsonEncode(c.match.toJson())) as Map);
      final a = StatsEngine.computeRotations(c.match).total;
      final b = StatsEngine.computeRotations(reloaded).total;
      expect((b.won, b.lost, b.sideOutWon, b.breakWon), (a.won, a.lost, a.sideOutWon, a.breakWon));
      final sa = StatsEngine.computeShots(c.match), sb = StatsEngine.computeShots(reloaded);
      expect(sb.shots.length, sa.shots.length);
      for (var i = 0; i < sa.shots.length; i++) {
        expect((sb.shots[i].originX, sb.shots[i].targetX, sb.shots[i].targetY),
            (sa.shots[i].originX, sa.shots[i].targetX, sa.shots[i].targetY));
      }
    });

    test('sin zonas registradas: gráficos completos, mapas vacíos con los toques contados', () {
      final c = _simulatedMatch(sets: 1);
      final json = jsonDecode(jsonEncode(c.match.toJson())) as Map<String, dynamic>;
      for (final set in json['sets'] as List) {
        for (final ev in (set as Map)['events'] as List) {
          (ev as Map).remove('targetZone');
        }
      }
      final legacy = VolleyMatch.fromJson(json);
      expect(StatsEngine.computeRotations(legacy).total.rallies, StatsEngine.computeRotations(c.match).total.rallies);
      final shots = StatsEngine.computeShots(legacy);
      // Solo se dibujan los que terminan en la red (bloqueados y "a la red"):
      // no necesitan zona. El resto se cuenta como "sin zona".
      expect(shots.shots.every((s) => s.result == ShotResult.blocked || s.result == ShotResult.net), isTrue);
      final team = StatsEngine.compute(legacy).team;
      expect(shots.missingZone(ShotKind.serve) + shots.where(ShotKind.serve).length, team.saque.total);
      expect(shots.missingZone(ShotKind.attack) + shots.where(ShotKind.attack).length, team.ataque.total);
    });
  });

  group('PDF', () {
    test('se arma con todos los gráficos en un partido de 5 sets y 9 zonas', () async {
      final c = _simulatedMatch(sets: 5, nineHitZones: true);
      final bytes = await PdfReportService.buildPdf(c.match, charts: VisualChart.values.toSet());
      expect(bytes.length, greaterThan(1000));
    });

    test('sin gráficos elegidos no agrega la sección visual', () async {
      final c = _simulatedMatch(sets: 2);
      final without = await PdfReportService.buildPdf(c.match);
      final withCharts = await PdfReportService.buildPdf(c.match, charts: VisualChart.values.toSet());
      expect(withCharts.length, greaterThan(without.length));
    });

    test('un partido sin puntos se arma igual (sin sección visual)', () async {
      final c = _newController();
      final bytes = await PdfReportService.buildPdf(c.match, charts: VisualChart.values.toSet());
      expect(bytes.length, greaterThan(500));
    });

    test('la selección se guarda por destino; sin premium se muestra todo', () async {
      final s = StorageService.instance;
      await s.savePdfVisualCharts({VisualChart.dashboard, VisualChart.heatmap});
      await s.savePdfCourtMaps({ShotKind.attack});
      await s.saveScreenVisualCharts({VisualChart.timeline});
      await s.saveScreenCourtMaps({});

      expect(VisualStatsPreferences.pdfCharts(isPremium: true), {VisualChart.dashboard, VisualChart.heatmap});
      expect(VisualStatsPreferences.pdfMaps(isPremium: true), {ShotKind.attack});
      expect(VisualStatsPreferences.screenCharts(isPremium: true), {VisualChart.timeline});
      expect(VisualStatsPreferences.screenMaps(isPremium: true), isEmpty);

      expect(VisualStatsPreferences.pdfCharts(isPremium: false), VisualChart.values.toSet());
      expect(VisualStatsPreferences.pdfMaps(isPremium: false), ShotKind.values.toSet());
      expect(VisualStatsPreferences.screenCharts(isPremium: false), VisualChart.values.toSet());
      expect(VisualStatsPreferences.screenMaps(isPremium: false), ShotKind.values.toSet());

      await _resetVisualPrefs();
    });

    test('la planilla de mapas por jugador agrega páginas al PDF', () async {
      final c = _simulatedMatch(sets: 3);
      final without = await PdfReportService.buildPdf(c.match);
      final withMaps = await PdfReportService.buildPdf(c.match, maps: ShotKind.values.toSet());
      final onlyAttack = await PdfReportService.buildPdf(c.match, maps: {ShotKind.attack});
      expect(withMaps.length, greaterThan(onlyAttack.length));
      expect(onlyAttack.length, greaterThan(without.length));
    });
  });

  group('UI', () {
    Widget app(Widget home, {bool premium = true}) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: AppDataController()),
            ChangeNotifierProvider.value(value: ThemeController()),
            ChangeNotifierProvider.value(value: SubscriptionController()..isPremium = premium),
          ],
          child: MaterialApp(theme: buildLightTheme(), home: home),
        );

    testWidgets('la pestaña Gráficos muestra el tablero y los gráficos de un partido', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);

      final c = _simulatedMatch(sets: 2);
      await tester.pumpWidget(app(MatchSummaryScreen(match: c.match)));
      await tester.pumpAndSettle();
      expect(find.text('Tabla'), findsOneWidget);

      await tester.tap(find.text('Gráficos'));
      await tester.pumpAndSettle();
      expect(find.text('Tablero rápido'), findsOneWidget);
      expect(find.text('Side-out'), findsWidgets);
      expect(find.text('Rendimiento por rotación'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
          find.text('Mapa de calor por zona'), find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('también se ve en modo oscuro y en un celular angosto', (tester) async {
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final c = _simulatedMatch(sets: 1);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppDataController()),
          ChangeNotifierProvider.value(value: ThemeController()),
          ChangeNotifierProvider.value(value: SubscriptionController()..isPremium = true),
        ],
        child: MaterialApp(theme: buildDarkTheme(), home: MatchSummaryScreen(match: c.match)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gráficos'));
      await tester.pumpAndSettle();
      expect(find.text('Tablero rápido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin puntos cargados, la pestaña avisa en vez de mostrar gráficos vacíos', (tester) async {
      final c = _newController();
      await tester.pumpWidget(app(MatchSummaryScreen(match: c.match)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gráficos'));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay puntos cargados'), findsOneWidget);
    });

    testWidgets('la configuración del PDF guarda cada cambio de mapas y gráficos', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      // La E/S real de Hive tiene que ir dentro de runAsync: en el tiempo
      // simulado de testWidgets nunca termina.
      await tester.runAsync(_resetVisualPrefs);
      await tester.pumpWidget(app(const VisualStatsSettingsScreen(target: VisualStatsTarget.pdf)));
      await tester.pumpAndSettle();
      expect(find.text('11 de 11 seleccionados'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Ninguno'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('0 de 11 seleccionados'), findsOneWidget);
      expect(StorageService.instance.loadPdfVisualCharts(), isEmpty);
      expect(StorageService.instance.loadPdfCourtMaps(), isEmpty);

      await tester.runAsync(() async {
        await tester.tap(find.text(VisualChart.timeline.label));
        await tester.tap(find.text(ShotKind.attack.label));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(StorageService.instance.loadPdfVisualCharts(), {VisualChart.timeline});
      expect(StorageService.instance.loadPdfCourtMaps(), {ShotKind.attack});
      // La de pantalla no se toca.
      expect(StorageService.instance.loadScreenVisualCharts(), VisualChart.values.toSet());

      await tester.runAsync(_resetVisualPrefs);
    });

    testWidgets('la pestaña Mapas muestra la cancha, los jugadores y la tabla por zona', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);

      final c = _simulatedMatch(sets: 2);
      await tester.pumpWidget(app(MatchSummaryScreen(match: c.match)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mapas'));
      await tester.pumpAndSettle();
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Punto'), findsOneWidget);
      expect(find.text('Ver como tabla por zona'), findsOneWidget);

      await tester.tap(find.text('Saque'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('#9 '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver como tabla por zona'));
      await tester.pumpAndSettle();
      expect(find.text('Zona'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lo que se ocultó en Configuración no aparece en las pestañas', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await StorageService.instance.saveScreenVisualCharts({VisualChart.dashboard});
        await StorageService.instance.saveScreenCourtMaps({});
      });

      final c = _simulatedMatch(sets: 1);
      await tester.pumpWidget(app(MatchSummaryScreen(match: c.match)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gráficos'));
      await tester.pumpAndSettle();
      expect(find.text('Tablero rápido'), findsOneWidget);
      expect(find.text('Rendimiento por rotación'), findsNothing);

      await tester.tap(find.text('Mapas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ocultaste todos los mapas'), findsOneWidget);

      // Sin premium la selección no se aplica: se ve todo.
      await tester.pumpWidget(app(MatchSummaryScreen(match: c.match), premium: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ocultaste'), findsNothing);

      await tester.runAsync(_resetVisualPrefs);
    });
  });
}
