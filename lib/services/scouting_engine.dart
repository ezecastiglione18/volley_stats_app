import '../models/rally_event.dart';
import '../models/stat_line.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

/// Estadística agregada de TODOS los partidos jugados contra un mismo
/// rival (identificado por `VolleyMatch.rivalTeamName`), para tener un
/// scouting armado solo con lo que ya se cargó, sin releer partido por
/// partido.
class RivalScoutingReport {
  final String rivalName;

  /// Partidos contra este rival, más nuevo primero.
  final List<VolleyMatch> matches;

  final int matchesWon;
  final int matchesLost;

  /// Errores del rival (que nos dan el punto), sumados en todos los sets de
  /// todos los partidos contra este rival.
  final RivalErrorStats errors;

  /// Puntos que el rival ganó con su propio toque (ataque/contra), sumados
  /// igual que [errors].
  final RivalPointStats points;

  /// Cuántos sets, por número de set (1, 2, 3...), se ganaron o perdieron
  /// contra este rival — para notar si el rival mejora o se cae en sets
  /// avanzados (o si nosotros lo hacemos).
  final Map<int, int> setsWonBySetNumber;
  final Map<int, int> setsLostBySetNumber;

  RivalScoutingReport({
    required this.rivalName,
    required this.matches,
    required this.matchesWon,
    required this.matchesLost,
    required this.errors,
    required this.points,
    required this.setsWonBySetNumber,
    required this.setsLostBySetNumber,
  });

  int get matchesPlayed => matches.length;

  /// Toque que más punto le dio al rival contra nosotros (para saber qué
  /// reforzar en la práctica: defensa de ataque, de contra, o presión de
  /// saque para forzar más errores).
  String get rivalStrongestWeapon {
    if (points.attack >= points.counter && points.attack > 0) return 'Ataque';
    if (points.counter > 0) return 'Contraataque';
    return 'Sin datos suficientes';
  }

  /// Tipo de error más frecuente del rival (para saber dónde presionar).
  String get rivalWeakestSpot {
    final entries = <MapEntry<String, int>>[
      MapEntry('Saque', errors.serve),
      MapEntry('Ataque', errors.attack),
      MapEntry('Contraataque', errors.counter),
      MapEntry('Genérico', errors.generic),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.value == 0 ? 'Sin datos suficientes' : entries.first.key;
  }
}

class ScoutingEngine {
  /// Nombres de rivales con al menos un partido cargado, ordenados por
  /// cantidad de partidos jugados (más enfrentado primero) y, a igualdad,
  /// alfabéticamente.
  static List<String> rivalNames(List<VolleyMatch> matches) {
    final counts = <String, int>{};
    for (final m in matches) {
      final name = m.rivalTeamName.trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return names;
  }

  static RivalScoutingReport buildReport(String rivalName, List<VolleyMatch> allMatches) {
    final matches = allMatches.where((m) => m.rivalTeamName.trim() == rivalName).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final errors = RivalErrorStats();
    final points = RivalPointStats();
    final setsWon = <int, int>{};
    final setsLost = <int, int>{};
    var matchesWon = 0;
    var matchesLost = 0;

    for (final match in matches) {
      final stats = StatsEngine.compute(match);
      errors.serve += stats.rivalErrors.serve;
      errors.attack += stats.rivalErrors.attack;
      errors.counter += stats.rivalErrors.counter;
      errors.generic += stats.rivalErrors.generic;
      points.attack += stats.rivalPoints.attack;
      points.counter += stats.rivalPoints.counter;
      points.unclassified += stats.rivalPoints.unclassified;

      if (match.status == MatchStatus.finished) {
        if (match.ownSetsWon > match.rivalSetsWon) {
          matchesWon++;
        } else if (match.rivalSetsWon > match.ownSetsWon) {
          matchesLost++;
        }
      }
      for (final set in match.sets) {
        if (!set.finished || set.winner == null) continue;
        final map = set.winner == TeamSide.own ? setsWon : setsLost;
        map[set.setNumber] = (map[set.setNumber] ?? 0) + 1;
      }
    }

    return RivalScoutingReport(
      rivalName: rivalName,
      matches: matches,
      matchesWon: matchesWon,
      matchesLost: matchesLost,
      errors: errors,
      points: points,
      setsWonBySetNumber: setsWon,
      setsLostBySetNumber: setsLost,
    );
  }
}
