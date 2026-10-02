import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';

class EfficiencyRow {
  const EfficiencyRow({required this.label, required this.efficiency, required this.detail});
  final String label;

  /// Fracción (puede ser negativa).
  final double efficiency;

  /// Texto chico a la derecha, p. ej. "9 pts · 2 err · 23 tot".
  final String detail;
}

/// Barras horizontales de eficiencia, una por jugador, que crecen hacia la
/// derecha (positivo) o la izquierda (negativo) desde 0 %. Pensado para el
/// ancho de un celular: cada jugador ocupa dos renglones (nombre y detalle
/// arriba, la barra a todo el ancho abajo), así la escala no queda apretada
/// entre las dos columnas de texto.
class EfficiencyBarsChart extends StatelessWidget {
  const EfficiencyBarsChart({super.key, required this.rows});

  final List<EfficiencyRow> rows;

  static const rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rows.length * rowHeight + 18,
      width: double.infinity,
      child: CustomPaint(painter: _EfficiencyPainter(rows, ChartPalette.of(context))),
    );
  }
}

class _EfficiencyPainter extends CustomPainter {
  _EfficiencyPainter(this.rows, this.palette);

  final List<EfficiencyRow> rows;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    // Margen a los costados para que el % de una barra en el extremo de la
    // escala no se salga del gráfico.
    const left = 38.0;
    final right = size.width - 38;
    // Escala de -40 % a +80 % como mínimo, ampliada si algún valor se pasa.
    final lo = math.min(-0.4, (rows.map((r) => r.efficiency).reduce(math.min) * 5).floor() / 5);
    final hi = math.max(0.8, (rows.map((r) => r.efficiency).reduce(math.max) * 5).ceil() / 5);
    double x(double v) => left + (v - lo) / (hi - lo) * (right - left);
    final plotH = rows.length * EfficiencyBarsChart.rowHeight;

    final axisStyle = palette.label(fontSize: 9.5, color: palette.textMuted);
    for (var v = lo; v <= hi + 0.001; v += 0.2) {
      final isZero = v.abs() < 0.001;
      canvas.drawLine(Offset(x(v), 0), Offset(x(v), plotH),
          Paint()
            ..color = isZero ? palette.zeroLine : palette.grid
            ..strokeWidth = isZero ? 1 : 0.5);
      paintChartText(canvas, '${(v * 100).round()}%', Offset(x(v), plotH + 9), style: axisStyle, align: TextAlign.center);
    }

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final top = i * EfficiencyBarsChart.rowHeight;
      final detailStyle = palette.label(fontSize: 10, color: palette.textMuted);
      final detailW = measureChartText(r.detail, detailStyle);
      paintChartText(canvas, r.label, Offset(0, top + 9),
          style: palette.label(fontSize: 12, fontWeight: FontWeight.bold, color: palette.text),
          maxWidth: math.max(40, size.width - detailW - 12));
      paintChartText(canvas, r.detail, Offset(size.width, top + 9), style: detailStyle, align: TextAlign.right);

      final cy = top + 28;
      final e = r.efficiency;
      final color = e >= 0 ? palette.positive : palette.negative;
      canvas.drawRect(Rect.fromLTRB(math.min(x(0), x(e)), cy - 7, math.max(x(0), x(e)), cy + 7), Paint()..color = color);
      paintChartText(canvas, signedPct(e), Offset(e >= 0 ? x(e) + 4 : x(e) - 4, cy),
          style: palette.label(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          align: e >= 0 ? TextAlign.left : TextAlign.right);
    }
  }

  @override
  bool shouldRepaint(covariant _EfficiencyPainter old) => old.rows != rows || old.palette.text != palette.text;
}
