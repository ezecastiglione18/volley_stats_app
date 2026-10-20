// Reproducción de jugadas de la pizarra (issue #51): la lógica pura de qué
// dibujar según el progreso, el parámetro `progress` del dibujante y la
// pantalla de reproducción.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/models/play.dart';
import 'package:rally_stats/screens/whiteboard/play_playback_screen.dart';
import 'package:rally_stats/screens/whiteboard/widgets/playback.dart';
import 'package:rally_stats/screens/whiteboard/widgets/whiteboard_painter.dart';

/// Trazo horizontal de [n] puntos con x = 0, 1, 2, ... (fácil de verificar).
PlayStroke _stroke(int n, {bool arrow = false, int color = 0xFF1565C0}) => PlayStroke(
      colorValue: color,
      arrow: arrow,
      pointsX: [for (var i = 0; i < n; i++) i.toDouble()],
      pointsY: [for (var i = 0; i < n; i++) 0.5],
    );

void main() {
  group('visibleStrokes (lógica pura)', () {
    test('progress 0: todavía no se dibuja nada', () {
      expect(visibleStrokes([_stroke(4), _stroke(4)], 0), isEmpty);
    });

    test('progress 1: todos los trazos completos y con todos sus puntos', () {
      final strokes = [_stroke(4, arrow: true), _stroke(3)];
      final v = visibleStrokes(strokes, 1);

      expect(v, hasLength(2));
      expect(v.every((s) => s.complete), isTrue);
      expect(v[0].xs, strokes[0].pointsX);
      expect(v[1].xs, strokes[1].pointsX);
    });

    test('progress 0.5 con dos trazos iguales: el primero completo y el segundo todavía no empezó', () {
      final v = visibleStrokes([_stroke(4), _stroke(4)], 0.5); // 4 de 8 puntos

      expect(v, hasLength(1));
      expect(v.single.complete, isTrue);
    });

    test('el progreso se reparte por cantidad de puntos, no por trazo', () {
      // 2 + 6 puntos: a 0.25 solo alcanza para el trazo corto (2 de 8).
      final v = visibleStrokes([_stroke(2), _stroke(6)], 0.25);
      expect(v, hasLength(1));
      expect(v.single.xs, hasLength(2));

      // A 0.5 (4 de 8) el segundo trazo ya va por su 2º punto.
      final mid = visibleStrokes([_stroke(2), _stroke(6)], 0.5);
      expect(mid, hasLength(2));
      expect(mid[0].complete, isTrue);
      expect(mid[1].complete, isFalse);
      expect(mid[1].xs, [0.0, 1.0]);
    });

    test('el trazo en curso se corta en el punto proporcional (interpolando)', () {
      // 4 puntos con x = 0,1,2,3; progress 0.625 -> 2.5 puntos: 0, 1 y la
      // mitad del camino entre 1 y 2.
      final v = visibleStrokes([_stroke(4)], 0.625);

      expect(v.single.complete, isFalse);
      expect(v.single.xs, [0.0, 1.0, 1.5]);
      expect(v.single.ys, [0.5, 0.5, 0.5]);
    });

    test('trazo de un solo punto: aparece completo cuando le toca su parte', () {
      // 1 + 3 puntos. A 0.25 (1 de 4) el de un punto ya está completo.
      final v = visibleStrokes([_stroke(1), _stroke(3)], 0.25);

      expect(v, hasLength(1));
      expect(v.single.complete, isTrue);
      expect(v.single.xs, [0.0]);

      // Sin progreso suficiente todavía no está.
      expect(visibleStrokes([_stroke(1), _stroke(3)], 0), isEmpty);
    });

    test('la flecha aparece solo cuando el trazo está completo', () {
      final strokes = [_stroke(4, arrow: true)];

      final casiListo = visibleStrokes(strokes, 0.99).single;
      expect(casiListo.complete, isFalse);
      expect(casiListo.showArrow, isFalse);

      final listo = visibleStrokes(strokes, 1).single;
      expect(listo.complete, isTrue);
      expect(listo.showArrow, isTrue);
    });

    test('un trazo completo SIN flecha nunca muestra flecha', () {
      expect(visibleStrokes([_stroke(4)], 1).single.showArrow, isFalse);
    });

    test('progress fuera de rango se acota a 0..1', () {
      expect(visibleStrokes([_stroke(4)], -1), isEmpty);
      expect(visibleStrokes([_stroke(4)], 5).single.complete, isTrue);
    });

    test('sin trazos (o sin puntos) no hay nada que dibujar', () {
      expect(visibleStrokes(const [], 0.5), isEmpty);
      expect(visibleStrokes([_stroke(0)], 0.5), isEmpty);
    });

    test('no modifica los trazos originales al cortar el que está en curso', () {
      final original = _stroke(4);
      visibleStrokes([original], 0.5);
      expect(original.pointsX, [0.0, 1.0, 2.0, 3.0]);
    });
  });

  group('duración', () {
    test('totalPoints suma los puntos de todos los trazos', () {
      expect(totalPoints([_stroke(3), _stroke(5)]), 8);
      expect(totalPoints(const []), 0);
    });

    test('8 ms por punto, acotada entre 2 y 12 segundos', () {
      expect(playbackDuration(10), const Duration(seconds: 2)); // 80 ms -> mínimo
      expect(playbackDuration(500), const Duration(seconds: 4)); // 4000 ms
      expect(playbackDuration(5000), const Duration(seconds: 12)); // 40 s -> máximo
    });
  });

  group('WhiteboardPainter.progress', () {
    test('cambiar el progreso obliga a redibujar; el mismo valor, no', () {
      final strokes = [_stroke(4)];
      WhiteboardPainter painter({double? progress}) => WhiteboardPainter(
            strokes: strokes,
            courtColor: Colors.white,
            lineColor: Colors.black,
            progress: progress,
          );

      expect(painter(progress: 0.5).shouldRepaint(painter()), isTrue);
      expect(painter(progress: 0.5).shouldRepaint(painter(progress: 0.6)), isTrue);
      expect(painter(progress: 0.5).shouldRepaint(painter(progress: 0.5)), isFalse);
      expect(painter().shouldRepaint(painter()), isFalse);
    });
  });

  group('PlayPlaybackScreen', () {
    // 500 puntos -> 4 s a 1×.
    final play = Play(
      id: 'p1',
      name: 'Rotación 3',
      date: DateTime(2026, 1, 1),
      strokes: [_stroke(250, arrow: true), _stroke(250)],
      tokens: const [
        PlacedToken(tokenId: 'A1', label: 'A', colorValue: 0xFF000000, x: 0.5, y: 0.3),
      ],
    );

    Widget app() => MaterialApp(home: PlayPlaybackScreen(play: play));

    Slider slider(WidgetTester t) => t.widget<Slider>(find.byType(Slider));

    testWidgets('arranca reproduciendo, avanza y al terminar ofrece repetir', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Rotación 3'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget, reason: 'arranca reproduciendo');
      expect(find.text('A'), findsOneWidget, reason: 'el fichín se ve desde el primer cuadro');

      await tester.pump(const Duration(seconds: 2));
      expect(slider(tester).value, inExclusiveRange(0.3, 0.7));

      await tester.pump(const Duration(seconds: 3)); // pasa los 4 s totales
      await tester.pump();
      expect(slider(tester).value, 1.0);
      expect(find.byIcon(Icons.replay), findsOneWidget);
    });

    testWidgets('pausa, retoma y reinicia', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      final pausedAt = slider(tester).value;
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(slider(tester).value, pausedAt, reason: 'en pausa no avanza');

      await tester.tap(find.byIcon(Icons.play_arrow));
      // El primer cuadro tras arrancar el reloj solo fija su punto de partida;
      // el tiempo empieza a contar desde el siguiente.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(slider(tester).value, greaterThan(pausedAt));

      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pump();
      expect(slider(tester).value, lessThan(0.1));
      expect(find.byIcon(Icons.pause), findsOneWidget, reason: 'reiniciar vuelve a reproducir');
    });

    testWidgets('arrastrar el slider pausa en el punto elegido', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: 'queda pausado');
      expect(slider(tester).value, inExclusiveRange(0.3, 0.7));
    });

    testWidgets('a 2× tarda la mitad', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('2×'));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 2100)); // 4 s / 2 = 2 s
      await tester.pump();
      expect(slider(tester).value, 1.0);
    });
  });
}
