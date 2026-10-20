import 'package:flutter/material.dart' show DateTimeRange;

import '../models/stat_line.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

/// Estadística acumulada de un equipo a lo largo de varios partidos (una
/// "temporada" o el recorte que elijan los filtros), sumando partido por
/// partido lo que ya calcula [StatsEngine]. Es solo lectura sobre el archivo:
/// no hay nada que se cargue aparte.
class SeasonReport {
  /// Partidos terminados que entraron en el recorte, del más nuevo al más
  /// viejo.
  final List<VolleyMatch> matches;
  final int matchesWon;
  final int matchesLost;
  final int setsFor;
  final int setsAgainst;

  /// Una fila por jugador (más "No Asignado" si hubo), con los conteos
  /// sumados de todos los partidos. Ordenadas por dorsal, "No Asignado" al
  /// final (igual que la tabla de un partido).
  final List<PlayerStatLine> rows;

  /// Fila "TOTAL EQUIPO": la suma de las filas de equipo de cada partido.
  final PlayerStatLine total;

  /// En cuántos partidos del recorte figura cada jugador (clave = playerId):
  /// los partidos donde tuvo al menos una acción cargada.
  final Map<String, int> matchesPlayed;

  SeasonReport({
    required this.matches,
    required this.matchesWon,
    required this.matchesLost,
    required this.setsFor,
    required this.setsAgainst,
    required this.rows,
    required this.total,
    required this.matchesPlayed,
  });

  int get matchesCount => matches.length;
  bool get isEmpty => matches.isEmpty;
}

/// Una opción del filtro de equipo: [key] es lo que se le pasa a
/// [SeasonEngine.buildSeason] y [label] lo que se muestra.
class SeasonTeamOption {
  final String key;
  final String label;
  const SeasonTeamOption(this.key, this.label);
}

class SeasonEngine {
  /// Clave que identifica "el mismo equipo" entre partidos: el id del equipo
  /// cargado en "Equipos" (`ownTeamSourceId`) o, en los partidos que se
  /// armaron sin elegir uno, el nombre escrito a mano.
  static String teamKeyOf(VolleyMatch m) {
    final id = m.ownTeamSourceId;
    return id != null && id.isNotEmpty ? id : 'name:${m.ownTeamName}';
  }

  /// Equipos distintos que aparecen en [all] (solo partidos terminados),
  /// ordenados por nombre. El nombre mostrado es el del partido más reciente
  /// de ese equipo.
  static List<SeasonTeamOption> teamOptions(List<VolleyMatch> all) {
    final latest = <String, VolleyMatch>{};
    for (final m in all) {
      if (m.status != MatchStatus.finished) continue;
      final key = teamKeyOf(m);
      final current = latest[key];
      if (current == null || m.date.isAfter(current.date)) latest[key] = m;
    }
    final options = [
      for (final e in latest.entries) SeasonTeamOption(e.key, e.value.ownTeamName),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  /// Torneos distintos (no vacíos) de los partidos terminados de [teamKey],
  /// ordenados alfabéticamente.
  static List<String> tournaments(List<VolleyMatch> all, {required String teamKey}) {
    final set = <String>{
      for (final m in all)
        if (m.status == MatchStatus.finished &&
            teamKeyOf(m) == teamKey &&
            m.tournament.trim().isNotEmpty)
          m.tournament.trim(),
    };
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Arma el reporte de temporada de [teamKey] con los partidos terminados de
  /// [all], opcionalmente recortados por [tournament] y por un rango de fechas
  /// [range] (inclusive, comparando solo el día).
  ///
  /// Los porcentajes de la tabla salen de los conteos sumados (los calcula
  /// la propia tabla a partir de PP/P/N/...), nunca promediando porcentajes
  /// de cada partido. Nombre, dorsal y posición de cada jugador son los del
  /// partido más reciente en el que figura.
  static SeasonReport buildSeason(
    List<VolleyMatch> all, {
    required String teamKey,
    String? tournament,
    DateTimeRange? range,
  }) {
    final matches = all.where((m) {
      if (m.status != MatchStatus.finished) return false;
      if (teamKeyOf(m) != teamKey) return false;
      if (tournament != null && m.tournament.trim() != tournament) return false;
      if (range != null) {
        final day = DateTime(m.date.year, m.date.month, m.date.day);
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // más nuevo primero

    final total = PlayerStatLine(playerId: 'team', displayName: 'Total Equipo', number: -1);
    final byPlayer = <String, PlayerStatLine>{};
    final played = <String, int>{};
    var won = 0;
    var lost = 0;
    var setsFor = 0;
    var setsAgainst = 0;

    for (final match in matches) {
      final stats = StatsEngine.compute(match);

      if (match.ownSetsWon > match.rivalSetsWon) {
        won++;
      } else if (match.rivalSetsWon > match.ownSetsWon) {
        lost++;
      }
      setsFor += match.ownSetsWon;
      setsAgainst += match.rivalSetsWon;

      _add(total, stats.team);

      for (final line in stats.byPlayer.values) {
        played[line.playerId] = (played[line.playerId] ?? 0) + 1;
        // Como los partidos vienen del más nuevo al más viejo, la primera
        // vez que aparece un jugador es en su partido más reciente: de ahí
        // salen nombre, dorsal y posición.
        final acc = byPlayer.putIfAbsent(
          line.playerId,
          () => PlayerStatLine(
            playerId: line.playerId,
            displayName: line.displayName,
            number: line.number,
            position: line.position,
          ),
        );
        _add(acc, line);
      }
    }

    final rows = byPlayer.values.where((r) => r.playerId != unassignedId).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final unassigned = byPlayer[unassignedId];
    if (unassigned != null) rows.add(unassigned);

    return SeasonReport(
      matches: matches,
      matchesWon: won,
      matchesLost: lost,
      setsFor: setsFor,
      setsAgainst: setsAgainst,
      rows: rows,
      total: total,
      matchesPlayed: played,
    );
  }

  static void _add(PlayerStatLine target, PlayerStatLine src) {
    target.saque.addFrom(src.saque);
    target.ataque.addFrom(src.ataque);
    target.contra.addFrom(src.contra);
    target.recepcion.addFrom(src.recepcion);
    target.bloqueoPts += src.bloqueoPts;
    target.errGen += src.errGen;
    target.yellowCards += src.yellowCards;
    target.redCards += src.redCards;
  }
}
