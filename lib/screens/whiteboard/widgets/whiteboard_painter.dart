import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/play.dart';

/// Dibuja la cancha de vóley (dos mitades separadas por la red, con las
/// líneas de ataque a 3m) y encima los trazos guardados/en curso, todo en
/// coordenadas normalizadas (0.0–1.0) mapeadas al tamaño real del canvas.
class WhiteboardPainter extends CustomPainter {
  final List<PlayStroke> strokes;
  final List<Offset>? livePoints;
  final Color? liveColor;
  final bool liveArrow;
  final Color courtColor;
  final Color lineColor;

  WhiteboardPainter({
    required this.strokes,
    required this.courtColor,
    required this.lineColor,
    this.livePoints,
    this.liveColor,
    this.liveArrow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(court, Paint()..color = courtColor);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(court.deflate(1), linePaint);
    // Red al medio de la cancha.
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint..strokeWidth = 3,
    );
    // Líneas de ataque a 3m de la red (cancha reglamentaria de 9m de largo
    // por lado -> 3/9 del alto de cada mitad).
    final attackDash = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final topAttackY = size.height / 2 - size.height / 6;
    final bottomAttackY = size.height / 2 + size.height / 6;
    canvas.drawLine(Offset(0, topAttackY), Offset(size.width, topAttackY), attackDash);
    canvas.drawLine(Offset(0, bottomAttackY), Offset(size.width, bottomAttackY), attackDash);

    for (final stroke in strokes) {
      _drawStroke(
        canvas,
        size,
        _denormalize(stroke.pointsX, stroke.pointsY, size),
        Color(stroke.colorValue),
        stroke.arrow,
      );
    }
    if (livePoints != null && livePoints!.length > 1 && liveColor != null) {
      _drawStroke(canvas, size, livePoints!, liveColor!, liveArrow);
    }
  }

  List<Offset> _denormalize(List<double> xs, List<double> ys, Size size) {
    return List.generate(xs.length, (i) => Offset(xs[i] * size.width, ys[i] * size.height));
  }

  void _drawStroke(Canvas canvas, Size size, List<Offset> points, Color color, bool arrow) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);

    if (arrow) {
      final tip = points.last;
      final prev = points[points.length - 2];
      final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
      const arrowLength = 14.0;
      const arrowAngle = math.pi / 7;
      final p1 = tip - Offset(math.cos(angle - arrowAngle), math.sin(angle - arrowAngle)) * arrowLength;
      final p2 = tip - Offset(math.cos(angle + arrowAngle), math.sin(angle + arrowAngle)) * arrowLength;
      final headPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(Path()..addPolygon([tip, p1, p2], true), headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.livePoints != livePoints ||
        oldDelegate.liveColor != liveColor ||
        oldDelegate.liveArrow != liveArrow;
  }
}
