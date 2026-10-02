import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/visual_stats.dart';
import '../../utils/theme.dart';

/// Colores "de dato" de la estadística visual. Son los mismos en modo claro y
/// oscuro (coinciden con los botones de calificación de `grade_labels.dart`);
/// lo que cambia según el tema es la grilla, los ejes y el texto, que se
/// toman del `ColorScheme` en [ChartPalette.of].
const kChartPositive = Color(0xFF1E88E5); // PP
const kChartPositiveLight = Color(0xFF64B5F6); // P
const kChartNegative = Color(0xFFE64A3B); // NN
const kChartWarning = Color(0xFFFFB74D); // N
const kChartSold = Color(0xFFFF8A65); // V-
const kChartExcl = Color(0xFF9CCC65); // !
const kChartBlock = Color(0xFFE39A12);
const kChartNeutral = Color(0xFF9CA3AF);

class ChartPalette {
  const ChartPalette({
    required this.positive,
    required this.negative,
    required this.sideOut,
    required this.breakPoint,
    required this.slate,
    required this.grid,
    required this.zeroLine,
    required this.text,
    required this.textMuted,
    required this.courtFill,
    required this.courtLine,
    required this.net,
    this.fontFamily,
  });

  /// Fuente del tema: el texto que dibuja un `CustomPainter` con
  /// `TextPainter` no hereda el `DefaultTextStyle` de la app, hay que
  /// pasársela a mano para que los gráficos usen la misma tipografía.
  final String? fontFamily;

  /// Estilo de texto para dibujar dentro de un gráfico, con la fuente del tema.
  TextStyle label({double? fontSize, FontWeight? fontWeight, Color? color}) =>
      TextStyle(fontFamily: fontFamily, fontSize: fontSize, fontWeight: fontWeight, color: color);

  final Color positive;
  final Color negative;
  final Color sideOut;
  final Color breakPoint;

  /// Gris pizarra para "punto directo rival" y similares (más claro en modo
  /// oscuro para que no se pierda contra el fondo).
  final Color slate;
  final Color grid;
  final Color zeroLine;
  final Color text;
  final Color textMuted;
  final Color courtFill;
  final Color courtLine;
  final Color net;

  factory ChartPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ChartPalette(
      positive: kChartPositive,
      negative: kChartNegative,
      sideOut: dark ? AppColors.accentDark : AppColors.primaryLight,
      breakPoint: dark ? const Color(0xFFF5B84D) : AppColors.accentLight,
      slate: dark ? const Color(0xFF7C8B9C) : const Color(0xFF475569),
      grid: scheme.outline,
      zeroLine: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      text: scheme.onSurface,
      textMuted: scheme.onSurfaceVariant,
      courtFill: dark ? const Color(0xFF1E2C3A) : const Color(0xFFE8F1FA),
      courtLine: dark ? const Color(0xFF4B5A6B) : const Color(0xFF9CA3AF),
      net: dark ? AppColors.textDark : AppColors.primaryLight,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
  }

  /// Color de cada categoría del gráfico "Origen de los puntos".
  Color categoryColor(RallyCategory c) {
    switch (c) {
      case RallyCategory.attackPoint:
        return kChartPositive;
      case RallyCategory.counterPoint:
        return kChartPositiveLight;
      case RallyCategory.blockPoint:
        return sideOut;
      case RallyCategory.servePoint:
        return AppColors.accentLight;
      case RallyCategory.rivalError:
      case RallyCategory.otherWon:
        return kChartNeutral;
      case RallyCategory.attackError:
      case RallyCategory.attackBlocked:
        return kChartNegative;
      case RallyCategory.serveError:
        return kChartSold;
      case RallyCategory.receptionError:
        return kChartWarning;
      case RallyCategory.genericError:
      case RallyCategory.otherLost:
        return kChartBlock;
      case RallyCategory.rivalPoint:
        return slate;
    }
  }
}

/// Dibuja [text] con su ancla en [at]: [align] decide si [at] es el borde
/// izquierdo, el centro o el borde derecho del texto, y [at].dy es el centro
/// vertical. Si se pasa [maxWidth], el texto se corta con "…".
void paintChartText(
  Canvas canvas,
  String text,
  Offset at, {
  required TextStyle style,
  TextAlign align = TextAlign.left,
  double? maxWidth,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxWidth == null ? null : '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  final dx = switch (align) {
    TextAlign.center => -tp.width / 2,
    TextAlign.right || TextAlign.end => -tp.width,
    _ => 0.0,
  };
  tp.paint(canvas, at + Offset(dx, -tp.height / 2));
}

double measureChartText(String text, TextStyle style) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)
    ..layout();
  return tp.width;
}

/// Paso "lindo" (1, 2, 3, 5, 10, ...) para una grilla de unas 4 divisiones
/// sobre un rango de [span] unidades enteras.
int niceIntStep(num span) {
  if (span <= 4) return 1;
  final raw = span / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toInt();
  for (final m in [1, 2, 3, 5, 10]) {
    if (m * mag >= raw) return m * mag;
  }
  return 10 * mag;
}

/// "+4", "0", "-3".
String signedInt(int v) => v > 0 ? '+$v' : '$v';

/// "+24%" / "-8%" a partir de una fracción.
String signedPct(double v) {
  final p = (v * 100).round();
  return p > 0 ? '+$p%' : '$p%';
}
