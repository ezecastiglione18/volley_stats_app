import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/rally_event.dart';
import '../models/stat_line.dart';
import '../models/visual_stats.dart';
import '../utils/court_geometry.dart';

/// Gráficos de la estadística visual para el PDF del partido. Misma
/// geometría que los `CustomPainter` de `lib/widgets/charts/` (y que el
/// boceto `tool/generate_propuesta_estadistica.dart`), dibujada con
/// `package:pdf`. Ojo con el texto: el reporte usa las fuentes estándar
/// del PDF (Helvetica, codificación WinAnsi), así que nada de "−" (U+2212),
/// flechas ni símbolos fuera de Latin-1: usar "-" común.

const pdfPositive = PdfColor.fromInt(0xFF1E88E5);
const pdfPositiveLight = PdfColor.fromInt(0xFF64B5F6);
const pdfNegative = PdfColor.fromInt(0xFFE64A3B);
const pdfNegativeDark = PdfColor.fromInt(0xFFB71C1C);
const pdfWarning = PdfColor.fromInt(0xFFFFB74D);
const pdfSold = PdfColor.fromInt(0xFFFF8A65);
const pdfExcl = PdfColor.fromInt(0xFF9CCC65);
const pdfBlock = PdfColor.fromInt(0xFFE39A12);
const pdfNavy = PdfColor.fromInt(0xFF1E2A38);
const pdfCyan = PdfColor.fromInt(0xFF3DC2EC);
const pdfSlate = PdfColor.fromInt(0xFF475569);
const pdfNeutral = PdfColor.fromInt(0xFF9CA3AF);
const pdfGrid = PdfColor.fromInt(0xFFE5E7EB);
const pdfZero = PdfColor.fromInt(0xFF9CA3AF);
const pdfText = PdfColor.fromInt(0xFF1B1F24);
const pdfMuted = PdfColor.fromInt(0xFF6B7280);
const pdfCourt = PdfColor.fromInt(0xFFE8F1FA);

/// Lienzo con coordenadas "y hacia abajo" desde la esquina superior
/// izquierda del widget (más natural para portar los `CustomPainter`).
class PdfChartCanvas {
  PdfChartCanvas(this.context, this._ox, this._oy, this.width, this.height)
      : _font = (pw.Theme.of(context).defaultTextStyle.fontNormal ?? pw.Font.helvetica()).getFont(context),
        _fontBold = (pw.Theme.of(context).defaultTextStyle.fontBold ?? pw.Font.helveticaBold()).getFont(context);

  final pw.Context context;
  final double _ox, _oy;
  final double width, height;
  final PdfFont _font;
  final PdfFont _fontBold;

  PdfGraphics get g => context.canvas;
  double _x(double x) => _ox + x;
  double _y(double y) => _oy + height - y;

  void line(double x1, double y1, double x2, double y2, PdfColor color, {double width = 1, List<num>? dash}) {
    g
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..setLineDashPattern(dash ?? const [])
      ..moveTo(_x(x1), _y(y1))
      ..lineTo(_x(x2), _y(y2))
      ..strokePath()
      ..setLineDashPattern(const []);
  }

  void rect(double x, double y, double w, double h, {PdfColor? fill, PdfColor? stroke, double strokeWidth = 0.6}) {
    if (w <= 0 || h <= 0) return;
    if (fill != null) {
      g
        ..setFillColor(fill)
        ..drawRect(_x(x), _y(y + h), w, h)
        ..fillPath();
    }
    if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(strokeWidth)
        ..drawRect(_x(x), _y(y + h), w, h)
        ..strokePath();
    }
  }

  void polyline(List<(double, double)> points, PdfColor color, {double width = 1}) {
    if (points.length < 2) return;
    g
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..setLineJoin(PdfLineJoin.round)
      ..moveTo(_x(points.first.$1), _y(points.first.$2));
    for (final p in points.skip(1)) {
      g.lineTo(_x(p.$1), _y(p.$2));
    }
    g.strokePath();
  }

  void triangle(double cx, double top, double size, PdfColor color) {
    g
      ..setFillColor(color)
      ..moveTo(_x(cx), _y(top))
      ..lineTo(_x(cx - size), _y(top + size * 1.6))
      ..lineTo(_x(cx + size), _y(top + size * 1.6))
      ..closePath()
      ..fillPath();
  }

  void opacity(double o) => g.setGraphicState(PdfGraphicState(opacity: o));

  void fillPolygon(List<(double, double)> points, PdfColor color) {
    g
      ..setFillColor(color)
      ..moveTo(_x(points.first.$1), _y(points.first.$2));
    for (final p in points.skip(1)) {
      g.lineTo(_x(p.$1), _y(p.$2));
    }
    g
      ..closePath()
      ..fillPath();
  }

  void fillCircle(double cx, double cy, double r, PdfColor color) {
    g
      ..setFillColor(color)
      ..drawEllipse(_x(cx), _y(cy), r, r)
      ..fillPath();
  }

  double textWidth(String s, double size, {bool bold = false}) =>
      (bold ? _fontBold : _font).stringMetrics(s).advanceWidth * size;

  /// Texto con ancla horizontal según [align] ('l', 'c', 'r') y [cy] como
  /// centro vertical aproximado.
  void text(String s, double x, double cy,
      {double size = 7, bool bold = false, PdfColor color = pdfText, String align = 'l', double? maxWidth}) {
    var str = s;
    if (maxWidth != null) {
      while (str.length > 1 && textWidth(str, size, bold: bold) > maxWidth) {
        str = str.substring(0, str.length - 1);
      }
      if (str != s) str = '${str.substring(0, math.max(1, str.length - 2))}...';
    }
    final w = textWidth(str, size, bold: bold);
    final dx = align == 'c' ? -w / 2 : (align == 'r' ? -w : 0.0);
    g
      ..setFillColor(color)
      ..drawString(bold ? _fontBold : _font, size, str, _x(x + dx), _y(cy + size * 0.35));
  }
}

/// Widget de tamaño fijo que dibuja con un [PdfChartCanvas].
class PdfChart extends pw.Widget {
  PdfChart(this.chartWidth, this.chartHeight, this.painter);

  final double chartWidth, chartHeight;
  final void Function(PdfChartCanvas c) painter;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    box = PdfRect(0, 0, chartWidth, chartHeight);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    context.canvas.saveContext();
    painter(PdfChartCanvas(context, box!.left, box!.bottom, box!.width, box!.height));
    context.canvas.restoreContext();
  }
}

String _signed(int v) => v > 0 ? '+$v' : '$v';
String _signedPct(double v) {
  final p = (v * 100).round();
  return p > 0 ? '+$p%' : '$p%';
}

int _niceStep(num span) {
  if (span <= 4) return 1;
  final raw = span / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toInt();
  for (final m in [1, 2, 3, 5, 10]) {
    if (m * mag >= raw) return m * mag;
  }
  return 10 * mag;
}

/// Barras divergentes (G-P por rotación).
pw.Widget pdfDivergingBars(double w, double h, List<String> labels, List<int> values) {
  return PdfChart(w, h, (c) {
    if (values.isEmpty) return;
    const left = 22.0, right = 4.0, top = 12.0, bottom = 14.0;
    final minV = math.min(0, values.reduce(math.min));
    final maxV = math.max(0, values.reduce(math.max));
    final step = _niceStep(math.max(1, maxV - minV));
    // Un punto de margen arriba y abajo (ver DivergingBarChart).
    final lo = ((minV < 0 ? minV - 1 : 0) / step).floor() * step.toDouble();
    final hi = (math.max(maxV > 0 ? maxV + 1 : 0, lo + step) / step).ceil() * step.toDouble();
    final ph = h - top - bottom, plotW = w - left - right;
    double y(num v) => top + (hi - v) / (hi - lo) * ph;
    for (var v = lo; v <= hi + 0.001; v += step) {
      c.line(left, y(v), w - right, y(v), v == 0 ? pdfZero : pdfGrid, width: v == 0 ? 0.9 : 0.5);
      c.text('${v.round()}', left - 3, y(v), size: 6.5, color: pdfMuted, align: 'r');
    }
    final slot = plotW / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final v = values[i];
      final cx = left + slot * (i + 0.5);
      final bw = math.min(slot * 0.6, 40.0);
      final color = v >= 0 ? pdfPositive : pdfNegative;
      if (v != 0) c.rect(cx - bw / 2, math.min(y(0), y(v)), bw, (y(v) - y(0)).abs(), fill: color);
      c.text(_signed(v), cx, v >= 0 ? y(v) - 5 : y(v) + 5,
          size: 7.5, bold: true, color: v == 0 ? pdfMuted : color, align: 'c');
      c.text(labels[i], cx, h - 6, size: 7.5, bold: true, align: 'c');
    }
  });
}

/// Pares de barras de porcentaje (side-out / break-point por rotación).
pw.Widget pdfGroupedPctBars(double w, double h, List<String> labels, List<double?> a, List<double?> b) {
  return PdfChart(w, h, (c) {
    const left = 26.0, right = 4.0, top = 10.0, bottom = 14.0;
    final ph = h - top - bottom, plotW = w - left - right;
    double y(double v) => top + (1 - v) * ph;
    for (var v = 0.0; v <= 1.001; v += 0.25) {
      c.line(left, y(v), w - right, y(v), pdfGrid, width: 0.5);
      c.text('${(v * 100).round()}%', left - 3, y(v), size: 6.3, color: pdfMuted, align: 'r');
    }
    c.line(left, y(0.5), w - right, y(0.5), pdfZero, width: 0.6, dash: [2, 2]);
    final slot = plotW / labels.length;
    void bar(double? v, double x, double bw, PdfColor color) {
      if (v == null) {
        c.text('-', x + bw / 2, y(0) - 5, size: 6.5, color: pdfMuted, align: 'c');
        return;
      }
      c.rect(x, y(v), bw, y(0) - y(v), fill: color);
      c.text('${(v * 100).round()}', x + bw / 2, y(v) - 4, size: 6.3, bold: true, color: color, align: 'c');
    }

    for (var i = 0; i < labels.length; i++) {
      final cx = left + slot * (i + 0.5);
      final bw = math.min(slot * 0.3, 18.0);
      bar(a[i], cx - bw - 1, bw, pdfNavy);
      bar(b[i], cx + 1, bw, pdfCyan);
      c.text(labels[i], cx, h - 6, size: 7.5, bold: true, align: 'c');
    }
  });
}

/// Evolución del marcador de un set.
pw.Widget pdfTimeline(double w, double h, SetTimeline t) {
  return PdfChart(w, h, (c) {
    final points = t.points;
    if (points.isEmpty) return;
    const left = 20.0, right = 6.0, top = 12.0, bottom = 13.0;
    // Dos puntos de margen arriba y abajo: ahí van las etiquetas de las rachas.
    final maxAbs = points.map((p) => p.diff.abs()).reduce(math.max) + 2;
    final ph = h - top - bottom, plotW = w - left - right;
    double y(num v) => top + (maxAbs - v) / (2 * maxAbs) * ph;
    final step = plotW / points.length;
    final gridStep = maxAbs > 8 ? 4 : 2;
    for (var v = -maxAbs; v <= maxAbs; v++) {
      if (v % gridStep != 0) continue;
      c.line(left, y(v), w - right, y(v), v == 0 ? pdfZero : pdfGrid, width: v == 0 ? 0.9 : 0.4);
      c.text(_signed(v), left - 3, y(v), size: 6, color: pdfMuted, align: 'r');
    }
    for (var i = 0; i < points.length; i++) {
      final d = points[i].diff;
      if (d == 0) continue;
      c.opacity(0.3);
      c.rect(left + i * step + step * 0.12, math.min(y(0), y(d)), step * 0.76, (y(d) - y(0)).abs(),
          fill: d > 0 ? pdfPositive : pdfNegative);
      c.opacity(1);
    }
    c.polyline([
      (left, y(0)),
      for (var i = 0; i < points.length; i++) (left + (i + 1) * step, y(points[i].diff)),
    ], pdfNavy, width: 1.1);
    for (final run in t.runs()) {
      final own = run.team == TeamSide.own;
      final color = own ? pdfPositive : pdfNegative;
      final x0 = left + run.start * step, x1 = left + run.end * step;
      final endY = y(points[run.end - 1].diff);
      final ly = own ? endY - 8 : endY + 8;
      c.line(x0 + 1, own ? ly + 4 : ly - 4, x1 - 1, own ? ly + 4 : ly - 4, color, width: 0.7);
      c.text(own ? 'Racha ${run.length}-0' : 'Racha 0-${run.length}', (x0 + x1) / 2, ly,
          size: 6.3, bold: true, color: color, align: 'c');
    }
    for (final m in t.substitutionMarks) {
      c.triangle(left + m * step, h - bottom + 0.5, 2.2, pdfMuted);
    }
    final tickEvery = points.length > 40 ? 10 : 5;
    for (var k = tickEvery; k <= points.length; k += tickEvery) {
      c.text('$k', left + k * step, h - 4, size: 6, color: pdfMuted, align: 'c');
    }
  });
}

class PdfSegment {
  const PdfSegment(this.label, this.value, this.color);
  final String label;
  final int value;
  final PdfColor color;
}

/// Barra horizontal apilada.
pw.Widget pdfStackedBar(double w, double h, List<PdfSegment> segments, {bool showPercent = false}) {
  final sum = segments.fold<int>(0, (a, s) => a + s.value);
  return PdfChart(w, h, (c) {
    if (sum == 0) return;
    var x = 0.0;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sw = w * s.value / sum;
      c.rect(x, 0, math.max(0.5, sw - 0.8), h, fill: s.color);
      final label = showPercent ? '${(s.value / sum * 100).round()}%' : '${s.value}';
      if (c.textWidth(label, 7, bold: true) + 3 < sw) {
        c.text(label, x + sw / 2, h / 2, size: 7, bold: true, color: PdfColors.white, align: 'c');
      }
      x += sw;
    }
  });
}

pw.Widget pdfLegend(List<(String, PdfColor)> items) => pw.Wrap(
      spacing: 9,
      runSpacing: 3,
      children: [
        for (final (label, color) in items)
          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
            pw.Container(width: 7, height: 7, color: color),
            pw.SizedBox(width: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: pdfText)),
          ]),
      ],
    );

class PdfEfficiencyRow {
  const PdfEfficiencyRow(this.label, this.efficiency, this.detail);
  final String label;
  final double efficiency;
  final String detail;
}

/// Eficiencia de ataque por jugador (barras horizontales desde 0 %).
pw.Widget pdfEfficiencyBars(double w, List<PdfEfficiencyRow> rows) {
  const rowH = 15.0;
  final h = rows.length * rowH + 12;
  return PdfChart(w, h, (c) {
    if (rows.isEmpty) return;
    const labelW = 110.0, detailW = 105.0;
    const left = labelW + 6;
    final right = w - detailW - 4;
    final lo = math.min(-0.4, (rows.map((r) => r.efficiency).reduce(math.min) * 5).floor() / 5);
    final hi = math.max(0.8, (rows.map((r) => r.efficiency).reduce(math.max) * 5).ceil() / 5);
    double x(double v) => left + (v - lo) / (hi - lo) * (right - left);
    final plotH = rows.length * rowH;
    for (var v = lo; v <= hi + 0.001; v += 0.2) {
      final zero = v.abs() < 0.001;
      c.line(x(v), 0, x(v), plotH, zero ? pdfZero : pdfGrid, width: zero ? 0.9 : 0.4);
      c.text('${(v * 100).round()}%', x(v), plotH + 6, size: 6, color: pdfMuted, align: 'c');
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final cy = i * rowH + rowH / 2;
      c.text(r.label, labelW, cy, size: 7.5, bold: true, align: 'r', maxWidth: labelW);
      final e = r.efficiency;
      final color = e >= 0 ? pdfPositive : pdfNegative;
      c.rect(math.min(x(0), x(e)), cy - 5, (x(e) - x(0)).abs(), 10, fill: color);
      c.text(_signedPct(e), e >= 0 ? x(e) + 3 : x(e) - 3, cy,
          size: 7, bold: true, color: color, align: e >= 0 ? 'l' : 'r');
      c.text(r.detail, w, cy, size: 6.5, color: pdfMuted, align: 'r');
    }
  });
}

/// Mitad rival con cada zona pintada según la cantidad de toques.
pw.Widget pdfZoneHeatmap(double w, Map<int, TouchStats> byZone, {required bool nineZones}) {
  final rows = nineZones
      ? const [
          [1, 6, 5],
          [9, 8, 7],
          [2, 3, 4],
        ]
      : const [
          [1, 6, 5],
          [2, 3, 4],
        ];
  final courtH = w * (nineZones ? 1.0 : 0.82);
  return PdfChart(w, courtH + 6, (c) {
    final rowHeights = nineZones ? [courtH / 3, courtH / 3, courtH / 3] : [courtH * 2 / 3, courtH / 3];
    final cellW = w / 3;
    final maxCount = math.max(1, byZone.values.map((s) => s.total).fold(0, math.max));
    var top = 0.0;
    for (var r = 0; r < rows.length; r++) {
      for (var col = 0; col < 3; col++) {
        final zone = rows[r][col];
        final s = byZone[zone] ?? TouchStats();
        final intensity = s.total / maxCount;
        final x0 = col * cellW;
        c.rect(x0, top, cellW, rowHeights[r], fill: pdfCourt);
        if (s.total > 0) {
          c.opacity(0.12 + 0.78 * intensity);
          c.rect(x0, top, cellW, rowHeights[r], fill: pdfPositive);
          c.opacity(1);
        }
        c.rect(x0, top, cellW, rowHeights[r], stroke: pdfNeutral, strokeWidth: 0.5);
        final fg = intensity > 0.55 ? PdfColors.white : pdfText;
        final cx = x0 + cellW / 2, cy = top + rowHeights[r] / 2;
        c.text('Z$zone', cx, cy - 11, size: 6.5, color: fg, align: 'c');
        c.text('${s.total}', cx, cy, size: 12, bold: true, color: fg, align: 'c');
        if (s.total > 0) {
          c.text('${(s.pp / s.total * 100).round()}% pto', cx, cy + 10, size: 6, color: fg, align: 'c');
        }
      }
      top += rowHeights[r];
    }
    c.line(-2, courtH + 2, w + 2, courtH + 2, pdfNavy, width: 2);
  });
}

// ---------------- Mapas de dirección (planilla por jugador) ----------------

PdfColor _shotColor(ShotResult r) {
  switch (r) {
    case ShotResult.point:
      return pdfPositive;
    case ShotResult.inPlay:
      return pdfSlate;
    case ShotResult.blocked:
      return pdfBlock;
    case ShotResult.out:
    case ShotResult.net:
    case ShotResult.error:
      return pdfNegative;
  }
}

/// Un toque con el trazo de su resultado (mismo criterio que
/// `paintShotStroke` en `lib/widgets/charts/court_shots_chart.dart`).
void pdfShotStroke(PdfChartCanvas c, double x1, double y1, double x2, double y2, ShotResult result, {double k = 1}) {
  final color = _shotColor(result);
  final dx = x2 - x1, dy = y2 - y1;
  final len = math.max(0.001, math.sqrt(dx * dx + dy * dy));
  final ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
  final head = 4.0 * k;
  final ex = x2 - ux * head * 0.8, ey = y2 - uy * head * 0.8;
  void arrow() {
    final bx = x2 - ux * head, by = y2 - uy * head;
    c.fillPolygon([
      (x2, y2),
      (bx + nx * head * 0.45, by + ny * head * 0.45),
      (bx - nx * head * 0.45, by - ny * head * 0.45),
    ], color);
  }

  switch (result) {
    case ShotResult.point:
      c.line(x1, y1, ex, ey, color, width: 1.1 * k);
      arrow();
      break;
    case ShotResult.inPlay:
      c.line(x1, y1, ex, ey, color, width: 0.8 * k, dash: [2.6 * k, 1.8 * k]);
      arrow();
      break;
    case ShotResult.error:
      c.line(x1, y1, ex, ey, color, width: 0.8 * k, dash: [1.8 * k, 1.4 * k]);
      arrow();
      break;
    case ShotResult.out:
      final o = 1.0 * k;
      c.line(x1 + nx * o, y1 + ny * o, ex + nx * o, ey + ny * o, color, width: 0.55 * k, dash: [2.2 * k, 1.4 * k]);
      c.line(x1 - nx * o, y1 - ny * o, ex - nx * o, ey - ny * o, color, width: 0.55 * k, dash: [2.2 * k, 1.4 * k]);
      arrow();
      break;
    case ShotResult.blocked:
      c.line(x1, y1, x2, y2, color, width: 1.1 * k);
      final b = 3.2 * k;
      c.line(x2 + nx * b, y2 + ny * b, x2 - nx * b, y2 - ny * b, color, width: 1.4 * k);
      break;
    case ShotResult.net:
      c.line(x1, y1, x2, y2, color, width: 0.7 * k, dash: [1.1 * k, 1.2 * k]);
      final s = 2.3 * k;
      c.line(x2 - s, y2 - s, x2 + s, y2 + s, color, width: 1.1 * k);
      c.line(x2 - s, y2 + s, x2 + s, y2 - s, color, width: 1.1 * k);
      break;
  }
  c.fillCircle(x1, y1, 1.1 * k, pdfMuted);
}

/// Cancha compacta con las flechas de [shots] (ver `CourtGeometry`).
pw.Widget pdfCourtShots(double width, List<CourtShot> shots) {
  final geo = CourtGeometry(width);
  return PdfChart(width, geo.height, (c) {
    c.rect(0, 0, width, geo.height, fill: PdfColors.white, stroke: pdfGrid, strokeWidth: 0.6);
    final left = geo.px(0), right = geo.px(1);
    c.rect(left, geo.py(0), right - left, geo.py(0.5) - geo.py(0), fill: pdfCourt);
    c.rect(left, geo.py(0.5), right - left, geo.py(1) - geo.py(0.5), fill: const PdfColor.fromInt(0xFFF1F2F4));
    c.rect(left, geo.py(0), right - left, geo.py(1) - geo.py(0), stroke: pdfNeutral, strokeWidth: 0.7);
    c.line(left, geo.py(1 / 3), right, geo.py(1 / 3), pdfNeutral, width: 0.4);
    c.line(left, geo.py(2 / 3), right, geo.py(2 / 3), pdfNeutral, width: 0.4);
    for (final x in [1 / 3, 2 / 3]) {
      c.line(geo.px(x), geo.py(0), geo.px(x), geo.py(0.5), pdfNeutral, width: 0.3, dash: [1, 2]);
    }
    const rows = [
      [1, 6, 5],
      [2, 3, 4],
    ];
    for (var r = 0; r < 2; r++) {
      for (var col = 0; col < 3; col++) {
        c.text('${rows[r][col]}', geo.px((col + 0.5) / 3), geo.py(r == 0 ? 1 / 6 : 5 / 12),
            size: 7, bold: true, color: const PdfColor.fromInt(0xFFB9C7D6), align: 'c');
      }
    }
    c.line(geo.px(-0.05), geo.py(0.5), geo.px(1.05), geo.py(0.5), pdfNavy, width: 1.8);
    for (final s in shots) {
      pdfShotStroke(c, geo.px(s.originX), geo.py(s.originY), geo.px(s.targetX), geo.py(s.targetY), s.result,
          k: width < 130 ? 0.85 : 1);
    }
  });
}

/// Muestra de un trazo para la leyenda.
pw.Widget pdfShotLegend(List<ShotResult> results) => pw.Wrap(
      spacing: 12,
      runSpacing: 3,
      children: [
        for (final r in results)
          pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
            PdfChart(28, 9, (c) {
              final end = r == ShotResult.blocked || r == ShotResult.net ? 24.0 : 27.0;
              pdfShotStroke(c, 2, 4.5, end, 4.5, r);
            }),
            pw.SizedBox(width: 3),
            pw.Text(r.label, style: const pw.TextStyle(fontSize: 7, color: pdfText)),
          ]),
      ],
    );
