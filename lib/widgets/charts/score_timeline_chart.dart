import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/rally_event.dart';
import '../../models/visual_stats.dart';
import 'chart_palette.dart';

/// Evolución de la diferencia del marcador de un set, rally por rally: una
/// columna por rally (azul arriba de cero si el equipo propio va ganando,
/// roja abajo si va perdiendo), una línea con la diferencia, las rachas de
/// 4 o más puntos etiquetadas y una marca chica en el eje por cada cambio
/// de jugador.
class ScoreTimelineChart extends StatelessWidget {
  const ScoreTimelineChart({super.key, required this.timeline, this.height = 170});

  final SetTimeline timeline;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TimelinePainter(timeline, ChartPalette.of(context))),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.timeline, this.palette);

  final SetTimeline timeline;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final points = timeline.points;
    if (points.isEmpty) return;
    const left = 26.0, right = 8.0, top = 18.0, bottom = 20.0;
    // Dos puntos de margen arriba y abajo: ahí van las etiquetas de las rachas.
    final maxAbs = points.map((p) => p.diff.abs()).reduce(math.max) + 2;
    final ph = size.height - top - bottom;
    final pw = size.width - left - right;
    double y(num v) => top + (maxAbs - v) / (2 * maxAbs) * ph;
    final step = pw / points.length;

    final axisStyle = palette.label(fontSize: 9.5, color: palette.textMuted);
    final gridStep = maxAbs > 8 ? 4 : 2;
    for (var v = -maxAbs; v <= maxAbs; v++) {
      if (v % gridStep != 0) continue;
      canvas.drawLine(
        Offset(left, y(v)),
        Offset(size.width - right, y(v)),
        Paint()
          ..color = v == 0 ? palette.zeroLine : palette.grid
          ..strokeWidth = v == 0 ? 1 : 0.5,
      );
      paintChartText(canvas, signedInt(v), Offset(left - 5, y(v)), style: axisStyle, align: TextAlign.right);
    }

    for (var i = 0; i < points.length; i++) {
      final d = points[i].diff;
      if (d == 0) continue;
      final color = (d > 0 ? palette.positive : palette.negative).withValues(alpha: 0.3);
      canvas.drawRect(
        Rect.fromLTRB(left + i * step + step * 0.12, math.min(y(0), y(d)), left + (i + 1) * step - step * 0.12,
            math.max(y(0), y(d))),
        Paint()..color = color,
      );
    }

    final path = Path()..moveTo(left, y(0));
    for (var i = 0; i < points.length; i++) {
      path.lineTo(left + (i + 1) * step, y(points[i].diff));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    for (final run in timeline.runs()) {
      final own = run.team == TeamSide.own;
      final color = own ? palette.positive : palette.negative;
      final x0 = left + run.start * step, x1 = left + run.end * step;
      final endY = y(points[run.end - 1].diff);
      final ly = own ? endY - 12 : endY + 12;
      final label = own ? 'Racha ${run.length}-0' : 'Racha 0-${run.length}';
      canvas.drawLine(Offset(x0 + 1, own ? ly + 6 : ly - 6), Offset(x1 - 1, own ? ly + 6 : ly - 6),
          Paint()
            ..color = color
            ..strokeWidth = 1);
      paintChartText(canvas, label, Offset((x0 + x1) / 2, ly),
          style: palette.label(fontSize: 9.5, fontWeight: FontWeight.bold, color: color), align: TextAlign.center);
    }

    final markPaint = Paint()..color = palette.textMuted;
    for (final m in timeline.substitutionMarks) {
      final x = left + m * step;
      final base = size.height - bottom + 1;
      canvas.drawPath(
        Path()
          ..moveTo(x, base)
          ..lineTo(x - 3, base + 5)
          ..lineTo(x + 3, base + 5)
          ..close(),
        markPaint,
      );
    }

    final tickEvery = points.length > 40 ? 10 : 5;
    for (var k = tickEvery; k <= points.length; k += tickEvery) {
      paintChartText(canvas, '$k', Offset(left + k * step, size.height - 6), style: axisStyle, align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.timeline != timeline || old.palette.text != palette.text;
}
