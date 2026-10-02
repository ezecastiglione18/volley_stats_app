import 'dart:math' as math;

/// Geometría de la cancha "compacta" de los mapas de dirección (ver
/// documents/spec-estadistica-visual.md, sección 5.1). Dart puro: la usan
/// tanto el `CustomPainter` de la pantalla como el PDF, para que los dos se
/// vean igual.
///
/// Coordenadas de cancha normalizadas, vista desde el banco propio mirando
/// al rival: `x` 0.0 = lateral izquierda, 1.0 = derecha (9 m); `y` 0.0 =
/// fondo rival, 0.5 = red, 1.0 = fondo propio (18 m). Fuera de 0..1 = fuera
/// de la cancha. La mitad rival se dibuja a escala real (cuadrada) y la
/// propia comprimida al 50 %, porque de ese lado solo interesa el origen.
class CourtGeometry {
  CourtGeometry(this.width) : courtWidth = width / (1 + 2 * marginSide);

  /// Márgenes de "afuera", como fracción del ancho de la cancha.
  static const marginSide = 0.12;
  static const marginTop = 0.17;
  static const marginBottom = 0.15;

  /// Alto total del dibujo para un ancho dado.
  static double heightForWidth(double width) =>
      width / (1 + 2 * marginSide) * (1.5 + marginTop + marginBottom);

  final double width;

  /// Ancho de la cancha en sí (sin márgenes), en las mismas unidades.
  final double courtWidth;

  double get height => courtWidth * (1.5 + marginTop + marginBottom);

  /// Coordenada horizontal de dibujo para una `x` de cancha.
  double px(double x) => marginSide * courtWidth + x * courtWidth;

  /// Coordenada vertical de dibujo (hacia abajo) para una `y` de cancha.
  double py(double y) {
    final top = marginTop * courtWidth;
    if (y <= 0.5) return top + (y / 0.5) * courtWidth;
    return top + courtWidth + ((y - 0.5) / 0.5) * 0.5 * courtWidth;
  }
}

/// Distancia de un punto (px, py) al segmento a-b.
double distanceToSegment(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
