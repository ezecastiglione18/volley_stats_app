import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/visual_stats.dart';
import '../../utils/court_geometry.dart';
import 'chart_palette.dart';

/// Cancha compacta con una flecha por toque (mapa de dirección, spec 5.2 y
/// boceto `tool/generate_propuesta_estadistica.dart`, función drawShot). El
/// trazo dice el resultado: continua = punto, punteada = adentro, doble
/// punteada = afuera, barra en la red = bloqueado, cruz en la red = a la
/// red, punteada roja = error sin detalle. Tocar una flecha la elige
/// ([onShotTap]); tocar fuera de las flechas la deselecciona.
class CourtShotsChart extends StatelessWidget {
  const CourtShotsChart({
    super.key,
    required this.shots,
    this.selected,
    this.onShotTap,
    this.maxWidth = 340,
  });

  final List<CourtShot> shots;
  final CourtShot? selected;
  final ValueChanged<CourtShot?>? onShotTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, maxWidth);
      final geo = CourtGeometry(width);
      return Center(
        child: GestureDetector(
          onTapUp: onShotTap == null ? null : (d) => onShotTap!(_hitTest(geo, d.localPosition)),
          child: CustomPaint(
            size: Size(width, geo.height),
            painter: _CourtShotsPainter(shots, selected, geo, palette, surface),
          ),
        ),
      );
    });
  }

  /// La flecha más cercana al toque, si está a menos de 16 px.
  CourtShot? _hitTest(CourtGeometry geo, Offset p) {
    CourtShot? best;
    var bestDist = 16.0;
    for (final s in shots) {
      final d = distanceToSegment(
          p.dx, p.dy, geo.px(s.originX), geo.py(s.originY), geo.px(s.targetX), geo.py(s.targetY));
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}

class _CourtShotsPainter extends CustomPainter {
  _CourtShotsPainter(this.shots, this.selected, this.geo, this.palette, this.surface);

  final List<CourtShot> shots;
  final CourtShot? selected;
  final CourtGeometry geo;
  final ChartPalette palette;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    paintCompactCourt(canvas, geo, palette, surface);
    for (final s in shots) {
      if (identical(s, selected)) continue;
      paintShotStroke(canvas, Offset(geo.px(s.originX), geo.py(s.originY)), Offset(geo.px(s.targetX), geo.py(s.targetY)),
          s.result, palette, dim: selected != null);
    }
    final sel = selected;
    if (sel != null) {
      paintShotStroke(canvas, Offset(geo.px(sel.originX), geo.py(sel.originY)),
          Offset(geo.px(sel.targetX), geo.py(sel.targetY)), sel.result, palette, scale: 1.7);
    }
  }

  @override
  bool shouldRepaint(covariant _CourtShotsPainter old) =>
      old.shots != shots || old.selected != selected || old.geo.width != geo.width || old.palette.text != palette.text;
}

/// Cancha compacta: margen de afuera, mitad rival a escala con sus zonas,
/// mitad propia comprimida, líneas de 3 m y red.
void paintCompactCourt(Canvas canvas, CourtGeometry geo, ChartPalette palette, Color surface) {
  final outer = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, geo.width, geo.height), const Radius.circular(6));
  canvas.drawRRect(outer, Paint()..color = surface);
  canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = palette.grid);
  final left = geo.px(0), right = geo.px(1);
  canvas.drawRect(Rect.fromLTRB(left, geo.py(0), right, geo.py(0.5)), Paint()..color = palette.courtFill);
  canvas.drawRect(Rect.fromLTRB(left, geo.py(0.5), right, geo.py(1)),
      Paint()..color = palette.courtFill.withValues(alpha: 0.45));
  final line = Paint()
    ..color = palette.courtLine
    ..strokeWidth = 0.8
    ..style = PaintingStyle.stroke;
  canvas.drawRect(Rect.fromLTRB(left, geo.py(0), right, geo.py(1)), line);
  final thin = Paint()
    ..color = palette.courtLine
    ..strokeWidth = 0.5;
  canvas.drawLine(Offset(left, geo.py(1 / 3)), Offset(right, geo.py(1 / 3)), thin);
  canvas.drawLine(Offset(left, geo.py(2 / 3)), Offset(right, geo.py(2 / 3)), thin);
  final dotted = Paint()
    ..color = palette.courtLine.withValues(alpha: 0.7)
    ..strokeWidth = 0.5;
  for (final x in [1 / 3, 2 / 3]) {
    _dashedLine(canvas, Offset(geo.px(x), geo.py(0)), Offset(geo.px(x), geo.py(0.5)), dotted, 1.5, 3);
  }
  final zoneStyle = palette.label(
      fontSize: geo.courtWidth > 200 ? 13 : 10, fontWeight: FontWeight.bold, color: palette.courtLine.withValues(alpha: 0.8));
  const rows = [
    [1, 6, 5],
    [2, 3, 4],
  ];
  for (var r = 0; r < 2; r++) {
    for (var c = 0; c < 3; c++) {
      paintChartText(canvas, '${rows[r][c]}', Offset(geo.px((c + 0.5) / 3), geo.py(r == 0 ? 1 / 6 : 5 / 12)),
          style: zoneStyle, align: TextAlign.center);
    }
  }
  canvas.drawLine(Offset(geo.px(-0.05), geo.py(0.5)), Offset(geo.px(1.05), geo.py(0.5)),
      Paint()
        ..color = palette.net
        ..strokeWidth = 2.4);
}

/// Color del trazo según el resultado.
Color shotColor(ShotResult r, ChartPalette palette) {
  switch (r) {
    case ShotResult.point:
      return palette.positive;
    case ShotResult.inPlay:
      return palette.slate;
    case ShotResult.blocked:
      return kChartBlock;
    case ShotResult.out:
    case ShotResult.net:
    case ShotResult.error:
      return palette.negative;
  }
}

/// Dibuja un toque de [a] (origen) a [b] (destino) con el trazo de su
/// resultado. [scale] agranda todo (flecha elegida); [dim] atenúa (cuando
/// hay otra elegida).
void paintShotStroke(Canvas canvas, Offset a, Offset b, ShotResult result, ChartPalette palette,
    {double scale = 1, bool dim = false}) {
  final color = shotColor(result, palette).withValues(alpha: dim ? 0.3 : 1);
  final k = scale;
  final d = b - a;
  final len = math.max(0.001, d.distance);
  final u = d / len;
  final n = Offset(-u.dy, u.dx);
  final head = 5.0 * k;
  final end = b - u * head * 0.8; // la línea termina donde empieza la punta
  final paint = Paint()
    ..color = color
    ..strokeCap = StrokeCap.butt;

  switch (result) {
    case ShotResult.point:
      canvas.drawLine(a, end, paint..strokeWidth = 1.5 * k);
      _arrowHead(canvas, a, b, color, head);
      break;
    case ShotResult.inPlay:
      _dashedLine(canvas, a, end, paint..strokeWidth = 1.1 * k, 3.5 * k, 2.5 * k);
      _arrowHead(canvas, a, b, color, head);
      break;
    case ShotResult.error:
      _dashedLine(canvas, a, end, paint..strokeWidth = 1.1 * k, 2.5 * k, 2 * k);
      _arrowHead(canvas, a, b, color, head);
      break;
    case ShotResult.out:
      final o = n * 1.4 * k;
      paint.strokeWidth = 0.8 * k;
      _dashedLine(canvas, a + o, end + o, paint, 3 * k, 2 * k);
      _dashedLine(canvas, a - o, end - o, paint, 3 * k, 2 * k);
      _arrowHead(canvas, a, b, color, head);
      break;
    case ShotResult.blocked:
      canvas.drawLine(a, b, paint..strokeWidth = 1.5 * k);
      final bar = n * 4.5 * k;
      canvas.drawLine(b + bar, b - bar, Paint()
        ..color = color
        ..strokeWidth = 2 * k);
      break;
    case ShotResult.net:
      _dashedLine(canvas, a, b, paint..strokeWidth = 1 * k, 1.5 * k, 1.8 * k);
      final c = 3.2 * k;
      final cross = Paint()
        ..color = color
        ..strokeWidth = 1.5 * k;
      canvas.drawLine(b + Offset(-c, -c), b + Offset(c, c), cross);
      canvas.drawLine(b + Offset(-c, c), b + Offset(c, -c), cross);
      break;
  }
  canvas.drawCircle(a, 1.6 * k, Paint()..color = palette.textMuted.withValues(alpha: dim ? 0.3 : 1));
}

void _arrowHead(Canvas canvas, Offset a, Offset b, Color color, double size) {
  final d = b - a;
  if (d.distance < 0.01) return;
  final u = d / d.distance;
  final n = Offset(-u.dy, u.dx);
  final base = b - u * size;
  canvas.drawPath(
    Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo((base + n * size * 0.45).dx, (base + n * size * 0.45).dy)
      ..lineTo((base - n * size * 0.45).dx, (base - n * size * 0.45).dy)
      ..close(),
    Paint()..color = color,
  );
}

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
  final d = b - a;
  final len = d.distance;
  if (len < 0.01) return;
  final u = d / len;
  var t = 0.0;
  while (t < len) {
    final t2 = math.min(t + dash, len);
    canvas.drawLine(a + u * t, a + u * t2, paint);
    t += dash + gap;
  }
}

/// Leyenda de trazos (muestra + texto) para los resultados dados.
class ShotLegend extends StatelessWidget {
  const ShotLegend({super.key, required this.results});

  final List<ShotResult> results;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final style = TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final r in results)
          Row(mainAxisSize: MainAxisSize.min, children: [
            CustomPaint(size: const Size(34, 12), painter: _LegendStrokePainter(r, palette)),
            const SizedBox(width: 5),
            Text(r.label, style: style),
          ]),
      ],
    );
  }
}

class _LegendStrokePainter extends CustomPainter {
  _LegendStrokePainter(this.result, this.palette);

  final ShotResult result;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final endInset = result == ShotResult.blocked || result == ShotResult.net ? 5.0 : 1.0;
    paintShotStroke(canvas, Offset(3, size.height / 2), Offset(size.width - endInset, size.height / 2), result, palette);
  }

  @override
  bool shouldRepaint(covariant _LegendStrokePainter old) => old.result != result || old.palette.text != palette.text;
}
