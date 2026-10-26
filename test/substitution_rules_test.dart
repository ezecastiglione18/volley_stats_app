// Pruebas de las reglas de la FIVB para casos excepcionales: el cambio
// excepcional de un jugador (Regla 15.7, también como reemplazo por una
// expulsión o descalificación, 15.8) y el líbero sin poder jugar con su
// redesignación (Regla 19.4).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/sanction_event.dart';
import 'package:rally_stats/models/substitution_event.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/live/widgets/libero_unable_dialog.dart';
import 'package:rally_stats/screens/live/widgets/substitution_dialog.dart';
import 'package:rally_stats/services/match_incidents.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/match_controller.dart';

Player _p(String id, int number, PlayerPosition pos) =>
    Player(id: id, firstName: id, lastName: id, number: number, position: pos);

List<Player> _roster({int liberos = 1}) => [
      _p('A1', 1, PlayerPosition.armador),
      _p('P1', 2, PlayerPosition.puntaReceptor),
      _p('C1', 3, PlayerPosition.central),
      _p('O1', 4, PlayerPosition.opuesto),
      _p('P2', 5, PlayerPosition.puntaReceptor),
      _p('C2', 6, PlayerPosition.central),
      _p('B1', 10, PlayerPosition.puntaReceptor),
      _p('B2', 11, PlayerPosition.central),
      _p('B3', 12, PlayerPosition.universal),
      if (liberos >= 1) _p('L1', 7, PlayerPosition.libero),
      if (liberos >= 2) _p('L2', 8, PlayerPosition.libero),
    ];

// Slot 0 = posición 1 al arrancar (saca A1), ..., slot 5 = posición 6 (C2).
const _order = ['A1', 'P1', 'C1', 'O1', 'P2', 'C2'];

MatchController _newController({int maxSubs = 6, int liberos = 1}) {
  final match = VolleyMatch(
    id: 'match_subs_${DateTime.now().microsecondsSinceEpoch}',
    date: DateTime(2026, 10, 26),
    ownTeamName: 'Propio',
    ownRoster: _roster(liberos: liberos),
    rivalTeamName: 'Rival',
    config: MatchConfig(maxSubstitutionsPerSet: maxSubs),
  );
  final controller = MatchController(match);
  controller.startSet(
    setNumber: 1,
    startingOrderOwn: List.of(_order),
    startingServer: TeamSide.own,
  );
  return controller;
}

List<String> _ids(List<Player> players) => players.map((p) => p.id).toList();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_subs_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();
    await StorageService.instance.openUserBoxes('test-uid');
  });

  group('Cambio excepcional (Regla 15.7)', () {
    test('no se habilita mientras haya un cambio legal posible', () {
      final c = _newController();
      expect(c.hasLegalSubstitutionFor('C1'), isTrue);
      expect(c.canSubOutExceptional('C1'), isFalse);
      c.substituteExceptional(playerOutId: 'C1', playerInId: 'B2');
      expect(c.currentSet.substitutions, isEmpty);
    });

    test('sin cupo: entra cualquiera del banco, no cuenta y el que sale queda afuera del partido', () {
      final c = _newController(maxSubs: 1);
      c.substitutePlayer(playerOutId: 'P1', playerInId: 'B1');
      expect(c.substitutionsRemaining, 0);

      expect(c.hasLegalSubstitutionFor('C1'), isFalse);
      expect(c.canSubOutExceptional('C1'), isTrue);
      // Cualquiera que no esté en cancha, incluso el titular que ya salió
      // (P1), pero nunca un líbero.
      expect(_ids(c.eligibleExceptionalBenchFor('C1')), containsAll(['P1', 'B2', 'B3']));
      expect(_ids(c.eligibleExceptionalBenchFor('C1')), isNot(contains('L1')));

      c.substituteExceptional(playerOutId: 'C1', playerInId: 'B2');
      expect(c.playerAtPosition(3), 'B2');
      expect(c.substitutionsUsedOwn, 1);
      expect(c.exceptionalSubstitutionsUsedOwn, 1);
      expect(c.currentSet.substitutions.last.exceptional, isTrue);
      expect(c.currentSet.substitutions.last.countedAgainstLimit, isFalse);
      expect(c.isBarredFromPlay('C1'), isTrue);
      expect(_ids(c.benchPlayers), isNot(contains('C1')));
      // El puesto queda cerrado a cambios regulares.
      expect(c.canSubOutRegular('B2'), isFalse);

      // Deshacer lo revierte todo.
      expect(c.canUndoLastSubstitution, isTrue);
      c.undoLastSubstitution();
      expect(c.playerAtPosition(3), 'C1');
      expect(c.isBarredFromPlay('C1'), isFalse);
    });

    test('el que salió por cambio excepcional tampoco juega los sets siguientes', () {
      final c = _newController(maxSubs: 0);
      c.substituteExceptional(playerOutId: 'C1', playerInId: 'B2');
      c.startSet(
        setNumber: 2,
        startingOrderOwn: ['A1', 'P1', 'B2', 'O1', 'P2', 'C2'],
        startingServer: TeamSide.rival,
      );
      expect(c.match.isBarredForMatch('C1'), isTrue);
      expect(_ids(c.benchPlayers), isNot(contains('C1')));
      expect(_ids(c.eligibleRegularBenchFor('C2')), isNot(contains('C1')));
    });

    test('no puede entrar el jugador al que está reemplazando el líbero', () {
      final c = _newController(maxSubs: 0);
      c.bringLiberoIn('L1', 'C2'); // C2 está en posición 6, al fondo
      expect(c.playerAtPosition(6), 'L1');
      final bench = _ids(c.eligibleExceptionalBenchFor('C1'));
      expect(bench, isNot(contains('C2')));
      expect(bench, isNot(contains('L1')));
      expect(c.canSubOutExceptional('L1'), isFalse); // el líbero nunca
    });

    test('expulsado sin cambio legal: reemplazo excepcional y afuera de todo el partido', () {
      final c = _newController(maxSubs: 0);
      final sanction = c.registerSanction(
        team: TeamSide.own,
        targetKind: SanctionTargetKind.player,
        targetPlayerId: 'O1',
        category: SanctionCategory.ofensiva,
      );
      expect(sanction.outcome, SanctionOutcome.expulsion);
      expect(_ids(c.eligibleReplacementsForSanction('O1')), containsAll(['B1', 'B2', 'B3']));
      c.substituteForSanction(sanction.id, 'O1', 'B3');
      expect(c.currentSet.substitutions.last.exceptional, isTrue);
      expect(c.match.isBarredForMatch('O1'), isTrue);

      // Una expulsión con cambio legal, en cambio, vale solo para el set.
      final legal = _newController();
      final s2 = legal.registerSanction(
        team: TeamSide.own,
        targetKind: SanctionTargetKind.player,
        targetPlayerId: 'O1',
        category: SanctionCategory.ofensiva,
      );
      legal.substituteForSanction(s2.id, 'O1', 'B3');
      expect(legal.currentSet.substitutions.last.exceptional, isFalse);
      expect(legal.match.isBarredForMatch('O1'), isFalse);
    });

    test('JSON: guarda el cambio excepcional y lee partidos viejos sin el campo', () {
      final sub = SubstitutionEvent(
        id: 's1',
        setNumber: 1,
        rallyNumber: 3,
        slotIndex: 2,
        position: 3,
        playerOutId: 'C1',
        playerInId: 'B2',
        countedAgainstLimit: false,
        isLiberoAction: false,
        exceptional: true,
        timestamp: DateTime(2026, 10, 26),
      );
      expect(SubstitutionEvent.fromJson(sub.toJson()).exceptional, isTrue);
      final old = sub.toJson()..remove('exceptional');
      expect(SubstitutionEvent.fromJson(old).exceptional, isFalse);
    });
  });

  testWidgets('UI: el panel ofrece el cambio excepcional recién cuando no hay cambio legal', (tester) async {
    final c = _newController(maxSubs: 1);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showSubstitutionDialog(context: context, controller: c),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    const link = '¿No puede seguir por lesión o enfermedad? Cambio excepcional';

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text(link), findsNothing);
    Navigator.of(tester.element(find.text('Cambio de jugador'))).pop();
    await tester.pumpAndSettle();

    c.substitutePlayer(playerOutId: 'P1', playerInId: 'B1'); // se acaba el cupo
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(link));
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    expect(find.text('Cambio excepcional'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#3 C1 · CEN').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#11 B2 · CEN (sugerido)').last);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar cambio excepcional'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(c.playerAtPosition(3), 'B2');
    expect(c.exceptionalSubstitutionsUsedOwn, 1);
  });

  testWidgets('UI: diálogo del líbero lesionado en cancha con redesignación directa', (tester) async {
    final c = _newController();
    c.bringLiberoIn('L1', 'C2');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showLiberoUnableDialog(context: context, controller: c),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    // Con un solo líbero viene marcado y ya se ofrece redesignar.
    expect(find.text('Nuevo líbero'), findsOneWidget);
    expect(find.text('#6 C2 (vuelve)'), findsOneWidget);
    await tester.tap(find.text('#10 B1 · P/R'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('#10 B1 (nuevo líbero)'));
    await tester.tap(find.text('#10 B1 (nuevo líbero)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(c.isLibero('B1'), isTrue);
    expect(c.playerAtPosition(6), 'B1');
  });

  group('Líbero sin poder jugar y redesignación (Regla 19.4)', () {
    test('con un solo líbero: se declara y se redesigna a un jugador del banco', () {
      final c = _newController();
      expect(c.redesignationAllowedAfter(const []), isFalse);
      expect(c.redesignationAllowedAfter(['L1']), isTrue);
      // Los que están en cancha no se pueden redesignar.
      expect(_ids(c.redesignationCandidates), unorderedEquals(['B1', 'B2', 'B3']));

      c.declareLiberoUnable(liberoIds: ['L1'], newLiberoId: 'B1');
      expect(c.isLibero('B1'), isTrue);
      expect(c.isBarredFromPlay('L1'), isTrue);
      expect(c.rosterLiberoIds, ['B1']);
      // El nuevo líbero ya no entra por cambios regulares ni excepcionales.
      expect(_ids(c.eligibleRegularBenchFor('C1')), isNot(contains('B1')));
      // Y entra como líbero por un jugador del fondo.
      expect(c.canBringLiberoIn('B1', 'C2'), isTrue);
      c.bringLiberoIn('B1', 'C2');
      expect(_ids(c.onCourtAttackersAndBlockers), isNot(contains('B1')));
    });

    test('con dos líberos solo se puede redesignar cuando ninguno puede seguir', () {
      final c = _newController(liberos: 2);
      expect(c.redesignationAllowedAfter(['L1']), isFalse);
      c.declareLiberoUnable(liberoIds: ['L1'], newLiberoId: 'B1'); // no corresponde
      expect(c.currentSet.liberoUnableEvents, isEmpty);

      c.declareLiberoUnable(liberoIds: ['L1']);
      expect(c.rosterLiberoIds, ['L2']);
      expect(c.redesignationAllowedAfter(const []), isFalse);
      expect(c.redesignationAllowedAfter(['L2']), isTrue);
      c.declareLiberoUnable(liberoIds: ['L2'], newLiberoId: 'B3');
      expect(c.rosterLiberoIds, ['B3']);
      expect(c.match.unableLiberoIds, unorderedEquals(['L1', 'L2']));
    });

    test('líbero en cancha: el nuevo entra directo y se deshace todo junto', () {
      final c = _newController();
      c.bringLiberoIn('L1', 'C2');
      // El reemplazado por el líbero no se puede redesignar.
      expect(_ids(c.redesignationCandidates), isNot(contains('C2')));
      expect(c.liberoCourtReplacementOptions(5, unableIds: ['L1'], newLiberoId: 'B1'),
          unorderedEquals(['C2', 'B1']));

      c.declareLiberoUnable(liberoIds: ['L1'], newLiberoId: 'B1', courtReplacementId: 'B1');
      expect(c.playerAtPosition(6), 'B1');
      expect(c.liberoOnCourtSlot, 5);
      // Sigue reemplazando a C2: después de un punto puede salir por él.
      expect(c.canSendLiberoOut(5), isFalse);
      c.logOpponentError();
      expect(c.canSendLiberoOut(5), isTrue);
      c.undoLastAction(); // el punto

      expect(c.canUndoLastSubstitution, isFalse); // va con la redesignación
      c.undoLastAction();
      expect(c.playerAtPosition(6), 'L1');
      expect(c.isLibero('B1'), isFalse);
      expect(c.isBarredFromPlay('L1'), isFalse);
    });

    test('líbero en cancha sin redesignar: por defecto vuelve el jugador reemplazado', () {
      final c = _newController(liberos: 2);
      c.bringLiberoIn('L1', 'C2');
      c.declareLiberoUnable(liberoIds: ['L1']);
      expect(c.playerAtPosition(6), 'C2');
    });

    test('líbero expulsado en cancha: lo reemplaza el otro líbero y se deshace con la sanción', () {
      final c = _newController(liberos: 2);
      c.bringLiberoIn('L1', 'C2');
      final sanction = c.registerSanction(
        team: TeamSide.own,
        targetKind: SanctionTargetKind.player,
        targetPlayerId: 'L1',
        category: SanctionCategory.ofensiva,
      );
      expect(c.liberoReplacementsForSanction('L1'), unorderedEquals(['C2', 'L2']));
      c.substituteLiberoForSanction(sanction.id, 'L1', 'L2');
      expect(c.playerAtPosition(6), 'L2');
      c.undoLastAction();
      expect(c.playerAtPosition(6), 'L1');
      expect(c.currentSet.sanctions, isEmpty);
    });

    test('líbero único expulsado: se puede redesignar y queda afuera del partido', () {
      final c = _newController();
      c.bringLiberoIn('L1', 'C2');
      c.registerSanction(
        team: TeamSide.own,
        targetKind: SanctionTargetKind.player,
        targetPlayerId: 'L1',
        category: SanctionCategory.ofensiva,
      );
      expect(c.redesignationAllowedAfter(const []), isTrue);
      c.declareLiberoUnable(liberoIds: const [], newLiberoId: 'B2', courtReplacementId: 'B2');
      expect(c.playerAtPosition(6), 'B2');
      expect(c.match.isBarredForMatch('L1'), isTrue);
    });

    test('incidencias reglamentarias para el resumen y el PDF, en orden', () {
      final c = _newController(maxSubs: 0);
      expect(matchIncidents(c.match), isEmpty);
      c.logOpponentError(); // 1-0
      c.substituteExceptional(playerOutId: 'C1', playerInId: 'B2');
      c.declareLiberoUnable(liberoIds: ['L1'], newLiberoId: 'B1');
      expect(matchIncidents(c.match), [
        'Set 1 (1-0): cambio excepcional, sale #3 C1 (no vuelve a jugar) y entra #11 B2.',
        'Set 1 (1-0): #7 L1 sin poder jugar; #10 B1 (P/R) redesignado como líbero.',
      ]);
    });

    test('se conserva al guardar y retomar el partido, y vale en el set siguiente', () {
      final c = _newController();
      c.declareLiberoUnable(liberoIds: ['L1'], newLiberoId: 'B1');
      final restored = MatchController.resume(VolleyMatch.fromJson(c.match.toJson()));
      expect(restored.isLibero('B1'), isTrue);
      expect(restored.isBarredFromPlay('L1'), isTrue);

      restored.startSet(
        setNumber: 2,
        startingOrderOwn: List.of(_order),
        startingServer: TeamSide.rival,
        receptionLiberoId: 'L1', // rol heredado de un líbero que ya no juega
      );
      // Los automatismos siguen con el líbero disponible.
      expect(restored.liberoForCurrentServe(), 'B1');
      expect(restored.rosterLiberoIds, ['B1']);
    });
  });
}
