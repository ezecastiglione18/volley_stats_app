import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/stat_line.dart';
import '../models/volley_match.dart';

const String unassignedId = '__no_asignado__';

class MatchStats {
  final Map<String, PlayerStatLine> byPlayer; // incluye fila "No Asignado"
  final PlayerStatLine team; // fila "Total Equipo"

  MatchStats({required this.byPlayer, required this.team});

  List<PlayerStatLine> get orderedRows {
    final rows = byPlayer.values.where((r) => r.playerId != unassignedId).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final unassigned = byPlayer[unassignedId];
    if (unassigned != null) rows.add(unassigned);
    return rows;
  }
}

class StatsEngine {
  /// Calcula las estadísticas agregadas de todo el partido (todos los sets)
  /// o, si [setNumber] se especifica, solo de ese set.
  static MatchStats compute(VolleyMatch match, {int? setNumber}) {
    final Map<String, PlayerStatLine> lines = {};

    PlayerStatLine lineFor(String playerId) {
      return lines.putIfAbsent(playerId, () {
        if (playerId == unassignedId) {
          return PlayerStatLine(
            playerId: unassignedId,
            displayName: 'No Asignado',
            number: 9999,
          );
        }
        final p = match.ownRoster.firstWhere(
          (pl) => pl.id == playerId,
          orElse: () => Player(
            id: playerId,
            firstName: '',
            lastName: '?',
            number: 0,
            position: PlayerPosition.puntaReceptor,
          ),
        );
        return PlayerStatLine(
          playerId: p.id,
          displayName: p.fullName,
          number: p.number,
        );
      });
    }

    final sets = setNumber == null
        ? match.sets
        : match.sets.where((s) => s.setNumber == setNumber).toList();

    for (final set in sets) {
      for (final ev in set.events) {
        if (ev.team != TeamSide.own) continue; // solo estadística propia
        _applyEvent(ev, lineFor);
      }
    }

    final team = PlayerStatLine(playerId: 'team', displayName: 'Total Equipo', number: -1);
    for (final l in lines.values) {
      _accumulate(team.saque, l.saque);
      _accumulate(team.ataque, l.ataque);
      _accumulate(team.contra, l.contra);
      team.bloqueoPts += l.bloqueoPts;
      team.errGen += l.errGen;
      _accumulateRecepcion(team.recepcion, l.recepcion);
    }

    return MatchStats(byPlayer: lines, team: team);
  }

  static void _applyEvent(RallyEvent ev, PlayerStatLine Function(String) lineFor) {
    switch (ev.phase) {
      case RallyPhase.serve:
        final line = lineFor(_singlePlayer(ev));
        _bumpTouch(line.saque, ev.grade);
        break;
      case RallyPhase.reception:
        final line = lineFor(_singlePlayer(ev));
        _bumpReception(line.recepcion, ev.grade);
        break;
      case RallyPhase.attack:
        final line = lineFor(_singlePlayer(ev));
        _bumpTouch(line.ataque, ev.grade);
        break;
      case RallyPhase.counter:
        final line = lineFor(_singlePlayer(ev));
        _bumpTouch(line.contra, ev.grade);
        break;
      case RallyPhase.block:
        final ids = ev.playerIds.isEmpty ? [unassignedId] : ev.playerIds;
        for (final id in ids) {
          lineFor(id).bloqueoPts += 1;
        }
        break;
      case RallyPhase.genericError:
        final id = ev.playerIds.isNotEmpty ? ev.playerIds.first : unassignedId;
        lineFor(id).errGen += 1;
        break;
      case RallyPhase.opponentPoint:
      case RallyPhase.opponentError:
        // No se atribuye a jugador propio.
        break;
    }
  }

  static String _singlePlayer(RallyEvent ev) =>
      ev.playerIds.isNotEmpty ? ev.playerIds.first : unassignedId;

  static void _bumpTouch(TouchStats stats, String? grade) {
    switch (grade) {
      case Grade.pp:
        stats.pp++;
        break;
      case Grade.p:
        stats.p++;
        break;
      case Grade.n:
        stats.n++;
        break;
      case Grade.nn:
        stats.nn++;
        break;
      case Grade.bloq:
        stats.bloq++;
        break;
    }
  }

  static void _bumpReception(ReceptionStats stats, String? grade) {
    switch (grade) {
      case Grade.pp:
        stats.pp++;
        break;
      case Grade.p:
        stats.p++;
        break;
      case Grade.excl:
        stats.excl++;
        break;
      case Grade.n:
        stats.n++;
        break;
      case Grade.vNeg:
        stats.vNeg++;
        break;
      case Grade.nn:
        stats.nn++;
        break;
    }
  }

  static void _accumulate(TouchStats target, TouchStats src) {
    target.pp += src.pp;
    target.p += src.p;
    target.n += src.n;
    target.nn += src.nn;
    target.bloq += src.bloq;
  }

  static void _accumulateRecepcion(ReceptionStats target, ReceptionStats src) {
    target.pp += src.pp;
    target.p += src.p;
    target.excl += src.excl;
    target.n += src.n;
    target.vNeg += src.vNeg;
    target.nn += src.nn;
  }
}
