import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';

/// Pares de barras de porcentaje (0–100 %) por categoría. Usado para
/// side-out y break-point por rotación. Un valor null (sin rallies de ese
/// tipo) no dibuja barra y muestra "—".
class GroupedPctBarChart extends StatelessWidget {
  const GroupedPctBarChart({
    super.key,
    required this.labels,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    this.height = 180,
  });

  final List<String> labels;
  final List<double?> a;
  final List<double?> b;
  final Color colorA;
  final Color colorB;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _GroupedPctPainter(this, ChartPalette.of(context))),
    );
  }
}

class _GroupedPctPainter extends CustomPainter {
  _GroupedPctPainter(this.chart, this.palette);

  final GroupedPctBarChart chart;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 6.0, top = 14.0, bottom = 22.0;
    final ph = size.height - top - bottom;
    final pw = size.width - left - right;
    double y(double v) => top + (1 - v) * ph;

    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 0.6;
    final axisStyle = palette.label(fontSize: 10, color: palette.textMuted);
    for (var v = 0.0; v <= 1.001; v += 0.25) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width - right, y(v)), gridPaint);
      paintChartText(canvas, '${(v * 100).round()}%', Offset(left - 5, y(v)), style: axisStyle, align: TextAlign.right);
    }
    // Referencia del 50 %.
    _dashedLine(canvas, Offset(left, y(0.5)), Offset(size.width - right, y(0.5)),
        Paint()
          ..color = palette.zeroLine
          ..strokeWidth = 0.8);

    final slot = pw / chart.labels.length;
    for (var i = 0; i < chart.labels.length; i++) {
      final cx = left + slot * (i + 0.5);
      final bw = math.min(slot * 0.3, 22.0);
      _bar(canvas, chart.a[i], cx - bw - 1.5, bw, chart.colorA, y);
      _bar(canvas, chart.b[i], cx + 1.5, bw, chart.colorB, y);
      paintChartText(canvas, chart.labels[i], Offset(cx, size.height - 9),
          style: palette.label(fontSize: 11, fontWeight: FontWeight.bold, color: palette.text), align: TextAlign.center);
    }
  }

  void _bar(Canvas canvas, double? v, double x, double bw, Color color, double Function(double) y) {
    final style = palette.label(fontSize: 9.5, fontWeight: FontWeight.bold, color: v == null ? palette.textMuted : color);
    if (v == null) {
      paintChartText(canvas, '—', Offset(x + bw / 2, y(0) - 8), style: style, align: TextAlign.center);
      return;
    }
    canvas.drawRect(Rect.fromLTRB(x, y(v), x + bw, y(0)), Paint()..color = color);
    paintChartText(canvas, '${(v * 100).round()}', Offset(x + bw / 2, y(v) - 7), style: style, align: TextAlign.center);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
    var x = a.dx;
    while (x < b.dx) {
      canvas.drawLine(Offset(x, a.dy), Offset(math.min(x + dash, b.dx), a.dy), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedPctPainter old) => old.chart != chart || old.palette.text != palette.text;
}
