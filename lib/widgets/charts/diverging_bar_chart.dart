import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';

/// Barras verticales que crecen hacia arriba (positivo, azul) o hacia abajo
/// (negativo, rojo) desde una línea de cero. Usado para la diferencia de
/// puntos por rotación (G-P).
class DivergingBarChart extends StatelessWidget {
  const DivergingBarChart({super.key, required this.labels, required this.values, this.height = 190});

  final List<String> labels;
  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _DivergingBarPainter(labels, values, ChartPalette.of(context))),
    );
  }
}

class _DivergingBarPainter extends CustomPainter {
  _DivergingBarPainter(this.labels, this.values, this.palette);

  final List<String> labels;
  final List<int> values;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 28.0, right = 6.0, top = 16.0, bottom = 22.0;
    final minV = math.min(0, values.reduce(math.min));
    final maxV = math.max(0, values.reduce(math.max));
    final step = niceIntStep(math.max(1, maxV - minV));
    // Un punto de margen arriba y abajo, para que la etiqueta de la barra más
    // larga no se pise con el eje ni con el nombre de la rotación.
    final lo = (((minV < 0 ? minV - 1 : 0) / step).floor() * step).toDouble();
    final hi = (math.max(maxV > 0 ? maxV + 1 : 0, lo + step) / step).ceil() * step.toDouble();
    final ph = size.height - top - bottom;
    final pw = size.width - left - right;
    double y(num v) => top + (hi - v) / (hi - lo) * ph;

    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 0.6;
    final zeroPaint = Paint()
      ..color = palette.zeroLine
      ..strokeWidth = 1;
    final axisStyle = palette.label(fontSize: 10, color: palette.textMuted);
    for (var v = lo; v <= hi + 0.001; v += step) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width - right, y(v)), v == 0 ? zeroPaint : gridPaint);
      paintChartText(canvas, '${v.round()}', Offset(left - 5, y(v)), style: axisStyle, align: TextAlign.right);
    }

    final slot = pw / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final v = values[i];
      final cx = left + slot * (i + 0.5);
      final bw = math.min(slot * 0.62, 46.0);
      final color = v >= 0 ? palette.positive : palette.negative;
      if (v != 0) {
        canvas.drawRect(
          Rect.fromLTRB(cx - bw / 2, math.min(y(0), y(v)), cx + bw / 2, math.max(y(0), y(v))),
          Paint()..color = color,
        );
      }
      final valueStyle = palette.label(fontSize: 11, fontWeight: FontWeight.bold, color: v == 0 ? palette.textMuted : color);
      paintChartText(canvas, signedInt(v), Offset(cx, v >= 0 ? y(v) - 8 : y(v) + 8),
          style: valueStyle, align: TextAlign.center);
      paintChartText(canvas, labels[i], Offset(cx, size.height - 9),
          style: palette.label(fontSize: 11, fontWeight: FontWeight.bold, color: palette.text), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _DivergingBarPainter old) =>
      old.values != values || old.labels != labels || old.palette.text != palette.text;
}
