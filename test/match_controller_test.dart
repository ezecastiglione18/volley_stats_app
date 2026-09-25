// Pruebas de la lógica de juego de MatchController (sin UI): rotación
// manual y su "deshacer", cambio entre líberos de la planilla, y registro
// de zonas en 9.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/rally_event.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/screens/live/live_match_screen.dart';
import 'package:rally_stats/screens/live/widgets/court_view.dart';
import 'package:rally_stats/screens/live/widgets/hit_zone_picker.dart';
import 'package:rally_stats/services/stats_engine.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/match_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
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
  _p('L1', 7, PlayerPosition.libero),
  _p('L2', 8, PlayerPosition.libero),
];

// Slot 0 = posición 1 al arrancar, slot 1 = posición 2, etc.
const _order = ['A1', 'P1', 'C1', 'O1', 'P2', 'C2'];

MatchController _newController({
  bool allowManualRotation = true,
  TeamSide startingServer = TeamSide.own,
  String? defensiveLiberoId,
  String? receptionLiberoId,
  bool nineHitZones = false,
}) {
  final match = VolleyMatch(
    id: 'match_test_${DateTime.now().microsecondsSinceEpoch}',
    date: DateTime(2026, 9, 25),
    ownTeamName: 'Propio',
    ownRoster: _roster,
    rivalTeamName: 'Rival',
    config: MatchConfig(allowManualRotation: allowManualRotation),
  );
  final controller = MatchController(match);
  controller.startSet(
    setNumber: 1,
    startingOrderOwn: List.of(_order),
    startingServer: startingServer,
    trackHitZones: true,
    nineHitZones: nineHitZones,
    defensiveLiberoId: defensiveLiberoId,
    receptionLiberoId: receptionLiberoId,
  );
  return controller;
}

void main() {
  // Mismo truco que widget_test.dart: MatchController persiste en Hive en
  // cada acción, y Hive necesita path_provider, que no existe en test.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_ctrl_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async =>
          methodCall.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    await StorageService.instance.init();
  });

  group('Rotación manual', () {
    test('rota hacia adelante y hacia atrás, y se deshace con "Deshacer última acción"', () {
      final c = _newController();
      expect(c.playerAtPosition(1), 'A1');

      c.rotateManually();
      expect(c.playerAtPosition(1), 'P1'); // 2 -> 1
      expect(c.playerAtPosition(6), 'A1'); // 1 -> 6
      expect(c.canUndoLastAction, isTrue);

      c.undoLastAction();
      expect(c.playerAtPosition(1), 'A1');
      expect(c.currentSet.manualRotations, isEmpty);

      c.rotateManually(backward: true);
      expect(c.playerAtPosition(1), 'C2'); // 6 -> 1
      expect(c.playerAtPosition(2), 'A1'); // 1 -> 2
    });

    test('deshacer respeta el orden entre puntos y rotaciones manuales', () {
      final c = _newController();
      c.logOpponentError(); // sacábamos: punto nuestro, sin side-out
      c.rotateManually();
      c.logOpponentError();
      expect(c.currentSet.ownScore, 2);
      expect(c.playerAtPosition(1), 'P1');

      c.undoLastAction(); // el último punto
      expect(c.currentSet.ownScore, 1);
      expect(c.playerAtPosition(1), 'P1');

      c.undoLastAction(); // la rotación manual
      expect(c.currentSet.ownScore, 1);
      expect(c.playerAtPosition(1), 'A1');
    });

    test('no está disponible si el partido no la habilita, ni con un punto en juego', () {
      final disabled = _newController(allowManualRotation: false);
      expect(disabled.canRotateManually, isFalse);
      disabled.rotateManually();
      expect(disabled.playerAtPosition(1), 'A1');

      final c = _newController();
      c.logServe('A1', Grade.p); // el punto sigue en juego
      expect(c.canRotateManually, isFalse);
      c.rotateManually();
      expect(c.playerAtPosition(1), 'A1');
    });

    test('se conserva al guardar y retomar el partido', () {
      final c = _newController();
      c.logOpponentError();
      c.rotateManually(backward: true);
      final json = jsonDecode(jsonEncode(c.match.toJson())) as Map<String, dynamic>;
      final resumed = MatchController.resume(VolleyMatch.fromJson(json));
      expect(resumed.playerAtPosition(1), 'C2');
      expect(resumed.match.config.allowManualRotation, isTrue);
      expect(resumed.currentSet.manualRotations, hasLength(1));
    });

    test('saca al líbero que queda adelante y lo vuelve a poner al deshacer', () {
      // Saca el rival: el líbero receptor entra solo por el central que
      // arranca en el fondo (C2, posición 6).
      final c = _newController(
        startingServer: TeamSide.rival,
        defensiveLiberoId: 'L1',
        receptionLiberoId: 'L1',
      );
      expect(c.currentSet.currentOrderOwn[5], 'L1');

      c.rotateManually(); // slot de C2: 6 -> 5, sigue atrás
      expect(c.currentSet.currentOrderOwn[5], 'L1');

      c.rotateManually(); // slot de C2: 5 -> 4, adelante: sale el líbero
      expect(c.currentSet.currentOrderOwn[5], 'C2');
      // ...y entra por C1, que ahora quedó en el fondo (posición 1).
      expect(c.currentSet.currentOrderOwn[2], 'L1');

      c.undoLastAction();
      expect(c.currentSet.currentOrderOwn[5], 'L1');
      expect(c.currentSet.currentOrderOwn[2], 'C1');
      expect(c.playerAtPosition(5), 'L1');
    });

    test('el líbero vuelve a entrar solo cuando el central regresa al fondo', () {
      // Sacamos: el líbero defensor entra por C2, que arranca en posición 6.
      final c = _newController(defensiveLiberoId: 'L1', receptionLiberoId: 'L1');
      expect(c.currentSet.currentOrderOwn[5], 'L1');

      c.rotateManually(); // C2: 6 -> 5
      c.rotateManually(); // C2: 5 -> 4, sale el líbero
      expect(c.currentSet.currentOrderOwn[5], 'C2');

      c.rotateManually(backward: true); // C2: 4 -> 5, vuelve al fondo
      expect(c.currentSet.currentOrderOwn[5], 'L1');
      c.rotateManually(backward: true); // C2: 5 -> 6
      expect(c.playerAtPosition(6), 'L1');
    });
  });

  group('Líberos de la planilla', () {
    test('un líbero sin rol asignado se puede hacer entrar a mano', () {
      final c = _newController(startingServer: TeamSide.rival);
      expect(c.declaredLiberoIds, isEmpty);
      expect(c.rosterLiberoIds, containsAll(['L1', 'L2']));
      expect(c.canBringLiberoIn('L2', 'C2'), isTrue);
      c.bringLiberoIn('L2', 'C2');
      expect(c.currentSet.currentOrderOwn[5], 'L2');
    });

    test('con un solo líbero configurado se puede pasar al otro, y los automatismos lo respetan',
        () {
      final c = _newController(
        startingServer: TeamSide.rival,
        defensiveLiberoId: 'L1',
        receptionLiberoId: 'L1',
      );
      expect(c.currentSet.currentOrderOwn[5], 'L1');
      expect(c.otherLiberosFor(5), ['L2']);

      // Hace falta un punto jugado entre dos cambios de líbero.
      c.logOpponentError(); // side-out: sacamos nosotros
      c.swapLiberoToOther(5, toLiberoId: 'L2');
      expect(c.currentSet.currentOrderOwn[5], 'L2');
      expect(c.liberoForCurrentServe(), 'L2');

      // Perdemos el saque, lo recuperamos y rotamos: L2 queda adelante y sale.
      c.logServe(c.playerAtPosition(1), Grade.nn);
      c.logOpponentError();
      expect(c.currentSet.currentOrderOwn[5], 'C2');

      // Perdemos el saque con C1 sacando: al pasar a recibir, el automatismo
      // mete a L2 (el que eligió el entrenador), no al L1 configurado.
      expect(c.playerAtPosition(1), 'C1');
      c.logServe('C1', Grade.nn);
      expect(c.currentSet.currentOrderOwn[2], 'L2');
    });

    test('con dos líberos en roles distintos, manda el rol según quién saca', () {
      final c = _newController(
        startingServer: TeamSide.rival,
        defensiveLiberoId: 'L1',
        receptionLiberoId: 'L2',
      );
      expect(c.currentSet.currentOrderOwn[5], 'L2'); // recibimos: receptor
      c.logOpponentError(); // sacamos: se intercambia solo por el defensor
      expect(c.currentSet.currentOrderOwn[5], 'L1');
    });
  });

  group('Zonas', () {
    test('con 9 zonas se registran y se reportan las zonas 7 a 9', () {
      final c = _newController(nineHitZones: true);
      c.logServe('A1', Grade.p, targetZone: 8);
      final zones = StatsEngine.computeZones(c.match);
      expect(zones.serveByZone[8]!.total, 1);
      expect(zones.hasMiddleZoneData, isTrue);
      expect(zones.displayZones, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('sin datos en la franja media, el reporte sigue mostrando 6 zonas', () {
      final c = _newController();
      c.logServe('A1', Grade.p, targetZone: 3);
      final zones = StatsEngine.computeZones(c.match);
      expect(zones.displayZones, [1, 2, 3, 4, 5, 6]);
    });

    test('la opción de 9 zonas se guarda con el set', () {
      final c = _newController(nineHitZones: true);
      final json = jsonDecode(jsonEncode(c.match.toJson())) as Map<String, dynamic>;
      expect(VolleyMatch.fromJson(json).sets.single.nineHitZones, isTrue);
    });
  });

  group('Editar formación', () {
    test('se puede editar hasta que se carga la primera acción, y de nuevo al deshacerla', () {
      // Arranca con un cambio automático (líbero por C2 en el fondo): es
      // parte de la formación, no una acción, así que no bloquea la edición.
      final c = _newController(startingServer: TeamSide.rival, receptionLiberoId: 'L1');
      expect(c.currentSet.substitutions, hasLength(1));
      expect(c.canEditCurrentSetLineup, isTrue);

      c.logOpponentError();
      expect(c.canEditCurrentSetLineup, isFalse);
      c.undoLastAction();
      expect(c.canEditCurrentSetLineup, isTrue);

      c.rotateManually();
      expect(c.canEditCurrentSetLineup, isFalse);
      c.undoLastAction();
      expect(c.canEditCurrentSetLineup, isTrue);
    });

    test('reemplaza el set en curso y recalcula los automatismos del arranque', () {
      final c = _newController(startingServer: TeamSide.rival, receptionLiberoId: 'L1');
      expect(c.currentSet.currentOrderOwn[5], 'L1');

      // Nueva formación: C1 y C2 intercambiados de lugar, y sacamos nosotros.
      c.replaceCurrentSetLineup(
        startingOrderOwn: ['A1', 'P1', 'C2', 'O1', 'P2', 'C1'],
        startingServer: TeamSide.own,
        receptionLiberoId: 'L1',
      );
      expect(c.match.sets, hasLength(1));
      expect(c.currentSet.setNumber, 1);
      expect(c.servingTeam, TeamSide.own);
      expect(c.stage, RallyStage.serveOwn);
      // Sacamos y no hay líbero defensor: no entra nadie automáticamente.
      expect(c.currentSet.substitutions, isEmpty);
      expect(c.playerAtPosition(6), 'C1');
    });

    test('también sirve para el set 2 en adelante, sin tocar los sets anteriores', () {
      final c = _newController();
      c.simulateRestOfSet();
      c.confirmSetFinished();
      final set1 = c.match.sets.first;
      c.startSet(setNumber: 2, startingOrderOwn: List.of(_order), startingServer: TeamSide.rival);

      c.replaceCurrentSetLineup(
        startingOrderOwn: ['P1', 'C1', 'O1', 'P2', 'C2', 'A1'],
        startingServer: TeamSide.rival,
      );
      expect(c.match.sets, hasLength(2));
      expect(c.match.sets.first, same(set1));
      expect(c.currentSet.setNumber, 2);
      expect(c.playerAtPosition(1), 'P1');
    });

    test('no reemplaza nada si el set ya empezó', () {
      final c = _newController();
      c.logOpponentError();
      c.replaceCurrentSetLineup(
        startingOrderOwn: ['P1', 'C1', 'O1', 'P2', 'C2', 'A1'],
        startingServer: TeamSide.rival,
      );
      expect(c.currentSet.events, hasLength(1));
      expect(c.playerAtPosition(1), 'A1');
    });
  });

  group('UI', () {
    Widget wrap(Widget child) =>
        MaterialApp(theme: buildLightTheme(), home: Scaffold(body: child));

    testWidgets('el selector de zona muestra la franja media 7-8-9 solo con 9 zonas',
        (tester) async {
      int? picked;
      await tester.pumpWidget(wrap(HitZonePicker(
        selectedZone: null,
        nineZones: true,
        onChanged: (z) => picked = z,
      )));
      for (var z = 1; z <= 9; z++) {
        expect(find.text('$z'), findsOneWidget);
      }
      await tester.tap(find.text('7'));
      expect(picked, 7);

      await tester.pumpWidget(wrap(HitZonePicker(selectedZone: null, onChanged: (_) {})));
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('"Editar formación" corrige el set desde la pantalla en vivo', (tester) async {
      final c = _newController();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppDataController()),
          ChangeNotifierProvider.value(value: ThemeController()),
          ChangeNotifierProvider.value(value: SubscriptionController()),
        ],
        child: MaterialApp(theme: buildLightTheme(), home: LiveMatchScreen(controller: c)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Set 1 sin comenzar'), findsOneWidget);

      await tester.tap(find.text('Editar formación'));
      await tester.pumpAndSettle();
      expect(find.text('Editar formación — set 1'), findsOneWidget);

      // Cambia quién saca y guarda (el guardado real en Hive necesita E/S
      // real, por eso va dentro de runAsync).
      await tester.tap(find.text('Rival'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.text('Guardar formación'), find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar formación'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(c.servingTeam, TeamSide.rival);
      expect(c.match.sets, hasLength(1));
      expect(find.text('Set 1 sin comenzar'), findsOneWidget); // sigue sin comenzar

      // Una vez cargada una acción, el aviso desaparece.
      c.logOpponentError();
      await tester.pumpAndSettle();
      expect(find.text('Set 1 sin comenzar'), findsNothing);
    });

    testWidgets('los botones de rotar aparecen solo si el partido lo permite', (tester) async {
      final c = _newController();
      await tester.pumpWidget(wrap(CourtView(controller: c)));
      await tester.tap(find.text('Rotar'));
      expect(c.playerAtPosition(1), 'P1');

      await tester.pumpWidget(wrap(CourtView(controller: _newController(allowManualRotation: false))));
      expect(find.text('Rotar'), findsNothing);
      expect(find.text('Rotar atrás'), findsNothing);
    });
  });
}
