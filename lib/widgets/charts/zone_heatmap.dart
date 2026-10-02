import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/stat_line.dart';
import 'chart_palette.dart';

/// Mitad rival de la cancha (fondo arriba, red abajo, como `HitZonePicker`)
/// con cada zona pintada según cuántos toques fueron ahí: más oscuro = más
/// toques. Cada celda muestra la zona, la cantidad y el % que terminó en
/// punto (PP / total). Con [nineZones] suma la franja media 9-8-7.
class ZoneHeatmap extends StatelessWidget {
  const ZoneHeatmap({super.key, required this.byZone, required this.nineZones, this.maxWidth = 300});

  final Map<int, TouchStats> byZone;
  final bool nineZones;
  final double maxWidth;

  static const rows6 = [
    [1, 6, 5],
    [2, 3, 4],
  ];
  static const rows9 = [
    [1, 6, 5],
    [9, 8, 7],
    [2, 3, 4],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = math.min(constraints.maxWidth, maxWidth);
      return Center(
        child: SizedBox(
          width: w,
          height: w * (nineZones ? 1.0 : 0.82) + 10,
          child: CustomPaint(painter: _HeatmapPainter(byZone, nineZones, ChartPalette.of(context))),
        ),
      );
    });
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(this.byZone, this.nineZones, this.palette);

  final Map<int, TouchStats> byZone;
  final bool nineZones;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = nineZones ? ZoneHeatmap.rows9 : ZoneHeatmap.rows6;
    final courtH = size.height - 10;
    // En 6 zonas la fila de fondo (6 m) es el doble de alta que la de red
    // (3 m); en 9 zonas las tres franjas miden 3 m.
    final rowHeights = nineZones ? [courtH / 3, courtH / 3, courtH / 3] : [courtH * 2 / 3, courtH / 3];
    final cellW = size.width / 3;
    final maxCount = math.max(1, byZone.values.map((s) => s.total).fold(0, math.max));

    var top = 0.0;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 3; c++) {
        final zone = rows[r][c];
        final s = byZone[zone] ?? TouchStats();
        final intensity = s.total / maxCount;
        final rect = Rect.fromLTWH(c * cellW, top, cellW, rowHeights[r]);
        canvas.drawRect(rect, Paint()..color = palette.courtFill);
        if (s.total > 0) {
          canvas.drawRect(rect, Paint()..color = palette.positive.withValues(alpha: 0.12 + 0.78 * intensity));
        }
        canvas.drawRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = palette.courtLine
              ..strokeWidth = 0.6);
        final strong = intensity > 0.55;
        final fg = strong ? Colors.white : palette.text;
        final center = rect.center;
        paintChartText(canvas, 'Z$zone', center + const Offset(0, -17), style: palette.label(fontSize: 10, color: fg), align: TextAlign.center);
        paintChartText(canvas, '${s.total}', center,
            style: palette.label(fontSize: 19, fontWeight: FontWeight.bold, color: fg), align: TextAlign.center);
        if (s.total > 0) {
          paintChartText(canvas, '${(s.pp / s.total * 100).round()}% pto', center + const Offset(0, 16),
              style: palette.label(fontSize: 9.5, color: fg), align: TextAlign.center);
        }
      }
      top += rowHeights[r];
    }
    // Red.
    canvas.drawLine(Offset(-4, courtH + 2), Offset(size.width + 4, courtH + 2),
        Paint()
          ..color = palette.net
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) => old.byZone != byZone || old.palette.text != palette.text;
}
