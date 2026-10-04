// Comparador de dos partidos (documents/RallyStats-Funcionalidades-
// Pendientes.pdf, sección 4): deltas B − A, sentido de la mejora (en los
// errores propios, bajar es mejorar) y porcentajes en puntos porcentuales.
// Al final, pruebas de pantalla del comparador y de la tarjeta de notas.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/stat_line.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/matches/match_compare_screen.dart';
import 'package:rally_stats/screens/matches/match_summary_screen.dart';
import 'package:rally_stats/screens/matches/widgets/stats_table.dart';
import 'package:rally_stats/services/match_compare.dart';
import 'package:rally_stats/services/stats_engine.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
import 'package:rally_stats/utils/theme.dart';

MatchStats _stats({
  int servePts = 0,
  int attackPts = 0,
  int counterPts = 0,
  int blockPts = 0,
  int serveErr = 0,
  int attackErr = 0,
  int attackTotalExtra = 0,
  int genErr = 0,
  int recPerfect = 0,
  int recOther = 0,
  int rivalErr = 0,
}) {
  final team = PlayerStatLine(playerId: 'team', displayName: 'Total Equipo', number: -1);
  team.saque
    ..pp = servePts
    ..nn = serveErr;
  team.ataque
    ..pp = attackPts
    ..nn = attackErr
    ..p = attackTotalExtra;
  team.contra.pp = counterPts;
  team.bloqueoPts = blockPts;
  team.errGen = genErr;
  team.recepcion
    ..pp = recPerfect
    ..n = recOther;
  return MatchStats(
    byPlayer: {},
    team: team,
    rivalErrors: RivalErrorStats()..generic = rivalErr,
    rivalPoints: RivalPointStats(),
    rivalSanctions: RivalSanctionStats(),
  );
}

CompareRow _row(List<CompareRow> rows, String metric) => rows.firstWhere((r) => r.metric == metric);

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

/// Partido terminado 1-0 (un set simulado), con fecha y planteles propios.
VolleyMatch _finished(String id, DateTime date, List<Player> roster) {
  final match = VolleyMatch(
    id: id,
    date: date,
    ownTeamName: 'Propio',
    ownRoster: roster,
    rivalTeamName: 'Los Andes',
    config: MatchConfig(),
  );
  final c = MatchController(match)
    ..startSet(
      setNumber: 1,
      startingOrderOwn: [for (final p in roster.take(6)) p.id],
      startingServer: TeamSide.own,
      trackHitZones: false,
    );
  c.simulateRestOfSet();
  match.status = MatchStatus.finished;
  return match;
}

void main() {
  group('MatchCompare (lógica)', () {
    final a = _stats(servePts: 4, attackPts: 10, counterPts: 3, blockPts: 5, serveErr: 11, attackErr: 6,
        attackTotalExtra: 16, genErr: 3, recPerfect: 28, recOther: 22, rivalErr: 14);
    final b = _stats(servePts: 8, attackPts: 12, counterPts: 3, blockPts: 6, serveErr: 7, attackErr: 8,
        attackTotalExtra: 12, genErr: 5, recPerfect: 24, recOther: 25, rivalErr: 21);
    final rows = MatchCompare.compareTeam(a: a, b: b, setsA: (1, 3), setsB: (3, 1));

    test('todas las métricas pedidas, en orden', () {
      expect([for (final r in rows) r.metric], [
        'Sets (ganados-perdidos)',
        'Puntos totales',
        'Puntos de saque',
        'Puntos de ataque',
        'Puntos de contra',
        'Puntos de bloqueo',
        'Errores de saque',
        'Errores de ataque',
        'Errores generales',
        'Eficacia de ataque',
        'Eficacia de recepción',
        'Errores del rival',
      ]);
    });

    test('delta = B − A en los conteos; subir puntos es mejorar', () {
      final serve = _row(rows, 'Puntos de saque');
      expect((serve.a, serve.b, serve.delta, serve.improved), ('4', '8', 4, true));
      expect(serve.deltaLabel, '+4');
      // totalPts sale de PlayerStatLine: 4+10+3+5 = 22 contra 8+12+3+6 = 29.
      expect(_row(rows, 'Puntos totales').delta, 7);
      final counter = _row(rows, 'Puntos de contra');
      expect((counter.delta, counter.improved, counter.deltaLabel), (0, null, '0'));
    });

    test('en los errores propios, bajar es mejorar y subir es empeorar', () {
      final serveErr = _row(rows, 'Errores de saque');
      expect((serveErr.delta, serveErr.improved, serveErr.deltaLabel), (-4, true, '-4'));
      final attackErr = _row(rows, 'Errores de ataque');
      expect((attackErr.delta, attackErr.improved), (2, false));
      expect(_row(rows, 'Errores generales').improved, isFalse);
      // Los errores del rival suben a favor nuestro.
      final rival = _row(rows, 'Errores del rival');
      expect((rival.delta, rival.improved), (7, true));
    });

    test('porcentajes en puntos porcentuales, redondeados como se muestran', () {
      // Ataque A: 10 PP / 32 = 31 %; B: 12 / 32 = 38 % → +7.
      final atk = _row(rows, 'Eficacia de ataque');
      expect((atk.a, atk.b, atk.delta, atk.improved, atk.isPct), ('31%', '38%', 7, true, true));
      // Recepción A: 28/50 = 56 %; B: 24/49 = 49 % → −7, empeora.
      final rec = _row(rows, 'Eficacia de recepción');
      expect((rec.a, rec.b, rec.delta, rec.improved), ('56%', '49%', -7, false));
    });

    test('porcentaje sin datos en un partido: sin delta ni color', () {
      final r = MatchCompare.compareTeam(a: _stats(), b: b, setsA: (0, 0), setsB: (3, 1));
      final rec = _row(r, 'Eficacia de recepción');
      expect((rec.a, rec.delta, rec.improved, rec.deltaLabel), ('-', null, null, '-'));
    });

    test('sets: delta de la diferencia ganados − perdidos', () {
      final sets = _row(rows, 'Sets (ganados-perdidos)');
      expect((sets.a, sets.b, sets.delta, sets.improved, sets.deltaLabel), ('1-3', '3-1', 4, true, '▲'));
      final same = MatchCompare.compareTeam(a: a, b: b, setsA: (3, 2), setsB: (3, 2));
      expect(_row(same, 'Sets (ganados-perdidos)').deltaLabel, '=');
    });

    test('jugadores compartidos: solo los mismos Player.id de los dos planteles', () {
      VolleyMatch m(String id, List<Player> roster) => VolleyMatch(
          id: id, date: DateTime(2026, 9, 1), ownTeamName: 'P', ownRoster: roster, rivalTeamName: 'R', config: MatchConfig());
      final shared = MatchCompare.sharedPlayers(m('a', _roster), m('b', [_roster[3], _p('X', 99, PlayerPosition.libero), _roster[0]]));
      expect([for (final p in shared) p.id], ['A1', 'O1']);
      expect(MatchCompare.sharedPlayers(m('a', _roster), m('b', [_p('X', 9, PlayerPosition.libero)])), isEmpty);
    });
  });

  group('UI', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = Directory.systemTemp.createTempSync('rally_stats_compare_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async =>
            methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
      );
      await StorageService.instance.init();
    });

    Widget app(Widget home, AppDataController appData) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appData),
            ChangeNotifierProvider.value(value: ThemeController()),
            ChangeNotifierProvider.value(value: SubscriptionController()..isPremium = true),
          ],
          child: MaterialApp(theme: buildLightTheme(), home: home),
        );

    testWidgets('comparador: vista Equipo y vista Jugador con una fila por partido', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);

      final a = _finished('cmp_a', DateTime(2026, 8, 12), _roster);
      final b = _finished('cmp_b', DateTime(2026, 9, 20), _roster);
      final appData = AppDataController()..matches = [b, a];

      await tester.pumpWidget(app(MatchCompareScreen(initialA: a), appData));
      await tester.pumpAndSettle();
      expect(find.text('Métrica'), findsOneWidget);
      expect(find.text('Eficacia de recepción'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Jugador'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsTable), findsOneWidget);
      expect(find.text('A · 12/08'), findsOneWidget);
      expect(find.text('B · 20/09'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('comparador: sin jugadores en común muestra el aviso', (tester) async {
      final a = _finished('cmp_c', DateTime(2026, 8, 12), _roster);
      final other = [for (final p in _roster) _p('${p.id}_x', p.number, p.position)];
      final b = _finished('cmp_d', DateTime(2026, 9, 20), other);
      final appData = AppDataController()..matches = [b, a];

      await tester.pumpWidget(app(MatchCompareScreen(initialA: a), appData));
      await tester.tap(find.text('Jugador'));
      await tester.pumpAndSettle();
      expect(find.text('Estos partidos no comparten jugadores (planteles cargados a mano)'), findsOneWidget);
      expect(find.byType(StatsTable), findsNothing);
    });

    testWidgets('notas: vacía muestra el aviso; guardar solo espacios deja null y texto lo guarda',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);

      final m = _finished('notes_ui', DateTime(2026, 9, 20), _roster);
      final appData = AppDataController()..matches = [m];
      await tester.pumpWidget(app(MatchSummaryScreen(match: m), appData));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.text('Notas de scouting'), find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Sin notas · tocá ✎ para agregar'), findsOneWidget);
      // La tabla del resumen (ya extraída a StatsTable) sigue con su total.
      expect(find.byType(StatsTable), findsOneWidget);
      expect(find.text('TOTAL EQUIPO'), findsOneWidget);

      Future<void> save(String text) async {
        await tester.tap(find.byTooltip('Editar notas'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), text);
        await tester.tap(find.text('Guardar'));
        // saveMatch escribe en Hive: E/S real, fuera del reloj falso.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pumpAndSettle();
      }

      await save('   \n  ');
      expect(m.notes, isNull);

      await save('  Saque flotado corto a zona 1.  ');
      expect(m.notes, 'Saque flotado corto a zona 1.');
      expect(find.text('Saque flotado corto a zona 1.'), findsOneWidget);
      expect(StorageService.instance.loadMatches().firstWhere((x) => x.id == m.id).notes,
          'Saque flotado corto a zona 1.');

      // Cancelar no toca nada.
      await tester.tap(find.byTooltip('Editar notas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'otra cosa');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(m.notes, 'Saque flotado corto a zona 1.');
    });
  });
}
