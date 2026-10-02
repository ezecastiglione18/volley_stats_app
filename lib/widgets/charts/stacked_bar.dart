import 'package:flutter/material.dart';

import 'chart_palette.dart';

class ChartSegment {
  const ChartSegment(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

/// Barra horizontal apilada: cada segmento ocupa un ancho proporcional a su
/// valor y muestra adentro su cantidad (o su % si [showPercent]) cuando
/// entra. Usada en "Origen de los puntos" y "Recepción por jugador".
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.segments, this.height = 20, this.showPercent = false});

  final List<ChartSegment> segments;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
          painter: _StackedBarPainter(segments, showPercent, Theme.of(context).textTheme.bodyMedium?.fontFamily)),
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter(this.segments, this.showPercent, this.fontFamily);

  final List<ChartSegment> segments;
  final bool showPercent;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final sum = segments.fold<int>(0, (a, s) => a + s.value);
    if (sum == 0) return;
    var x = 0.0;
    final style = TextStyle(fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white);
    for (final s in segments) {
      if (s.value <= 0) continue;
      final w = size.width * s.value / sum;
      canvas.drawRect(Rect.fromLTWH(x, 0, (w - 1).clamp(0.5, w), size.height), Paint()..color = s.color);
      final label = showPercent ? '${(s.value / sum * 100).round()}%' : '${s.value}';
      if (measureChartText(label, style) + 4 < w) {
        paintChartText(canvas, label, Offset(x + w / 2, size.height / 2), style: style, align: TextAlign.center);
      }
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) => old.segments != segments;
}

/// Leyenda de colores (cuadradito + texto) para barras apiladas.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(label, style: style),
          ]),
      ],
    );
  }
}
