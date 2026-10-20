import '../../../models/play.dart';

/// Un trazo tal como hay que dibujarlo en un instante de la reproducción:
/// completo, o cortado en el punto proporcional si todavía se está
/// "dibujando". Las coordenadas siguen normalizadas (0.0–1.0), igual que en
/// [PlayStroke].
class PlaybackStroke {
  final PlayStroke source;
  final List<double> xs;
  final List<double> ys;

  /// true si el trazo ya se dibujó entero.
  final bool complete;

  const PlaybackStroke({
    required this.source,
    required this.xs,
    required this.ys,
    required this.complete,
  });

  /// La flecha de un trazo con `arrow == true` aparece recién cuando el
  /// trazo está completo (antes, la punta iría "adelantada" a medio camino).
  bool get showArrow => complete && source.arrow;
}

/// Cantidad total de puntos de [strokes]: es la unidad en la que se reparte
/// el progreso y la que define cuánto dura la animación.
int totalPoints(List<PlayStroke> strokes) =>
    strokes.fold(0, (sum, s) => sum + s.pointsX.length);

/// Qué dibujar cuando la reproducción va por [progress] (0 a 1).
///
/// El progreso se reparte por cantidad total de puntos, no por trazo: con N
/// puntos en total, a `progress` le corresponden `progress * N` puntos. Los
/// trazos se completan en orden; el que está en curso se corta en el punto
/// proporcional (interpolando entre dos puntos consecutivos para que el
/// avance sea suave y no a saltos). Solo se devuelven los trazos que ya
/// empezaron; los que faltan no aparecen.
List<PlaybackStroke> visibleStrokes(List<PlayStroke> strokes, double progress) {
  final total = totalPoints(strokes);
  if (total == 0) return const [];

  final p = progress.clamp(0.0, 1.0).toDouble();
  final budget = p * total; // cuántos puntos "alcanzan" para dibujar
  final out = <PlaybackStroke>[];
  var consumed = 0;

  for (final stroke in strokes) {
    final len = stroke.pointsX.length;
    final local = budget - consumed;
    if (local <= 0) break; // este trazo (y los siguientes) todavía no empezó
    consumed += len;

    if (local >= len) {
      out.add(PlaybackStroke(
        source: stroke,
        xs: stroke.pointsX,
        ys: stroke.pointsY,
        complete: true,
      ));
      continue;
    }

    // Trazo en curso: los primeros k puntos enteros + uno interpolado.
    final k = local.floor();
    final f = local - k;
    final xs = stroke.pointsX.sublist(0, k);
    final ys = stroke.pointsY.sublist(0, k);
    if (f > 0 && k >= 1 && k < len) {
      final x0 = stroke.pointsX[k - 1];
      final y0 = stroke.pointsY[k - 1];
      xs.add(x0 + (stroke.pointsX[k] - x0) * f);
      ys.add(y0 + (stroke.pointsY[k] - y0) * f);
    }
    out.add(PlaybackStroke(source: stroke, xs: xs, ys: ys, complete: false));
    break; // los que siguen todavía no empezaron
  }
  return out;
}

/// Duración de la reproducción a velocidad 1×: 8 ms por punto, acotada entre
/// 2 y 12 segundos (una jugada muy corta no tiene que pasar en un parpadeo
/// ni una muy larga volverse eterna).
Duration playbackDuration(int totalPoints) {
  final ms = (totalPoints * 8).clamp(2000, 12000).toInt();
  return Duration(milliseconds: ms);
}
