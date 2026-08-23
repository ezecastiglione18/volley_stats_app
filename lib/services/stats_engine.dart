import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/sanction_event.dart';
import '../models/stat_line.dart';
import '../models/volley_match.dart';

const String unassignedId = '__no_asignado__';

class MatchStats {
  final Map<String, PlayerStatLine> byPlayer; // incluye fila "No Asignado"
  final PlayerStatLine team; // fila "Total Equipo"
  final RivalErrorStats rivalErrors;
  final RivalPointStats rivalPoints;
  final RivalSanctionStats rivalSanctions;

  MatchStats({
    required this.byPlayer,
    required this.team,
    required this.rivalErrors,
    required this.rivalPoints,
    required this.rivalSanctions,
  });

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
          position: p.position,
        );
      });
    }

    final sets = setNumber == null
        ? match.sets
        : match.sets.where((s) => s.setNumber == setNumber).toList();

    final rivalErrors = RivalErrorStats();
    final rivalPoints = RivalPointStats();
    final rivalSanctions = RivalSanctionStats();

    for (final set in sets) {
      for (final ev in set.events) {
        if (ev.team == TeamSide.own) {
          _applyEvent(ev, lineFor);
        } else if (ev.phase == RallyPhase.opponentError) {
          _bumpRivalError(rivalErrors, ev.rivalActionType);
        } else if (ev.phase == RallyPhase.opponentPoint) {
          _bumpRivalPoint(rivalPoints, ev.rivalActionType);
        }
      }
      for (final s in set.sanctions) {
        if (s.team == TeamSide.own) {
          // Un jugador puntual suma a su fila; una sanción al banco/cuerpo
          // técnico suma a "No Asignado" (igual que un Error General sin
          // jugador elegido), para que no quede afuera del total del equipo.
          final line = lineFor(s.targetKind == SanctionTargetKind.player && s.targetPlayerId != null
              ? s.targetPlayerId!
              : unassignedId);
          if (s.outcome.showsYellow) line.yellowCards++;
          if (s.outcome.showsRed) line.redCards++;
        } else {
          if (s.outcome.showsYellow) rivalSanctions.yellowCards++;
          if (s.outcome.showsRed) rivalSanctions.redCards++;
        }
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
      team.yellowCards += l.yellowCards;
      team.redCards += l.redCards;
    }

    return MatchStats(
      byPlayer: lines,
      team: team,
      rivalErrors: rivalErrors,
      rivalPoints: rivalPoints,
      rivalSanctions: rivalSanctions,
    );
  }

  static void _bumpRivalError(RivalErrorStats stats, String? rivalActionType) {
    switch (rivalActionType) {
      case RivalAction.serve:
        stats.serve++;
        break;
      case RivalAction.attack:
        stats.attack++;
        break;
      case RivalAction.counter:
        stats.counter++;
        break;
      default:
        stats.generic++; // null (partido viejo) o 'generic'.
    }
  }

  static void _bumpRivalPoint(RivalPointStats stats, String? rivalActionType) {
    switch (rivalActionType) {
      case RivalAction.attack:
        stats.attack++;
        break;
      case RivalAction.counter:
        stats.counter++;
        break;
      default:
        stats.unclassified++; // partido viejo, sin subtipo guardado.
    }
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
      case RallyPhase.sanction:
        // El punto ya se contabilizó en el marcador; el detalle de la
        // tarjeta (a quién, qué color) sale de MatchSet.sanctions, no de
        // este RallyEvent sintético.
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

  /// Calcula la estadística de saque y ataque por zona de destino (1-6),
  /// para todo el partido o, si [setNumber] se especifica, solo ese set.
  /// Solo cuenta toques propios que tienen zona registrada (el registro de
  /// zona es opcional y puede estar desactivado en algún set).
  static ZoneStats computeZones(VolleyMatch match, {int? setNumber}) {
    final serveByZone = {for (var z = 1; z <= 6; z++) z: TouchStats()};
    final attackByZone = {for (var z = 1; z <= 6; z++) z: TouchStats()};
    final counterByZone = {for (var z = 1; z <= 6; z++) z: TouchStats()};
    final serveByZoneByPlayer = <String, Map<int, TouchStats>>{};
    final attackByZoneByPlayer = <String, Map<int, TouchStats>>{};
    final counterByZoneByPlayer = <String, Map<int, TouchStats>>{};

    Map<int, TouchStats> zoneMapFor(
      Map<String, Map<int, TouchStats>> store,
      String playerId,
    ) =>
        store.putIfAbsent(playerId, () => {for (var z = 1; z <= 6; z++) z: TouchStats()});

    final sets = setNumber == null
        ? match.sets
        : match.sets.where((s) => s.setNumber == setNumber).toList();

    for (final set in sets) {
      for (final ev in set.events) {
        if (ev.team != TeamSide.own || ev.targetZone == null) continue;
        final zone = ev.targetZone!;
        if (zone < 1 || zone > 6) continue;
        final playerId = _singlePlayer(ev);
        if (ev.phase == RallyPhase.serve) {
          _bumpTouch(serveByZone[zone]!, ev.grade);
          _bumpTouch(zoneMapFor(serveByZoneByPlayer, playerId)[zone]!, ev.grade);
        } else if (ev.phase == RallyPhase.attack) {
          _bumpTouch(attackByZone[zone]!, ev.grade);
          _bumpTouch(zoneMapFor(attackByZoneByPlayer, playerId)[zone]!, ev.grade);
        } else if (ev.phase == RallyPhase.counter) {
          _bumpTouch(counterByZone[zone]!, ev.grade);
          _bumpTouch(zoneMapFor(counterByZoneByPlayer, playerId)[zone]!, ev.grade);
        }
      }
    }

    return ZoneStats(
      serveByZone: serveByZone,
      attackByZone: attackByZone,
      counterByZone: counterByZone,
      serveByZoneByPlayer: serveByZoneByPlayer,
      attackByZoneByPlayer: attackByZoneByPlayer,
      counterByZoneByPlayer: counterByZoneByPlayer,
    );
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
