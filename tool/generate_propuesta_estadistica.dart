// Genera documents/RallyStats-Propuesta-Estadistica-Visual.pdf: el boceto (con datos de
// ejemplo, no reales) de la sección "Mapas" + "Gráficos" de Estadísticas. La spec
// implementable que acompaña a este PDF es documents/spec-estadistica-visual.md.
//
//   dart run tool/generate_propuesta_estadistica.dart [salida.pdf]
//
// Además de generar el documento, sirve como referencia de dibujo para implementar
// la funcionalidad real: drawShot() (los 5 trazos), CourtMap (cancha compacta),
// divergingBars / groupedPctBars / wormChart / stackedBar son la misma geometría que
// hay que reproducir en CustomPainter (pantalla) y en pdf_report_service.dart (PDF).
//
// Toma las fuentes Arial de C:WindowsFonts (solo corre en Windows), porque las
// fuentes por defecto de package:pdf no tienen algunos símbolos usados acá (→, ▼, ►).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------------------
// Paleta (AppColors de lib/utils/theme.dart + colores de calificación de grade_labels.dart)
// ---------------------------------------------------------------------------
const cNavy = PdfColor.fromInt(0xFF1E2A38);
const cNavyDeep = PdfColor.fromInt(0xFF121821);
const cCyan = PdfColor.fromInt(0xFF3DC2EC);
const cText = PdfColor.fromInt(0xFF1B1F24);
const cGrey = PdfColor.fromInt(0xFF6B7280);
const cGreyLight = PdfColor.fromInt(0xFF9CA3AF);
const cBorder = PdfColor.fromInt(0xFFE5E7EB);
const cSurfaceAlt = PdfColor.fromInt(0xFFEEF1F4);
const cBg = PdfColor.fromInt(0xFFF5F6F8);
const cPP = PdfColor.fromInt(0xFF1E88E5);
const cP = PdfColor.fromInt(0xFF64B5F6);
const cExcl = PdfColor.fromInt(0xFF9CCC65);
const cN = PdfColor.fromInt(0xFFFFB74D);
const cVneg = PdfColor.fromInt(0xFFFF8A65);
const cNN = PdfColor.fromInt(0xFFE64A3B);
const cInPlay = PdfColor.fromInt(0xFF475569);
const cBlock = PdfColor.fromInt(0xFFE39A12);
const cSuccess = PdfColor.fromInt(0xFF2ECC71);
const cRivalHalf = PdfColor.fromInt(0xFFE8F1FA);
const cOwnHalf = PdfColor.fromInt(0xFFF1F2F4);
const cWhite = PdfColors.white;

late pw.Font fReg;
late pw.Font fBold;

pw.Font _ttf(String path) => pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

// ---------------------------------------------------------------------------
// Lienzo: widget de tamaño fijo con coordenadas "y hacia abajo" desde arriba-izquierda.
// ---------------------------------------------------------------------------
class Cv {
  Cv(this.ctx, this.ox, this.oy, this.w, this.h);
  final pw.Context ctx;
  final double ox, oy, w, h;
  PdfGraphics get g => ctx.canvas;
  double sx(double x) => ox + x;
  double sy(double y) => oy + h - y;

  void line(double x1, double y1, double x2, double y2, PdfColor c,
      {double width = 1, List<num>? dash, bool round = false}) {
    g
      ..setStrokeColor(c)
      ..setLineWidth(width)
      ..setLineCap(round ? PdfLineCap.round : PdfLineCap.butt)
      ..setLineDashPattern(dash ?? const [])
      ..moveTo(sx(x1), sy(y1))
      ..lineTo(sx(x2), sy(y2))
      ..strokePath()
      ..setLineDashPattern(const []);
  }

  void rect(double x, double y, double rw, double rh,
      {PdfColor? fill, PdfColor? stroke, double sw = 1, double r = 0, List<num>? dash}) {
    void path() {
      if (r > 0) {
        g.drawRRect(sx(x), sy(y + rh), rw, rh, r, r);
      } else {
        g.drawRect(sx(x), sy(y + rh), rw, rh);
      }
    }

    if (fill != null) {
      g.setFillColor(fill);
      path();
      g.fillPath();
    }
    if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(sw)
        ..setLineDashPattern(dash ?? const []);
      path();
      g.strokePath();
      g.setLineDashPattern(const []);
    }
  }

  void circle(double cx, double cy, double r, {PdfColor? fill, PdfColor? stroke, double sw = 1}) {
    if (fill != null) {
      g.setFillColor(fill);
      g.drawEllipse(sx(cx), sy(cy), r, r);
      g.fillPath();
    }
    if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(sw)
        ..setLineDashPattern(const []);
      g.drawEllipse(sx(cx), sy(cy), r, r);
      g.strokePath();
    }
  }

  void poly(List<List<double>> pts, PdfColor fill) {
    g.setFillColor(fill);
    g.moveTo(sx(pts[0][0]), sy(pts[0][1]));
    for (final p in pts.skip(1)) {
      g.lineTo(sx(p[0]), sy(p[1]));
    }
    g.closePath();
    g.fillPath();
  }

  double tw(String s, double size, {bool bold = false}) =>
      (bold ? fBold : fReg).getFont(ctx).stringMetrics(s).advanceWidth * size;

  void text(String s, double x, double y,
      {double size = 8, bool bold = false, PdfColor? color, String align = 'l'}) {
    final f = (bold ? fBold : fReg).getFont(ctx);
    final width = f.stringMetrics(s).advanceWidth * size;
    final dx = align == 'c'
        ? -width / 2
        : align == 'r'
            ? -width
            : 0.0;
    g.setFillColor(color ?? cText);
    g.drawString(f, size, s, sx(x + dx), sy(y));
  }

  void opacity(double o) => g.setGraphicState(PdfGraphicState(opacity: o));
}

class Draw extends pw.Widget {
  Draw(this.width, this.height, this.painter);
  final double width, height;
  final void Function(Cv cv) painter;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    box = PdfRect(0, 0, width, height);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    context.canvas.saveContext();
    painter(Cv(context, box!.left, box!.bottom, box!.width, box!.height));
    context.canvas.restoreContext();
  }
}

// ---------------------------------------------------------------------------
// Modelo de ejemplo: tiros con origen/destino en coordenadas de cancha.
// x: 0..1 (ancho, 9 m, vista desde el banco propio); y: 0 = fondo rival,
// 0.5 = red, 1 = fondo propio. Valores fuera de 0..1 = fuera de la cancha.
// ---------------------------------------------------------------------------
enum Res { point, inPlay, out, blocked, net }

class Shot {
  Shot(this.ox, this.oy, this.tx, this.ty, this.res);
  final double ox, oy, tx, ty;
  final Res res;
}

class ShotSummary {
  ShotSummary(List<Shot> s)
      : total = s.length,
        pts = s.where((e) => e.res == Res.point).length,
        inPlay = s.where((e) => e.res == Res.inPlay).length,
        out = s.where((e) => e.res == Res.out).length,
        blocked = s.where((e) => e.res == Res.blocked).length,
        net = s.where((e) => e.res == Res.net).length;
  final int total, pts, inPlay, out, blocked, net;
  int get errors => out + blocked + net;
  double get eff => total == 0 ? 0 : (pts - errors) / total;
  String get effLabel => '${eff >= 0 ? '+' : ''}${(eff * 100).round()}%';
}

const zOrig = {
  4: [0.13, 0.60],
  3: [0.50, 0.59],
  2: [0.87, 0.60],
  5: [0.15, 0.76],
  6: [0.50, 0.77],
  1: [0.85, 0.76],
};
const serveR = [0.82, 1.06];
const serveC = [0.50, 1.06];
const serveL = [0.20, 1.06];

List<Shot> gen(
  int seed, {
  required int n,
  required List<List<double>> origins,
  required List<List<double>> targets,
  required List<double> probs, // point, inPlay, out, blocked, net
}) {
  final r = math.Random(seed);
  final out = <Shot>[];
  double j(double s) => (r.nextDouble() - 0.5) * s;
  for (var i = 0; i < n; i++) {
    final o = origins[r.nextInt(origins.length)];
    final ox = o[0] + j(0.05), oy = o[1] + j(0.02);
    final t = targets[r.nextInt(targets.length)];
    var tx = t[0] + j(0.16), ty = t[1] + j(0.12);
    final roll = r.nextDouble();
    var acc = 0.0;
    var res = Res.point;
    for (var k = 0; k < probs.length; k++) {
      acc += probs[k];
      if (roll <= acc) {
        res = Res.values[k];
        break;
      }
    }
    switch (res) {
      case Res.point:
      case Res.inPlay:
        tx = tx.clamp(0.05, 0.95);
        ty = ty.clamp(0.04, 0.46);
        break;
      case Res.out:
        if (ty < 0.22) {
          ty = -0.02 - r.nextDouble() * 0.05;
          tx = tx.clamp(0.05, 0.95);
        } else {
          tx = tx < 0.5 ? -0.04 - r.nextDouble() * 0.06 : 1.04 + r.nextDouble() * 0.06;
          ty = ty.clamp(0.08, 0.45);
        }
        break;
      case Res.blocked:
        tx = ox + (tx - ox) * 0.08 + j(0.05);
        ty = 0.52;
        break;
      case Res.net:
        tx = ox + (tx - ox) * 0.15 + j(0.08);
        ty = 0.503;
        break;
    }
    out.add(Shot(ox, oy, tx, ty, res));
  }
  return out;
}

class PlayerSample {
  PlayerSample(this.tag, this.number, this.role, this.serve, this.attack, this.counter);
  final String tag; // OP, PR, C, A
  final int number;
  final String role;
  final List<Shot> serve, attack, counter;
  String get label => '$tag #$number';
}

final players = <PlayerSample>[
  PlayerSample(
    'OP', 16, 'Opuesto',
    gen(11, n: 13, origins: [serveR], targets: [[0.18, 0.12], [0.5, 0.1], [0.2, 0.38]], probs: [0.2, 0.55, 0.2, 0, 0.05]),
    gen(12, n: 17, origins: [zOrig[2]!, zOrig[2]!, zOrig[1]!], targets: [[0.8, 0.12], [0.2, 0.22], [0.75, 0.38]], probs: [0.52, 0.28, 0.1, 0.07, 0.03]),
    gen(13, n: 10, origins: [zOrig[2]!, zOrig[1]!], targets: [[0.82, 0.15], [0.3, 0.12]], probs: [0.45, 0.35, 0.1, 0.1, 0]),
  ),
  PlayerSample(
    'PR', 9, 'Punta receptor',
    gen(21, n: 11, origins: [serveC, serveR], targets: [[0.8, 0.12], [0.5, 0.35]], probs: [0.1, 0.7, 0.1, 0, 0.1]),
    gen(22, n: 15, origins: [zOrig[4]!, zOrig[4]!, zOrig[6]!], targets: [[0.18, 0.15], [0.85, 0.2], [0.45, 0.3]], probs: [0.4, 0.33, 0.13, 0.07, 0.07]),
    gen(23, n: 8, origins: [zOrig[4]!, zOrig[6]!], targets: [[0.2, 0.1], [0.8, 0.25]], probs: [0.38, 0.37, 0.25, 0, 0]),
  ),
  PlayerSample(
    'PR', 5, 'Punta receptor',
    gen(31, n: 12, origins: [serveL, serveC], targets: [[0.18, 0.1], [0.82, 0.1]], probs: [0.25, 0.55, 0.15, 0, 0.05]),
    gen(32, n: 12, origins: [zOrig[4]!, zOrig[6]!], targets: [[0.2, 0.2], [0.7, 0.3]], probs: [0.33, 0.42, 0.08, 0.17, 0]),
    gen(33, n: 7, origins: [zOrig[4]!], targets: [[0.25, 0.15], [0.6, 0.12]], probs: [0.3, 0.55, 0.15, 0, 0]),
  ),
  PlayerSample(
    'C', 10, 'Central',
    gen(41, n: 10, origins: [serveR, serveC], targets: [[0.5, 0.4], [0.15, 0.3]], probs: [0.1, 0.75, 0.1, 0, 0.05]),
    gen(42, n: 11, origins: [zOrig[3]!], targets: [[0.5, 0.2], [0.15, 0.3], [0.85, 0.35]], probs: [0.55, 0.25, 0.1, 0.1, 0]),
    gen(43, n: 4, origins: [zOrig[3]!], targets: [[0.5, 0.25]], probs: [0.5, 0.5, 0, 0, 0]),
  ),
  PlayerSample(
    'C', 15, 'Central',
    gen(51, n: 9, origins: [serveL, serveC], targets: [[0.82, 0.15], [0.5, 0.2]], probs: [0.22, 0.56, 0.22, 0, 0]),
    gen(52, n: 9, origins: [zOrig[3]!], targets: [[0.3, 0.3], [0.7, 0.2]], probs: [0.45, 0.35, 0, 0.2, 0]),
    gen(53, n: 3, origins: [zOrig[3]!], targets: [[0.5, 0.2]], probs: [0.34, 0.66, 0, 0, 0]),
  ),
  PlayerSample(
    'A', 1, 'Armador',
    gen(61, n: 11, origins: [serveR], targets: [[0.5, 0.08], [0.2, 0.12]], probs: [0.1, 0.8, 0.1, 0, 0]),
    gen(62, n: 3, origins: [zOrig[2]!], targets: [[0.75, 0.42], [0.55, 0.42]], probs: [0.67, 0.33, 0, 0, 0]),
    gen(63, n: 2, origins: [zOrig[2]!], targets: [[0.3, 0.43]], probs: [0.5, 0.5, 0, 0, 0]),
  ),
];

// ---------------------------------------------------------------------------
// Cancha compacta: mitad rival a escala real (9x9 m = cuadrado), mitad propia
// comprimida al 50 % (solo interesa el punto de origen).
// ---------------------------------------------------------------------------
const _mx = 0.12, _mt = 0.17, _mb = 0.15;
double courtHeightFor(double width) => width / (1 + 2 * _mx) * (1.5 + _mt + _mb);

class CourtMap {
  CourtMap(this.bx, this.by, double width) : cw = width / (1 + 2 * _mx);
  final double bx, by, cw;
  double px(double x) => bx + _mx * cw + x * cw;
  double py(double y) {
    final top = by + _mt * cw;
    if (y <= 0.5) return top + (y / 0.5) * cw;
    return top + cw + ((y - 0.5) / 0.5) * 0.5 * cw;
  }
}

void drawCourt(Cv cv, CourtMap m, {bool zoneLabels = true, bool ownHalf = true, Map<int, double>? heat}) {
  final full = cv.w;
  // área de "afuera"
  cv.rect(m.bx, m.by, full, ownHalf ? courtHeightFor(full) : (m.cw * (1 + _mt) + 8),
      fill: cWhite, stroke: cBorder, sw: 0.6, r: 4);
  // mitad rival
  cv.rect(m.px(0), m.py(0), m.cw, m.py(0.5) - m.py(0), fill: cRivalHalf);
  if (heat != null) {
    const cells = {1: [0, 0], 6: [1, 0], 5: [2, 0], 2: [0, 1], 3: [1, 1], 4: [2, 1]};
    heat.forEach((z, v) {
      final c = cells[z]!;
      final x0 = m.px(c[0] / 3), x1 = m.px((c[0] + 1) / 3);
      final y0 = m.py(c[1] == 0 ? 0 : 1 / 3), y1 = m.py(c[1] == 0 ? 1 / 3 : 0.5);
      cv.opacity(0.12 + 0.78 * v);
      cv.rect(x0, y0, x1 - x0, y1 - y0, fill: cPP);
      cv.opacity(1);
    });
  }
  if (ownHalf) cv.rect(m.px(0), m.py(0.5), m.cw, m.py(1) - m.py(0.5), fill: cOwnHalf);
  const lc = cGreyLight;
  cv.rect(m.px(0), m.py(0), m.cw, (ownHalf ? m.py(1) : m.py(0.5)) - m.py(0), stroke: lc, sw: 0.8);
  cv.line(m.px(0), m.py(1 / 3), m.px(1), m.py(1 / 3), lc, width: 0.5);
  if (ownHalf) cv.line(m.px(0), m.py(2 / 3), m.px(1), m.py(2 / 3), lc, width: 0.5);
  if (zoneLabels) {
    cv.line(m.px(1 / 3), m.py(0), m.px(1 / 3), m.py(0.5), lc, width: 0.3, dash: [1, 2]);
    cv.line(m.px(2 / 3), m.py(0), m.px(2 / 3), m.py(0.5), lc, width: 0.3, dash: [1, 2]);
    final sz = m.cw > 150 ? 11.0 : 7.0;
    final col = heat != null ? cNavy : const PdfColor.fromInt(0xFFB9C7D6);
    const rows = [
      [1, 6, 5],
      [2, 3, 4]
    ];
    for (var ri = 0; ri < 2; ri++) {
      for (var ci = 0; ci < 3; ci++) {
        final cx = m.px((ci + 0.5) / 3);
        final cy = ri == 0 ? m.py(1 / 6) : m.py(5 / 12);
        if (heat == null) cv.text('${rows[ri][ci]}', cx, cy + sz * 0.35, size: sz, bold: true, color: col, align: 'c');
      }
    }
  }
  // red
  cv.line(m.px(-0.05), m.py(0.5), m.px(1.05), m.py(0.5), cNavy, width: 2);
}

void arrowHead(Cv cv, double x1, double y1, double x2, double y2, PdfColor c, double s) {
  final dx = x2 - x1, dy = y2 - y1;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 0.01) return;
  final ux = dx / len, uy = dy / len;
  final bx = x2 - ux * s, by = y2 - uy * s;
  final nx = -uy, ny = ux;
  cv.poly([
    [x2, y2],
    [bx + nx * s * 0.42, by + ny * s * 0.42],
    [bx - nx * s * 0.42, by - ny * s * 0.42],
  ], c);
}

/// Dibuja un tiro con el trazo que corresponde a su resultado.
void drawShot(Cv cv, double x1, double y1, double x2, double y2, Res res, {double k = 1}) {
  final dx = x2 - x1, dy = y2 - y1;
  final len = math.max(0.001, math.sqrt(dx * dx + dy * dy));
  final ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
  final hs = 4.2 * k; // tamaño punta
  final ex = x2 - ux * hs * 0.8, ey = y2 - uy * hs * 0.8; // fin de la línea antes de la punta
  switch (res) {
    case Res.point:
      cv.line(x1, y1, ex, ey, cPP, width: 1.25 * k);
      arrowHead(cv, x1, y1, x2, y2, cPP, hs);
      break;
    case Res.inPlay:
      cv.line(x1, y1, ex, ey, cInPlay, width: 0.9 * k, dash: [3 * k, 2 * k]);
      arrowHead(cv, x1, y1, x2, y2, cInPlay, hs);
      break;
    case Res.out:
      final o = 1.15 * k;
      cv.line(x1 + nx * o, y1 + ny * o, ex + nx * o, ey + ny * o, cNN, width: 0.65 * k, dash: [2.4 * k, 1.6 * k]);
      cv.line(x1 - nx * o, y1 - ny * o, ex - nx * o, ey - ny * o, cNN, width: 0.65 * k, dash: [2.4 * k, 1.6 * k]);
      arrowHead(cv, x1, y1, x2, y2, cNN, hs);
      break;
    case Res.blocked:
      cv.line(x1, y1, x2, y2, cBlock, width: 1.25 * k);
      final b = 3.6 * k;
      cv.line(x2 + nx * b, y2 + ny * b, x2 - nx * b, y2 - ny * b, cBlock, width: 1.6 * k);
      break;
    case Res.net:
      cv.line(x1, y1, x2, y2, cNN, width: 0.8 * k, dash: [1.2 * k, 1.4 * k]);
      final c = 2.6 * k;
      cv.line(x2 - c, y2 - c, x2 + c, y2 + c, cNN, width: 1.2 * k);
      cv.line(x2 - c, y2 + c, x2 + c, y2 - c, cNN, width: 1.2 * k);
      break;
  }
  cv.circle(x1, y1, 1.2 * k, fill: cGrey);
}

Draw courtWithShots(double width, List<Shot> shots, {double k = 1, Map<int, double>? heat}) {
  final h = courtHeightFor(width);
  return Draw(width, h, (cv) {
    final m = CourtMap(0, 0, width);
    drawCourt(cv, m, heat: heat);
    for (final s in shots) {
      drawShot(cv, m.px(s.ox), m.py(s.oy), m.px(s.tx), m.py(s.ty), s.res, k: k);
    }
  });
}

// ---------------------------------------------------------------------------
// Widgets de texto / maquetación
// ---------------------------------------------------------------------------
pw.Widget h1(String n, String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(children: [
        pw.Container(
          width: 24,
          height: 24,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: cNavy, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(n, style: const pw.TextStyle(color: cWhite, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 10),
        pw.Text(t, style: const pw.TextStyle(color: cText, fontSize: 17, fontWeight: pw.FontWeight.bold)),
      ]),
    );

pw.Widget h2(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
      child: pw.Text(t, style: const pw.TextStyle(color: cPP, fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget para(String t, {double size = 9.5, PdfColor? color}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: size, color: color ?? cText, lineSpacing: 2)),
    );

pw.Widget rich(List<pw.InlineSpan> spans, {double size = 9.5}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: size, color: cText, lineSpacing: 2), children: spans)),
    );

pw.TextSpan b(String t) => pw.TextSpan(text: t, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold));
pw.TextSpan plain(String t) => pw.TextSpan(text: t);

pw.Widget bullet(List<pw.InlineSpan> spans, {double size = 9.5}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, left: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
            width: 4, height: 4, margin: const pw.EdgeInsets.only(top: 4.5, right: 7), decoration: const pw.BoxDecoration(color: cCyan, shape: pw.BoxShape.circle)),
        pw.Expanded(
            child: pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: size, color: cText, lineSpacing: 2), children: spans))),
      ]),
    );

pw.Widget callout(String title, String body, {PdfColor? accent}) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        color: cSurfaceAlt,
        border: pw.Border(left: pw.BorderSide(color: accent ?? cCyan, width: 3)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: cText)),
        pw.SizedBox(height: 3),
        pw.Text(body, style: const pw.TextStyle(fontSize: 9, color: cText, lineSpacing: 1.5)),
      ]),
    );

pw.Widget tag(String t, {PdfColor? bg, PdfColor? fg}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(color: bg ?? cSurfaceAlt, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: fg ?? cText)),
    );

pw.Widget table(List<String> header, List<List<pw.Widget>> rows, {Map<int, pw.TableColumnWidth>? widths, double size = 8.5}) {
  pw.Widget cell(pw.Widget c, {bool head = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: c,
      );
  return pw.Table(
    columnWidths: widths,
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: cBorder, width: 0.6), bottom: pw.BorderSide(color: cBorder, width: 0.6)),
    children: [
      pw.TableRow(
          decoration: const pw.BoxDecoration(color: cNavy),
          children: header
              .map((h) => cell(pw.Text(h, style: pw.TextStyle(color: cWhite, fontSize: size, fontWeight: pw.FontWeight.bold)), head: true))
              .toList()),
      for (var i = 0; i < rows.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: i.isOdd ? cBg : cWhite),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: rows[i].map((c) => cell(c)).toList(),
        ),
    ],
  );
}

pw.Widget tx(String s, {double size = 8.5, bool bold = false, PdfColor? color, pw.TextAlign? align}) =>
    pw.Text(s, textAlign: align, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color ?? cText, lineSpacing: 1.2));

// ---------------------------------------------------------------------------
// Leyenda de trazos
// ---------------------------------------------------------------------------
Draw strokeSample(Res r, {double w = 46, double k = 1.25}) => Draw(w, 14, (cv) {
      drawShot(cv, 4, 7, w - (r == Res.blocked || r == Res.net ? 8 : 3), 7, r, k: k);
    });

const resLabel = {
  Res.point: 'Punto',
  Res.inPlay: 'Adentro, sin punto',
  Res.out: 'Afuera',
  Res.blocked: 'Bloqueado',
  Res.net: 'A la red',
};

pw.Widget legendRow({double size = 7.5, bool compact = false}) => pw.Wrap(
      spacing: compact ? 8 : 14,
      runSpacing: 4,
      children: Res.values
          .map((r) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                strokeSample(r, w: compact ? 26 : 34, k: compact ? 0.85 : 1.05),
                pw.SizedBox(width: 3),
                pw.Text(resLabel[r]!, style: pw.TextStyle(fontSize: size, color: cText)),
              ]))
          .toList(),
    );

pw.Widget countersLine(List<Shot> s, {double size = 7}) {
  final sm = ShotSummary(s);
  if (sm.total == 0) return pw.Text('Sin toques', style: pw.TextStyle(fontSize: size, color: cGrey));
  return pw.RichText(
    text: pw.TextSpan(style: pw.TextStyle(fontSize: size, color: cGrey), children: [
      pw.TextSpan(text: '${sm.total} ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: cText)),
      const pw.TextSpan(text: 'tot · '),
      pw.TextSpan(text: '${sm.pts} pts', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: cPP)),
      pw.TextSpan(text: ' · ${sm.errors} err · Ef '),
      pw.TextSpan(
          text: sm.effLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: sm.eff >= 0 ? cPP : cNN)),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Gráficos
// ---------------------------------------------------------------------------
Draw divergingBars(double w, double h, List<String> labels, List<num> values,
    {num? minV, num? maxV, num step = 3, String Function(num v)? fmt, double fontK = 1}) {
  return Draw(w, h, (cv) {
    final lo = (minV ?? values.reduce(math.min)).toDouble();
    final hi = (maxV ?? values.reduce(math.max)).toDouble();
    const left = 24.0, right = 6.0, top = 14.0, bottom = 18.0;
    final ph = h - top - bottom, pwid = w - left - right;
    double y(num v) => top + (hi - v) / (hi - lo) * ph;
    // grilla
    for (var v = (lo / step).ceil() * step; v <= hi; v += step) {
      cv.line(left, y(v), w - right, y(v), v == 0 ? cGreyLight : cBorder, width: v == 0 ? 0.9 : 0.5);
      cv.text('$v', left - 4, y(v) + 2.5, size: 6.5 * fontK, color: cGrey, align: 'r');
    }
    final slot = pwid / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final v = values[i];
      final cx = left + slot * (i + 0.5);
      final bw = slot * 0.62;
      final y0 = y(0), y1 = y(v);
      final col = v >= 0 ? cPP : cNN;
      if (v != 0) cv.rect(cx - bw / 2, math.min(y0, y1), bw, (y1 - y0).abs(), fill: col);
      final lab = fmt != null ? fmt(v) : (v > 0 ? '+$v' : '$v');
      cv.text(lab, cx, v >= 0 ? y1 - 3 : y1 + 8.5 * fontK, size: 7.5 * fontK, bold: true, color: v == 0 ? cGrey : col, align: 'c');
      cv.text(labels[i], cx, h - 5, size: 7.5 * fontK, bold: true, color: cText, align: 'c');
    }
  });
}

Draw groupedPctBars(double w, double h, List<String> labels, List<double> a, List<double> b2, PdfColor ca, PdfColor cb) {
  return Draw(w, h, (cv) {
    const left = 24.0, right = 6.0, top = 10.0, bottom = 18.0;
    final ph = h - top - bottom, pwid = w - left - right;
    double y(double v) => top + (1 - v) * ph;
    for (var v = 0.0; v <= 1.001; v += 0.25) {
      cv.line(left, y(v), w - right, y(v), v == 0 ? cGreyLight : cBorder, width: 0.5);
      cv.text('${(v * 100).round()}%', left - 4, y(v) + 2.5, size: 6.5, color: cGrey, align: 'r');
    }
    // referencia 50 %
    cv.line(left, y(0.5), w - right, y(0.5), cGreyLight, width: 0.6, dash: [2, 2]);
    final slot = pwid / labels.length;
    for (var i = 0; i < labels.length; i++) {
      final cx = left + slot * (i + 0.5);
      final bw = slot * 0.3;
      cv.rect(cx - bw - 1, y(a[i]), bw, y(0) - y(a[i]), fill: ca);
      cv.rect(cx + 1, y(b2[i]), bw, y(0) - y(b2[i]), fill: cb);
      cv.text('${(a[i] * 100).round()}', cx - bw / 2 - 1, y(a[i]) - 2.5, size: 6.3, bold: true, color: ca, align: 'c');
      cv.text('${(b2[i] * 100).round()}', cx + bw / 2 + 1, y(b2[i]) - 2.5, size: 6.3, bold: true, color: cb, align: 'c');
      cv.text(labels[i], cx, h - 5, size: 7.5, bold: true, align: 'c');
    }
  });
}

/// Evolución de la diferencia del marcador rally por rally.
Draw wormChart(double w, double h, String seq, {double fontK = 1, bool annotate = true}) {
  final diffs = <int>[];
  var own = 0, riv = 0;
  for (final ch in seq.split('')) {
    if (ch == 'O') {
      own++;
    } else {
      riv++;
    }
    diffs.add(own - riv);
  }
  return Draw(w, h, (cv) {
    const left = 22.0, right = 8.0, top = 12.0, bottom = 16.0;
    final maxAbs = diffs.map((d) => d.abs()).reduce(math.max).toDouble() + 1;
    final ph = h - top - bottom, pwid = w - left - right;
    double y(num v) => top + (maxAbs - v) / (2 * maxAbs) * ph;
    final step = pwid / diffs.length;
    for (var v = -maxAbs.floor(); v <= maxAbs; v++) {
      if (v % 2 != 0) continue;
      cv.line(left, y(v), w - right, y(v), v == 0 ? cGreyLight : cBorder, width: v == 0 ? 0.9 : 0.4);
      cv.text(v > 0 ? '+$v' : '$v', left - 4, y(v) + 2.3, size: 6 * fontK, color: cGrey, align: 'r');
    }
    for (var i = 0; i < diffs.length; i++) {
      final d = diffs[i];
      if (d == 0) continue;
      cv.opacity(0.28);
      cv.rect(left + i * step + step * 0.12, math.min(y(0), y(d)), step * 0.76, (y(d) - y(0)).abs(), fill: d > 0 ? cPP : cNN);
      cv.opacity(1);
    }
    var px = left, py = y(0);
    for (var i = 0; i < diffs.length; i++) {
      final nx = left + (i + 1) * step, ny = y(diffs[i]);
      cv.line(px, py, nx, ny, cNavy, width: 1.1, round: true);
      px = nx;
      py = ny;
    }
    // rachas >= 4
    if (annotate) {
      var i = 0;
      while (i < seq.length) {
        var j = i;
        while (j < seq.length && seq[j] == seq[i]) {
          j++;
        }
        final len = j - i;
        if (len >= 4) {
          final x0 = left + i * step, x1 = left + j * step;
          final isOwn = seq[i] == 'O';
          final col = isOwn ? cPP : cNN;
          final yy = isOwn ? y(diffs[j - 1]) - 9 : y(diffs[j - 1]) + 13;
          cv.line(x0 + 1, yy + (isOwn ? 3 : -8), x1 - 1, yy + (isOwn ? 3 : -8), col, width: 0.8);
          cv.text('Racha ${isOwn ? '$len-0' : '0-$len'}', (x0 + x1) / 2, yy, size: 6.8 * fontK, bold: true, color: col, align: 'c');
        }
        i = j;
      }
    }
    for (var k = 5; k <= diffs.length; k += 5) {
      cv.text('$k', left + k * step, h - 4, size: 6 * fontK, color: cGrey, align: 'c');
    }
  });
}

/// Barra horizontal apilada con etiquetas dentro de cada segmento.
Draw stackedBar(double w, double h, List<(String, num, PdfColor)> segs, {num? total, bool showPct = false}) {
  final sum = total ?? segs.fold<num>(0, (a, s) => a + s.$2);
  return Draw(w, h, (cv) {
    var x = 0.0;
    for (final s in segs) {
      final sw = w * s.$2 / sum;
      if (sw <= 0) continue;
      cv.rect(x, 0, sw - 0.8, h, fill: s.$3);
      final label = showPct ? '${(s.$2 / sum * 100).round()}%' : '${s.$2}';
      if (sw > cv.tw(label, 7, bold: true) + 3) {
        cv.text(label, x + sw / 2, h / 2 + 2.5, size: 7, bold: true, color: cWhite, align: 'c');
      }
      x += sw;
    }
  });
}

pw.Widget swatch(PdfColor c, String l) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(2))),
      pw.SizedBox(width: 3),
      pw.Text(l, style: const pw.TextStyle(fontSize: 7.3, color: cText)),
    ]);

pw.Widget kpi(String value, String label, String sub, PdfColor accent, {double w = 118}) => pw.Container(
      width: w,
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: pw.BoxDecoration(
        color: cWhite,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: cBorder, width: 0.8),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: cGrey)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.Text(sub, style: const pw.TextStyle(fontSize: 6.8, color: cGrey)),
      ]),
    );

// ---------------------------------------------------------------------------
// Maqueta de celular
// ---------------------------------------------------------------------------
pw.Widget phone({required String activeTab, required List<pw.Widget> body, double w = 238, double h = 500}) {
  pw.Widget tab(String t) {
    final on = t == activeTab;
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.only(top: 5, bottom: 4),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: on ? cCyan : cNavy, width: 2))),
        alignment: pw.Alignment.center,
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: on ? cWhite : const PdfColor.fromInt(0xFF97A1AC))),
      ),
    );
  }

  return pw.Container(
    width: w,
    height: h,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(color: cNavyDeep, borderRadius: pw.BorderRadius.circular(22)),
    child: pw.ClipRRect(
      horizontalRadius: 16,
      verticalRadius: 16,
      child: pw.Container(
        color: cBg,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            color: cNavy,
            padding: const pw.EdgeInsets.fromLTRB(12, 7, 12, 0),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('9:41', style: const pw.TextStyle(fontSize: 6.5, color: cWhite, fontWeight: pw.FontWeight.bold)),
                pw.Text('●●●  ▮', style: const pw.TextStyle(fontSize: 5.5, color: cWhite)),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('‹', style: const pw.TextStyle(fontSize: 14, color: cWhite)),
                pw.SizedBox(width: 8),
                pw.Text('Estadísticas', style: const pw.TextStyle(fontSize: 11, color: cWhite, fontWeight: pw.FontWeight.bold)),
                pw.Spacer(),
                pw.Text('PDF', style: const pw.TextStyle(fontSize: 7, color: cCyan, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [tab('Tabla'), tab('Mapas'), tab('Gráficos')]),
            ]),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 6),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: body),
          ),
        ]),
      ),
    ),
  );
}

pw.Widget chip(String t, {bool on = false, double size = 7}) => pw.Container(
      margin: const pw.EdgeInsets.only(right: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: on ? cCyan : cWhite,
        borderRadius: pw.BorderRadius.circular(9),
        border: pw.Border.all(color: on ? cCyan : cBorder, width: 0.7),
      ),
      child: pw.Text(t, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: on ? const PdfColor.fromInt(0xFF06222B) : cText)),
    );

pw.Widget segmented(List<String> opts, String sel) => pw.Container(
      decoration: pw.BoxDecoration(color: cSurfaceAlt, borderRadius: pw.BorderRadius.circular(6)),
      padding: const pw.EdgeInsets.all(2),
      child: pw.Row(
          children: opts
              .map((o) => pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                          color: o == sel ? cNavy : null, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Text(o,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: o == sel ? cWhite : cText)),
                    ),
                  ))
              .toList()),
    );

pw.Widget miniCard(String title, pw.Widget child) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: pw.BoxDecoration(color: cWhite, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: cBorder, width: 0.6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: cText)),
        pw.SizedBox(height: 3),
        child,
      ]),
    );

pw.Widget numberBadge(int n) => pw.Container(
      width: 14,
      height: 14,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(color: cCyan, shape: pw.BoxShape.circle),
      child: pw.Text('$n', style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF06222B))),
    );

// ---------------------------------------------------------------------------
// Datos de ejemplo de equipo
// ---------------------------------------------------------------------------
// Captura 2 (tabla de rotaciones) — se reproduce tal cual como ejemplo.
const rotLabels = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];
const rotGP = [4, 0, -3, 9, -4, -3];
const rotRows = [
  // G-P, adv -pts, adv +err, +pts, -err, gen err, saque pts, saque err, rec err, ataque pts, ataque bl, ataque err, bl tot
  ['P1', '4', '-12', '11', '10', '-5', '1', '.', '.', '2', '9', '.', '2', '1'],
  ['P2', '.', '-7', '5', '11', '-9', '1', '1', '3', '2', '9', '.', '3', '1'],
  ['P3', '-3', '-8', '4', '9', '-8', '3', '.', '1', '2', '7', '.', '2', '2'],
  ['P4', '9', '-7', '6', '17', '-7', '.', '3', '1', '3', '13', '.', '3', '1'],
  ['P5', '-4', '-6', '3', '5', '-6', '1', '.', '2', '.', '4', '.', '3', '1'],
  ['P6', '-3', '-4', '5', '7', '-11', '.', '.', '3', '3', '5', '.', '5', '2'],
];
const sideOut = [0.62, 0.55, 0.48, 0.71, 0.44, 0.50];
const breakPt = [0.46, 0.38, 0.33, 0.58, 0.29, 0.31];

// Set 1 de ejemplo, rally por rally (O = punto propio, R = punto rival).
const set1 = 'ORROORORROOOOORRORRRORRRROOROOORORROOOOROROROO';

// ---------------------------------------------------------------------------
Future<void> main(List<String> args) async {
  final outPath = args.isNotEmpty ? args.first : 'documents/RallyStats-Propuesta-Estadistica-Visual.pdf';
  fReg = _ttf(r'C:\Windows\Fonts\arial.ttf');
  fBold = _ttf(r'C:\Windows\Fonts\arialbd.ttf');

  final doc = pw.Document(
    title: 'RallyStats — Propuesta de estadística visual',
    author: 'RallyStats',
    theme: pw.ThemeData.withFont(base: fReg, bold: fBold),
  );
  const fmt = PdfPageFormat.a4;
  const margin = pw.EdgeInsets.fromLTRB(36, 34, 36, 30);

  // ======================== PORTADA ========================
  doc.addPage(pw.Page(
    pageFormat: fmt,
    margin: pw.EdgeInsets.zero,
    build: (ctx) => pw.Container(
      color: cNavy,
      padding: const pw.EdgeInsets.fromLTRB(48, 60, 48, 40),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('RALLYSTATS · PROPUESTA', style: const pw.TextStyle(color: cCyan, fontSize: 10, letterSpacing: 1.5, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        pw.Text('Estadística', style: const pw.TextStyle(color: cWhite, fontSize: 36, fontWeight: pw.FontWeight.bold)),
        pw.Text('visual', style: const pw.TextStyle(color: cCyan, fontSize: 36, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 14),
        pw.SizedBox(
          width: 400,
          child: pw.Text(
              'Mapa de direcciones de saque, ataque y contraataque por jugador, y gráficos de equipo para el entrenador. '
              'Boceto de la sección nueva, cómo se registra el dato y un plan de implementación por etapas.',
              style: const pw.TextStyle(color: PdfColor.fromInt(0xFFCBD5E1), fontSize: 11.5, lineSpacing: 3)),
        ),
        pw.SizedBox(height: 28),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: cWhite, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(mainAxisSize: pw.MainAxisSize.min, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              for (final e in [('Saque', players[0].serve), ('Ataque', players[0].attack), ('Contraataque', players[0].counter)]) ...[
                pw.Column(children: [
                  pw.Text(e.$1, style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: cNavy)),
                  pw.SizedBox(height: 4),
                  courtWithShots(130, e.$2),
                ]),
                if (e.$1 != 'Contraataque') pw.SizedBox(width: 10),
              ],
            ]),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
            child: pw.Text('OP #16 — datos de ejemplo',
                style: const pw.TextStyle(color: PdfColor.fromInt(0xFF97A1AC), fontSize: 8))),
        pw.Spacer(),
        pw.Divider(color: const PdfColor.fromInt(0xFF2A3542)),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Boceto con decisiones tomadas el 29/09/2026 · Todavía no implementado', style: const pw.TextStyle(color: PdfColor.fromInt(0xFF97A1AC), fontSize: 8.5)),
          pw.Text('29/09/2026 · RallyStats 1.0.3', style: const pw.TextStyle(color: PdfColor.fromInt(0xFF97A1AC), fontSize: 8.5)),
        ]),
      ]),
    ),
  ));

  pw.Widget header(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cBorder, width: 0.8))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('RallyStats', style: const pw.TextStyle(color: cNavy, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Text('Propuesta · Estadística visual', style: const pw.TextStyle(color: cGrey, fontSize: 8)),
        ]),
      );
  pw.Widget footer(pw.Context ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Boceto con datos de ejemplo', style: const pw.TextStyle(color: cGreyLight, fontSize: 7.5)),
        pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(color: cGrey, fontSize: 7.5)),
      ]);

  pw.MultiPage section(List<pw.Widget> Function() build) => pw.MultiPage(
        pageFormat: fmt,
        margin: margin,
        header: header,
        footer: footer,
        build: (ctx) => build(),
      );

  // ======================== 1. RESUMEN ========================
  pw.Widget avail(String s) {
    final col = s == 'Hoy' ? cSuccess : (s == 'Parcial' ? cBlock : cNN);
    return pw.Row(children: [tag(s, bg: col, fg: cWhite)]);
  }

  doc.addPage(section(() => [
        h1('1', 'Qué se propone'),
        para('Una sección nueva dentro de Estadísticas (junto a la tabla actual) que muestre lo mismo que la planilla '
            'a mano del entrenador: para cada jugador, una cancha por fundamento (saque, ataque, contraataque) con una '
            'flecha por toque, desde dónde salió hasta dónde cayó. El resultado se lee por el tipo de trazo, sin tener que '
            'mirar números. Además se suman gráficos de equipo (rendimiento por rotación, evolución del marcador, origen '
            'de los puntos, etc.) para que el entrenador lea el partido de un vistazo.'),
        rich([
          b('Respuesta corta a "¿se puede?": '),
          plain('sí. El motor de estadística ya recorre toque por toque cada set y ya guarda la zona de destino, así que '
              'una buena parte sale con los datos que la app registra hoy. Lo que falta es el punto exacto de caída '
              'y distinguir "afuera" de "a la red" dentro de NN; eso requiere un ajuste chico en la carga en vivo '
              '(ver sección 5).'),
        ]),
        h2('Qué incluye y con qué datos'),
        table(
          ['Mejora', 'Para qué le sirve al entrenador', '¿Datos de hoy?', 'Prioridad'],
          [
            [tx('Mapa de direcciones por jugador', bold: true), tx('Ver hacia dónde ataca/saca cada jugador y con qué resultado (punto, adentro, afuera, bloqueado).'), avail('Parcial'), tx('Alta')],
            [tx('Vista "Mapa + tabla"', bold: true), tx('Debajo de cada cancha, el conteo por zona y la eficiencia, para no perder el número.'), avail('Hoy'), tx('Alta')],
            [tx('Rendimiento por rotación (P1–P6)', bold: true), tx('Detectar en qué rotación se pierden puntos (captura 2), con side-out y break-point.'), avail('Hoy'), tx('Alta')],
            [tx('Evolución del marcador', bold: true), tx('Ver rachas a favor y en contra por set, para revisar tiempos y cambios.'), avail('Hoy'), tx('Media')],
            [tx('Origen de los puntos', bold: true), tx('De dónde salen los puntos ganados y cómo se regalan los perdidos.'), avail('Hoy'), tx('Media')],
            [tx('Eficiencia de ataque por jugador', bold: true), tx('Ranking simple: (puntos − errores − bloqueados) / total.'), avail('Hoy'), tx('Media')],
            [tx('Recepción por jugador', bold: true), tx('Distribución PP / P / ! / N / V- / NN de cada receptor, en una barra.'), avail('Hoy'), tx('Media')],
            [tx('Mapa de calor por zona', bold: true), tx('Las tablas de zona que ya existen, pintadas sobre la cancha.'), avail('Hoy'), tx('Baja')],
          ],
          widths: {0: const pw.FlexColumnWidth(2.1), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(1.1), 3: const pw.FlexColumnWidth(0.9)},
        ),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          avail('Hoy'),
          pw.SizedBox(width: 4),
          tx('sale con lo que ya se registra', size: 8, color: cGrey),
          pw.SizedBox(width: 12),
          avail('Parcial'),
          pw.SizedBox(width: 4),
          tx('sale aproximado hoy; exacto con el ajuste de carga de la sección 5', size: 8, color: cGrey),
        ]),
        pw.SizedBox(height: 10),
        callout('Todo es derivado del log de jugadas',
            'Igual que la tabla actual, estos gráficos se calculan desde la lista de RallyEvent de cada set '
            '(StatsEngine). No hay contadores nuevos que mantener, y los partidos ya guardados muestran estos gráficos '
            'automáticamente, siempre que tengan los datos necesarios.'),
      ]));

  // ======================== 2. MAPA DE DIRECCIONES ========================
  final big = players[0].attack;
  doc.addPage(section(() => [
        h1('2', 'Mapa de direcciones: cómo se lee'),
        para('Cada toque es una flecha: arranca en el punto desde donde se atacó o sacó (punto gris) y termina donde cayó '
            'la pelota. La cancha rival (arriba) está a escala real, con sus zonas 1–6. La mitad propia (abajo) está '
            'achicada a la mitad, porque solo interesa el punto de salida.'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(children: [
            courtWithShots(250, big, k: 1.35),
            pw.SizedBox(height: 4),
            pw.Text('OP #16 · Ataque (K1) · datos de ejemplo', style: const pw.TextStyle(fontSize: 7.5, color: cGrey)),
            pw.SizedBox(height: 2),
            countersLine(big, size: 8),
          ]),
          pw.SizedBox(width: 18),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              h2('Trazos'),
              for (final r in Res.values)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    strokeSample(r, w: 52, k: 1.4),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        tx(resLabel[r]!, bold: true, size: 9),
                        tx(
                            {
                              Res.point: 'Línea continua. Calificación PP.',
                              Res.inPlay: 'Línea punteada. P o N: la pelota entró pero siguió el rally.',
                              Res.out: 'Doble línea punteada. NN que salió de la cancha.',
                              Res.blocked: 'Línea continua corta que muere en la red, con una barra. BLOQ (solo ataque/contra).',
                              Res.net: 'Punteado fino que muere en la red, con una cruz. NN a la red.',
                            }[r]!,
                            size: 8,
                            color: cGrey),
                      ]),
                    ),
                  ]),
                ),
              pw.SizedBox(height: 2),
              callout('Forma y color dicen lo mismo',
                  'El resultado se reconoce por el tipo de trazo, así que se entiende aunque el PDF se imprima en blanco y negro. '
                  'El color (azul punto, gris adentro, rojo error, naranja bloqueado) lo refuerza en pantalla.'),
              callout('Pedido original + dos trazos extra',
                  'Lo pedido: continua = punto, punteada = adentro sin punto, doble punteada = afuera. '
                  'Se suman "bloqueado" y "a la red" porque la app ya distingue BLOQ, y separar la red de afuera '
                  'es justo lo que el entrenador anota a mano.',
                  accent: cBlock),
            ]),
          ),
        ]),
        h2('De la calificación al trazo'),
        table(
          ['Fundamento', 'PP', 'P', 'N', 'BLOQ', 'NN'],
          [
            [tx('Saque', bold: true), tx('Punto (ace)'), tx('Adentro'), tx('Adentro'), tx('—', color: cGrey), tx('Afuera o a la red *')],
            [tx('Ataque (K1)', bold: true), tx('Punto'), tx('Adentro'), tx('Adentro'), tx('Bloqueado'), tx('Afuera o a la red *')],
            [tx('Contraataque (K2+)', bold: true), tx('Punto'), tx('Adentro'), tx('Adentro'), tx('Bloqueado'), tx('Afuera o a la red *')],
          ],
          widths: {0: const pw.FlexColumnWidth(1.6), 5: const pw.FlexColumnWidth(1.8)},
        ),
        pw.SizedBox(height: 4),
        tx('* Hoy NN no guarda si fue afuera o a la red: con los datos actuales se dibuja con un trazo único de "error". '
            'La sección 5 propone cómo registrarlo sin agregar pasos a la carga.',
            size: 7.8, color: cGrey),
      ]));

  // ======================== 3. PLANILLA POR JUGADOR ========================
  List<pw.Widget> sheetRows(List<PlayerSample> ps) {
    const cw = 120.0;
    return [
      for (final p in ps)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 44,
              height: courtHeightFor(cw) + 14,
              decoration: pw.BoxDecoration(color: cNavy, borderRadius: pw.BorderRadius.circular(5)),
              alignment: pw.Alignment.center,
              child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text(p.tag, style: const pw.TextStyle(color: cCyan, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('#${p.number}', style: const pw.TextStyle(color: cWhite, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(p.role, textAlign: pw.TextAlign.center, style: const pw.TextStyle(color: PdfColor.fromInt(0xFF97A1AC), fontSize: 6)),
              ]),
            ),
            pw.SizedBox(width: 8),
            for (final e in [('Saque', p.serve), ('Ataque', p.attack), ('Contraataque', p.counter)]) ...[
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                courtWithShots(cw, e.$2, k: 0.95),
                pw.SizedBox(height: 2),
                pw.SizedBox(width: cw, child: countersLine(e.$2)),
              ]),
              if (e.$1 != 'Contraataque') pw.SizedBox(width: 8),
            ],
          ]),
        ),
    ];
  }

  pw.Widget sheetHeader() => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.SizedBox(width: 52),
          for (final t in ['SAQUE', 'ATAQUE (K1)', 'CONTRAATAQUE (K2+)'])
            pw.Container(
              width: 120,
              margin: pw.EdgeInsets.only(right: t == 'CONTRAATAQUE (K2+)' ? 0 : 8),
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(color: cSurfaceAlt, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(t, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: cNavy)),
            ),
        ]),
      );

  doc.addPage(section(() => [
        h1('3', 'Planilla por jugador (versión PDF)'),
        para('La misma idea que la planilla a mano (captura 1), pero generada sola al final del partido: una fila por '
            'jugador y una columna por fundamento. Debajo de cada cancha va el resumen numérico, así el reporte trae '
            'el mapa y la tabla al mismo tiempo. Se puede filtrar por set o ver el partido completo.',
            size: 9),
        legendRow(),
        pw.SizedBox(height: 6),
        sheetHeader(),
        ...sheetRows(players.sublist(0, 3)),
      ]));
  doc.addPage(section(() => [
        sheetHeader(),
        ...sheetRows(players.sublist(3, 6)),
        tx('Ef = (puntos − errores) / total, donde errores = afuera + a la red + bloqueado. Es la eficiencia estándar de '
            'ataque y se aplica igual al saque, que no tiene bloqueado.',
            size: 7.8, color: cGrey),
      ]));

  // ======================== 4. EN LA APP ========================
  final op = players[0];
  final opSum = ShotSummary(op.attack);
  doc.addPage(section(() => [
        h1('4', 'Cómo se vería en la app'),
        para('Estadísticas pasa a tener tres pestañas: Tabla (la actual, sin cambios), Mapas y Gráficos. Los filtros '
            '(partido completo / set) son los mismos que ya existen y aplican a las tres.'),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          phone(activeTab: 'Mapas', h: 490, body: [
            pw.Row(children: [chip('Partido completo ▼'), chip('S1'), chip('S2'), chip('S3')]),
            pw.SizedBox(height: 6),
            pw.Row(children: [chip('OP #16', on: true), chip('PR #9'), chip('PR #5'), chip('C #10'), chip('…')]),
            pw.SizedBox(height: 6),
            segmented(['Saque', 'Ataque', 'Contra'], 'Ataque'),
            pw.SizedBox(height: 6),
            pw.Center(child: courtWithShots(172, op.attack, k: 1.0)),
            pw.SizedBox(height: 4),
            legendRow(size: 6, compact: true),
            pw.SizedBox(height: 5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              for (final e in [
                ('${opSum.total}', 'Total', cText),
                ('${opSum.pts}', 'Puntos', cPP),
                ('${opSum.inPlay}', 'Adentro', cInPlay),
                ('${opSum.errors}', 'Errores', cNN),
                (opSum.effLabel, 'Eficiencia', cPP),
              ])
                pw.Column(children: [
                  pw.Text(e.$1, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: e.$3)),
                  pw.Text(e.$2, style: const pw.TextStyle(fontSize: 6, color: cGrey)),
                ]),
            ]),
            pw.SizedBox(height: 5),
            pw.Row(children: [
              pw.Text('Ver como tabla por zona', style: const pw.TextStyle(fontSize: 7, color: cPP, fontWeight: pw.FontWeight.bold)),
              pw.Text('  ►', style: const pw.TextStyle(fontSize: 6, color: cPP)),
            ]),
          ]),
          pw.SizedBox(width: 12),
          phone(activeTab: 'Gráficos', h: 490, body: [
            pw.Row(children: [chip('Partido completo ▼'), chip('S1'), chip('S2')]),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Expanded(child: miniCard('Side-out', pw.Text('56%', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: cNavy)))),
              pw.SizedBox(width: 5),
              pw.Expanded(child: miniCard('Break-point', pw.Text('39%', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: cCyan)))),
            ]),
            miniCard('Diferencia por rotación', divergingBars(200, 90, rotLabels, rotGP, minV: -6, maxV: 12, fontK: 0.85)),
            miniCard('Evolución del marcador · Set 1 (25-21)', wormChart(200, 82, set1, fontK: 0.85)),
            miniCard(
                'Origen de los puntos',
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  stackedBar(200, 11, [('Ataque', 11, cPP), ('Contra', 5, cP), ('Bloq', 3, cNavy), ('Saque', 2, cCyan), ('Err. rival', 4, cGreyLight)]),
                  pw.SizedBox(height: 3),
                  stackedBar(200, 11, [('Err. ataque', 4, cNN), ('Err. saque', 5, cVneg), ('Rec.', 2, cN), ('Gen.', 1, cBlock), ('Pto rival', 9, cInPlay)]),
                ])),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          for (final col in [
            [
              ['Filtro de set', 'el mismo de la pantalla actual (Partido completo / Set N), aplica a las tres pestañas.'],
              ['Selector de jugador', 'solo aparecen los que tuvieron toques en ese fundamento.'],
              ['Fundamento', 'Saque / Ataque / Contra. Tocar una flecha muestra set, marcador y calificación de ese toque.'],
            ],
            [
              ['Leyenda fija', 'debajo de la cancha, con los mismos trazos que el PDF.'],
              ['Resumen + "Ver como tabla"', 'abre la tabla por zona que ya existe en el reporte, para quien prefiera números.'],
              ['Gráficos de equipo', 'tarjetas una debajo de otra; cada una se amplía a pantalla completa.'],
            ],
          ]) ...[
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                for (final e in col) bullet([b('${e[0]}: '), plain(e[1])], size: 8.3),
              ]),
            ),
            pw.SizedBox(width: 12),
          ],
        ]),
        pw.SizedBox(height: 8),
        callout('Mapa y tabla a la vez',
            'Pediste el mapa, la tabla o los dos: la propuesta es mostrar los dos. El mapa es la vista principal, y los '
            'números quedan siempre debajo (resumen) y a un toque (tabla por zona). En el PDF del partido van juntos, como en la sección 3.'),
      ]));

  // ======================== 5. REGISTRO DEL DATO ========================
  doc.addPage(section(() => [
        h1('5', 'Cómo se registra el dato'),
        h2('Lo que guarda la app hoy'),
        bullet([b('Zona de destino '), plain('(1–6, o 1–9 con la franja media), opcional, solo si el set tiene activado el registro de zonas. Es la grilla que aparece en el diálogo del toque.')]),
        bullet([b('Sin punto de origen: '), plain('no se sabe desde dónde atacó o sacó el jugador.')]),
        bullet([b('NN no distingue '), plain('entre afuera, red o invasión: todo es "error".')]),
        para('Con eso ya sale un mapa aproximado (flecha al centro de la zona, origen deducido), también para partidos ya guardados.'),
        h2('Propuesta: tocar la cancha en vez de la grilla'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(children: [
            tx('Hoy', bold: true, size: 8.5),
            pw.SizedBox(height: 4),
            Draw(150, 110, (cv) {
              const rows = [
                [1, 6, 5],
                [2, 3, 4]
              ];
              cv.text('Fondo', 75, 8, size: 6.5, color: cGrey, align: 'c');
              for (var r = 0; r < 2; r++) {
                for (var c = 0; c < 3; c++) {
                  final sel = rows[r][c] == 5;
                  cv.rect(4 + c * 48, 14 + r * 42, 44, 38, fill: sel ? cCyan : cSurfaceAlt, stroke: sel ? cCyan : cBorder, r: 5);
                  cv.text('${rows[r][c]}', 26 + c * 48, 38 + r * 42, size: 12, bold: true, color: cText, align: 'c');
                }
              }
              cv.text('Red', 75, 108, size: 6.5, color: cGrey, align: 'c');
            }),
          ]),
          pw.SizedBox(width: 14),
          pw.Padding(padding: const pw.EdgeInsets.only(top: 50), child: pw.Text('→', style: const pw.TextStyle(fontSize: 22, color: cGrey))),
          pw.SizedBox(width: 14),
          pw.Column(children: [
            tx('Propuesta', bold: true, size: 8.5),
            pw.SizedBox(height: 4),
            Draw(190, 194, (cv) {
              final m = CourtMap(0, 0, 190);
              cv.rect(0, 0, 190, m.py(0.5) + 12, fill: cWhite, stroke: cBorder, sw: 0.6, r: 4, dash: [2, 2]);
              cv.rect(m.px(0), m.py(0), m.cw, m.py(0.5) - m.py(0), fill: cRivalHalf, stroke: cGreyLight, sw: 0.8);
              cv.line(m.px(0), m.py(1 / 3), m.px(1), m.py(1 / 3), cGreyLight, width: 0.5);
              cv.line(m.px(1 / 3), m.py(0), m.px(1 / 3), m.py(0.5), cGreyLight, width: 0.3, dash: [1, 2]);
              cv.line(m.px(2 / 3), m.py(0), m.px(2 / 3), m.py(0.5), cGreyLight, width: 0.3, dash: [1, 2]);
              cv.line(m.px(-0.06), m.py(0.5), m.px(1.06), m.py(0.5), cNavy, width: 2.2);
              cv.text('Red', m.px(1.0), m.py(0.5) + 10, size: 6.5, color: cGrey, align: 'r');
              cv.text('zona "afuera"', m.px(-0.06), m.py(0) - 5, size: 6, color: cGrey);
              // toque adentro
              final ix = m.px(0.8), iy = m.py(0.12);
              cv.circle(ix, iy, 7, stroke: cPP, sw: 1.2);
              cv.circle(ix, iy, 2.2, fill: cPP);
              cv.text('adentro · zona 5', ix, iy + 16, size: 6.5, bold: true, color: cPP, align: 'c');
              // toque afuera
              final ox = m.px(-0.07), oy = m.py(0.3);
              cv.circle(ox, oy, 7, stroke: cNN, sw: 1.2);
              cv.circle(ox, oy, 2.2, fill: cNN);
              cv.text('afuera', ox + 10, oy + 2, size: 6.5, bold: true, color: cNN);
              // toque en la red
              final nx = m.px(0.45), ny = m.py(0.5);
              cv.circle(nx, ny, 7, stroke: cNN, sw: 1.2);
              cv.text('red', nx + 10, ny - 5, size: 6.5, bold: true, color: cNN);
            }),
          ]),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              bullet([plain('La grilla se reemplaza por un '), b('dibujo de la cancha con margen'), plain('. Se toca donde cayó la pelota: '), b('un toque, igual que hoy.')], size: 8.3),
              bullet([plain('La '), b('zona se calcula sola'), plain(': las tablas de zona actuales siguen igual.')], size: 8.3),
              bullet([b('En el margen'), plain(' = afuera; '), b('sobre la red'), plain(' = red.')], size: 8.3),
              bullet([b('Tocar la mitad propia marca el origen'), plain(' (opcional). Sin modos: cuenta dónde cae el toque.')], size: 8.3),
              bullet([plain('Sigue siendo '), b('opcional'), plain(', con el interruptor por set de hoy.')], size: 8.3),
            ]),
          ),
        ]),
        h2('Punto de origen: se deduce, con un segundo toque opcional'),
        para('Obligar a marcar el origen duplicaría los toques en plena carga en vivo. Por defecto se deduce: la app ya '
            'sabe, en cada rally, la rotación exacta (la reconstruye desde el log) y el puesto de cada jugador. Si quien '
            'carga quiere precisión, puede tocar además la mitad propia de la cancha para marcar el origen real (opcional):'),
        table(
          ['Situación', 'Origen que se dibuja'],
          [
            [tx('Saque'), tx('Detrás de la línea de fondo propia, a la derecha (zona 1). Con el toque opcional, desde donde sacó realmente.')],
            [tx('Punta receptor en fila delantera / zaguero'), tx('Zona 4 / zaguero por zona 6 (pipe)')],
            [tx('Opuesto en fila delantera / zaguero'), tx('Zona 2 / zaguero por zona 1')],
            [tx('Central'), tx('Zona 3')],
            [tx('Armador (segunda pelota)'), tx('Zona 2, pegado a la red')],
            [tx('Universal'), tx('Según la posición de la rotación en ese momento')],
          ],
          widths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
        ),
        pw.SizedBox(height: 6),
        h2('Cambio técnico (resumen)'),
        bullet([b('RallyEvent: '), plain('campos opcionales nuevos targetX / targetY y originX / originY (coordenadas normalizadas, igual que los trazos de la pizarra) y missType (out / net) para NN. Mismo patrón toJson/fromJson a mano: los partidos viejos los leen como null.')], size: 8.5),
        bullet([b('HitZonePicker: '), plain('se reemplaza la grilla por la cancha tocable; targetZone se sigue guardando, calculada desde el punto.')], size: 8.5),
        bullet([b('StatsEngine: '), plain('nuevo computeShots(match, set) que devuelve la lista de flechas (origen deducido + destino exacto o centro de zona + resultado).')], size: 8.5),
      ]));

  // ======================== 6. ROTACIONES ========================
  doc.addPage(section(() => [
        h1('6', 'Rendimiento por rotación (captura 2)'),
        para('Para cada rotación (P1 = armador en zona 1, etc.) muestra cuántos puntos se ganaron y se perdieron mientras el '
            'equipo estuvo en esa formación. Es el gráfico más útil para decidir la rotación inicial y dónde parar el '
            'partido. Se puede calcular con los datos de hoy: la app ya reconstruye la rotación en cada rally.'),
        h2('Tabla'),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: cBorder, width: 0.6), bottom: pw.BorderSide(color: cBorder, width: 0.6)),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: cNavy), children: [
              for (final hd in ['Rot.', 'G-P', 'Adv\n−Pts', 'Adv\n+Err', '+Pts', '−Err', 'Err\ngen.', 'Saque\nPts', 'Saque\nErr', 'Rec.\nErr', 'Ataque\nPts', 'Ataque\nBl', 'Ataque\nErr', 'Bloq\nTot'])
                pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    child: pw.Text(hd, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: cWhite, fontWeight: pw.FontWeight.bold))),
            ]),
            for (var i = 0; i < rotRows.length; i++)
              pw.TableRow(decoration: pw.BoxDecoration(color: i.isOdd ? cBg : cWhite), children: [
                for (var c = 0; c < rotRows[i].length; c++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
                    child: pw.Text(rotRows[i][c],
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: c <= 1 || c == 4 || c == 5 ? pw.FontWeight.bold : null,
                          color: c == 1
                              ? (rotGP[i] > 0 ? cPP : (rotGP[i] < 0 ? cNN : cGrey))
                              : cText,
                        )),
                  ),
              ]),
          ],
        ),
        h2('Diferencia de puntos por rotación (ganados − perdidos)'),
        divergingBars(523, 170, rotLabels, rotGP, minV: -6, maxV: 12),
        h2('Side-out y break-point por rotación'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          groupedPctBars(330, 150, rotLabels, sideOut, breakPt, cNavy, cCyan),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [swatch(cNavy, 'Side-out'), pw.SizedBox(width: 10), swatch(cCyan, 'Break-point')]),
              pw.SizedBox(height: 6),
              bullet([b('Side-out: '), plain('% de rallies ganados cuando saca el rival (recepción + K1).')], size: 8.3),
              bullet([b('Break-point: '), plain('% de rallies ganados con saque propio.')], size: 8.3),
              bullet([plain('Separa si una rotación falla '), b('recibiendo'), plain(' o '), b('sacando'), plain('. En el ejemplo, P5 flojea en las dos.')], size: 8.3),
              tx('Datos: servingTeamBefore y pointWinner de cada RallyEvent, que ya se guardan.', size: 7.5, color: cGrey),
            ]),
          ),
        ]),
      ]));

  // ======================== 7. MÁS GRÁFICOS ========================
  // Eficiencia de ataque (ataque + contra) por jugador, a partir de los mismos tiros de ejemplo.
  final effRows = players
      .map((p) => (p.label, ShotSummary([...p.attack, ...p.counter])))
      .toList()
    ..sort((a, b2) => b2.$2.eff.compareTo(a.$2.eff));

  final recep = <(String, List<int>)>[
    ('PR #9', [7, 9, 4, 3, 1, 1]),
    ('PR #5', [5, 8, 5, 4, 2, 2]),
    ('L #3', [11, 8, 3, 2, 0, 1]),
    ('OP #16', [0, 2, 1, 1, 0, 1]),
  ];
  final recColors = [cPP, cP, cExcl, cN, cVneg, cNN];

  // mapa de calor del ataque de equipo: cantidad por zona de destino (solo toques adentro/punto).
  final allAtk = players.expand((p) => [...p.attack, ...p.counter]).toList();
  int zoneOf(Shot s) {
    final col = s.tx < 1 / 3 ? 0 : (s.tx < 2 / 3 ? 1 : 2);
    final back = s.ty < 1 / 3;
    return back ? [1, 6, 5][col] : [2, 3, 4][col];
  }

  final zoneCount = <int, int>{for (var z = 1; z <= 6; z++) z: 0};
  final zonePts = <int, int>{for (var z = 1; z <= 6; z++) z: 0};
  for (final s in allAtk.where((s) => s.res == Res.point || s.res == Res.inPlay)) {
    final z = zoneOf(s);
    zoneCount[z] = zoneCount[z]! + 1;
    if (s.res == Res.point) zonePts[z] = zonePts[z]! + 1;
  }
  final maxZ = zoneCount.values.reduce(math.max);

  doc.addPage(section(() => [
        h1('7', 'Otros gráficos útiles para el entrenador'),
        h2('Evolución del marcador (set 1, final 25-21)'),
        para('Cada columna es un rally: arriba de la línea, el equipo va ganando; abajo, perdiendo. Se marcan las rachas de 4 '
            'o más puntos seguidos, para revisar si se pidió tiempo a tiempo o si un cambio cortó la racha.', size: 9),
        wormChart(523, 150, set1),
        h2('Origen de los puntos'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(width: 90, child: tx('Ganados (25)', bold: true)),
          stackedBar(430, 16, [('Ataque', 11, cPP), ('Contra', 5, cP), ('Bloqueo', 3, cNavy), ('Saque', 2, cCyan), ('Error rival', 4, cGreyLight)]),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(width: 90, child: tx('Perdidos (21)', bold: true)),
          stackedBar(430, 16, [('Err. ataque', 4, cNN), ('Err. saque', 5, cVneg), ('Err. recepción', 2, cN), ('Err. genérico', 1, cBlock), ('Punto rival', 9, cInPlay)]),
        ]),
        pw.SizedBox(height: 5),
        pw.Wrap(spacing: 10, runSpacing: 3, children: [
          swatch(cPP, 'Ataque'), swatch(cP, 'Contra'), swatch(cNavy, 'Bloqueo'), swatch(cCyan, 'Saque'), swatch(cGreyLight, 'Error rival'),
          swatch(cNN, 'Err. ataque/bloq.'), swatch(cVneg, 'Err. saque'), swatch(cN, 'Err. recepción'), swatch(cBlock, 'Err. genérico'), swatch(cInPlay, 'Punto directo rival'),
        ]),
        pw.SizedBox(height: 4),
        tx('Lectura: si "Perdidos" tiene más rojo/naranja que gris, el equipo pierde más por errores propios que por mérito del rival.', size: 8, color: cGrey),
        h2('Eficiencia de ataque por jugador (ataque + contra)'),
        Draw(523, 22.0 * effRows.length + 16, (cv) {
          const left = 70.0, right = 70.0;
          const pwid = 523 - left - right;
          const lo = -0.4, hi = 0.8;
          double x(double v) => left + (v - lo) / (hi - lo) * pwid;
          for (var v = lo; v <= hi + 0.001; v += 0.2) {
            cv.line(x(v), 0, x(v), 22.0 * effRows.length, v.abs() < 0.001 ? cGreyLight : cBorder, width: v.abs() < 0.001 ? 0.9 : 0.4);
            cv.text('${(v * 100).round()}%', x(v), 22.0 * effRows.length + 11, size: 6.5, color: cGrey, align: 'c');
          }
          for (var i = 0; i < effRows.length; i++) {
            final r = effRows[i];
            final yy = i * 22.0 + 4;
            cv.text(r.$1, left - 8, yy + 10, size: 8.5, bold: true, align: 'r');
            final e = r.$2.eff;
            final col = e >= 0 ? cPP : cNN;
            cv.rect(math.min(x(0), x(e)), yy, (x(e) - x(0)).abs(), 13, fill: col);
            cv.text(r.$2.effLabel, e >= 0 ? x(e) + 4 : x(e) - 4, yy + 9.5, size: 7.5, bold: true, color: col, align: e >= 0 ? 'l' : 'r');
            cv.text('${r.$2.pts} pts · ${r.$2.errors} err · ${r.$2.total} tot', 523 - 2, yy + 9.5, size: 7, color: cGrey, align: 'r');
          }
        }),
      ]));

  doc.addPage(section(() => [
        h2('Recepción por jugador'),
        para('Cada barra suma 100 % de las recepciones del jugador, con los mismos colores que los botones de calificación '
            'de la app. A la derecha, la efectividad actual de la planilla: (PP + P) / total.', size: 9),
        for (final r in recep)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(children: [
              pw.SizedBox(width: 60, child: tx(r.$1, bold: true)),
              stackedBar(380, 15, [for (var i = 0; i < 6; i++) ('', r.$2[i], recColors[i])], showPct: true),
              pw.SizedBox(width: 8),
              tx('${((r.$2[0] + r.$2[1]) / r.$2.reduce((a, c) => a + c) * 100).round()}%', bold: true, color: cPP),
              pw.SizedBox(width: 4),
              tx('(${r.$2.reduce((a, c) => a + c)})', size: 7.5, color: cGrey),
            ]),
          ),
        pw.Wrap(spacing: 10, children: [
          swatch(cPP, 'PP'), swatch(cP, 'P'), swatch(cExcl, '!'), swatch(cN, 'N'), swatch(cVneg, 'V-'), swatch(cNN, 'NN'),
        ]),
        h2('Mapa de calor de destino (ataque + contra del equipo)'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          Draw(220, 220 / (1 + 2 * _mx) * (1 + _mt) + 14, (cv) {
            final m = CourtMap(0, 0, 220);
            drawCourt(cv, m, ownHalf: false, heat: {for (final z in zoneCount.keys) z: zoneCount[z]! / maxZ});
            const cells = {1: [0, 0], 6: [1, 0], 5: [2, 0], 2: [0, 1], 3: [1, 1], 4: [2, 1]};
            cells.forEach((z, c) {
              final cx = m.px((c[0] + 0.5) / 3);
              final cy = c[1] == 0 ? m.py(1 / 6) : m.py(5 / 12);
              final strong = zoneCount[z]! / maxZ > 0.55;
              final col = strong ? cWhite : cNavy;
              cv.text('Z$z', cx, cy - 8, size: 7, color: col, align: 'c');
              cv.text('${zoneCount[z]}', cx, cy + 5, size: 14, bold: true, color: col, align: 'c');
              final pct = zoneCount[z] == 0 ? 0 : (zonePts[z]! / zoneCount[z]! * 100).round();
              cv.text('$pct% pto', cx, cy + 15, size: 6.5, color: col, align: 'c');
            });
          }),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              para('Son los datos de las tablas "Ataque por zona" que ya trae el PDF, pintados sobre la cancha: cuanto más '
                  'oscuro, más pelotas fueron a esa zona. Debajo de la cantidad va el % que terminó en punto.', size: 8.8),
              para('Sirve para ver de un vistazo si el equipo es previsible (todo a la misma zona) y para comparar con el '
                  'scouting del rival.', size: 8.8),
              tx('Se puede hacer hoy, con la zona que ya se registra, y también por jugador.', size: 8, color: cGrey),
            ]),
          ),
        ]),
        h2('Tablero rápido del partido'),
        para('Una fila de indicadores arriba de la pestaña Gráficos, para el vistazo del entretiempo entre sets:', size: 9),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          kpi('56%', 'Side-out', 'rallies ganados recibiendo', cNavy),
          kpi('39%', 'Break-point', 'rallies ganados sacando', cCyan),
          kpi('+24%', 'Eficiencia de ataque', '(pts − err) / total', cPP),
          kpi('12', 'Errores no forzados', 'saque + ataque + genérico', cNN),
        ]),
        pw.SizedBox(height: 10),
        callout('Otras ideas para una segunda tanda',
            '• Comparación entre sets (small multiples de los mismos gráficos, uno por set).\n'
            '• Ataque según la calidad de la recepción previa: % de punto con recepción PP vs. N.\n'
            '• Evolución de un jugador a lo largo de varios partidos del archivo (tendencia de eficiencia).\n'
            '• Cruce con el scouting del rival: sus zonas débiles de recepción contra nuestras zonas de saque.'),
      ]));

  // ======================== 8. PLAN ========================
  pw.Widget cx(String s) => tx(s, size: 8);
  doc.addPage(section(() => [
        h1('8', 'Plan de implementación por etapas'),
        para('Cada etapa entrega algo usable por sí sola y la carga en vivo se toca recién al final. Decidido: se arranca por la etapa 1.'),
        table(
          ['Etapa', 'Qué incluye', 'Archivos principales', 'Esfuerzo'],
          [
            [
              tx('1 · Gráficos de equipo', bold: true, size: 8),
              cx('Pestaña "Gráficos": rotaciones P1–P6 (tabla + barras), side-out/break, evolución del marcador, origen de puntos, eficiencia de ataque, recepción, mapa de calor, tablero rápido. Mismo contenido en el PDF del partido.'),
              cx('stats_engine.dart (computeRotations, computeTimeline)\nmatch_summary_screen.dart (pestañas)\npdf_report_service.dart\nwidgets/charts/ (nuevos CustomPainter)'),
              cx('Medio'),
            ],
            [
              tx('2 · Mapas con datos de hoy', bold: true, size: 8),
              cx('Pestaña "Mapas" y planilla por jugador en el PDF, con origen deducido y destino en el centro de la zona. NN se dibuja como "error" genérico. Funciona con partidos ya guardados que tengan zona.'),
              cx('stats_engine.dart (computeShots)\nwidgets/charts/court_shots_painter.dart\npdf_report_service.dart'),
              cx('Medio'),
            ],
            [
              tx('3 · Carga precisa', bold: true, size: 8),
              cx('Cancha tocable en vez de la grilla: destino exacto + afuera/red automático, y origen con un segundo toque opcional en la mitad propia. Migración en fromJson para los partidos viejos. Los mapas pasan a verse exactos en los partidos nuevos.'),
              cx('rally_event.dart (targetX/Y, originX/Y, missType)\nhit_zone_picker.dart\ntouch_dialog.dart / match_controller.dart\ntest/match_controller_test.dart'),
              cx('Medio-bajo'),
            ],
            [
              tx('4 · Cierre', bold: true, size: 8),
              cx('Manual de usuario (sección Resumen/Estadísticas + Zona de destino), README, flutter analyze, builds según el proceso de release.'),
              cx('tool/generate_manual.dart\nREADME.md'),
              cx('Bajo'),
            ],
          ],
          widths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(3.6), 2: const pw.FlexColumnWidth(2.6), 3: const pw.FlexColumnWidth(0.9)},
        ),
        h2('Decisiones técnicas'),
        bullet([b('Sin librería de gráficos nueva. '), plain('Todo se dibuja con CustomPainter, igual que la pizarra (WhiteboardPainter). La geometría (escalas, posiciones, trazos) va en una clase de Dart puro compartida entre la pantalla y el PDF, así los dos se ven igual. Este documento está generado con package:pdf, la misma librería que usa la app, así que todos los trazos que aparecen acá se pueden dibujar en el reporte real.')], size: 8.8),
        bullet([b('Premium. '), plain('Mapas y Gráficos viven dentro de la pantalla de Estadísticas, así que heredan el mismo control premium que ya tiene (incluida la estadística gratis de prueba), sin lógica nueva de suscripción.')], size: 8.8),
        bullet([b('Rendimiento. '), plain('Un partido tiene unos pocos cientos de eventos: calcular todo al abrir la pantalla es instantáneo, no hace falta caché.')], size: 8.8),
        h2('Decisiones tomadas (29/09/2026)'),
        table(
          ['Pregunta', 'Decisión', 'Qué implica'],
          [
            [cx('¿Distinguir afuera y red dentro de NN?'), tx('Sí, deducido del toque en la cancha', size: 8, bold: true), cx('Tocar en el margen = afuera; sobre la red = red. Sin pasos extra en la carga.')],
            [cx('¿Origen deducido o tocado?'), tx('Deducido + segundo toque opcional', size: 8, bold: true), cx('Por defecto se deduce por puesto y rotación; tocar la mitad propia lo fija a mano.')],
            [cx('¿Bloqueado y red como trazos propios?'), tx('Sí, 5 trazos', size: 8, bold: true), cx('Punto, adentro, afuera, bloqueado y red. Sin dato de afuera/red, NN usa un trazo de "error" genérico.')],
            [cx('¿Vista por defecto en la pestaña?'), tx('Mapa con resumen', size: 8, bold: true), cx('"Ver como tabla" queda a un toque.')],
            [cx('¿Por dónde arrancar?'), tx('Etapa 1 (gráficos de equipo)', size: 8, bold: true), cx('Después, etapa 2 (mapas con datos de hoy) y etapa 3 (carga precisa).')],
          ],
          widths: {0: const pw.FlexColumnWidth(2.2), 1: const pw.FlexColumnWidth(2.2), 2: const pw.FlexColumnWidth(3)},
        ),
        pw.SizedBox(height: 6),
        tx('Spec implementable: documents/spec-estadistica-visual.md (en el repo de la app).', size: 8, color: cGrey),
      ]));

  final bytes = await doc.save();
  File(outPath).writeAsBytesSync(bytes);
  final o = set1.split('').where((c) => c == 'O').length;
  stdout.writeln('OK -> $outPath (${bytes.length} bytes). Set1 $o-${set1.length - o}');
}