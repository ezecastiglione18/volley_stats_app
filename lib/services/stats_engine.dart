import 'dart:math' as math;

import '../models/match_set.dart';
import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/sanction_event.dart';
import '../models/stat_line.dart';
import '../models/visual_stats.dart';
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

    // Precarga una fila por cada jugador del roster, así los que no
    // tocaron ningún punto igual aparecen en la estadística (con todo en
    // cero) en vez de quedar afuera.
    for (final p in match.ownRoster) {
      lineFor(p.id);
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

  /// Calcula la estadística de saque y ataque por zona de destino (1-9: las
  /// zonas 7-9 solo aparecen en sets cargados con "9 zonas"), para todo el
  /// partido o, si [setNumber] se especifica, solo ese set. Solo cuenta
  /// toques propios que tienen zona registrada (el registro de zona es
  /// opcional y puede estar desactivado en algún set).
  static ZoneStats computeZones(VolleyMatch match, {int? setNumber}) {
    final serveByZone = {for (var z = 1; z <= 9; z++) z: TouchStats()};
    final attackByZone = {for (var z = 1; z <= 9; z++) z: TouchStats()};
    final counterByZone = {for (var z = 1; z <= 9; z++) z: TouchStats()};
    final serveByZoneByPlayer = <String, Map<int, TouchStats>>{};
    final attackByZoneByPlayer = <String, Map<int, TouchStats>>{};
    final counterByZoneByPlayer = <String, Map<int, TouchStats>>{};

    Map<int, TouchStats> zoneMapFor(
      Map<String, Map<int, TouchStats>> store,
      String playerId,
    ) =>
        store.putIfAbsent(playerId, () => {for (var z = 1; z <= 9; z++) z: TouchStats()});

    final sets = setNumber == null
        ? match.sets
        : match.sets.where((s) => s.setNumber == setNumber).toList();

    for (final set in sets) {
      for (final ev in set.events) {
        if (ev.team != TeamSide.own || ev.targetZone == null) continue;
        final zone = ev.targetZone!;
        if (zone < 1 || zone > 9) continue;
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

  // ---------------- Estadística visual (pestaña "Gráficos") ----------------
  //
  // Reglas completas en documents/spec-estadistica-visual.md (secciones 3 y 4).

  static List<MatchSet> _selectedSets(VolleyMatch match, int? setNumber) =>
      setNumber == null ? match.sets : match.sets.where((s) => s.setNumber == setNumber).toList();

  static bool _isClosing(RallyEvent ev) => ev.endsRally && ev.pointWinner != null;

  /// Clasifica un rally por su evento de cierre (spec 3.3).
  static RallyCategory classifyClosing(RallyEvent ev) {
    switch (ev.phase) {
      case RallyPhase.serve:
        if (ev.grade == Grade.pp) return RallyCategory.servePoint;
        if (ev.grade == Grade.nn) return RallyCategory.serveError;
        break;
      case RallyPhase.reception:
        if (ev.grade == Grade.nn) return RallyCategory.receptionError;
        break;
      case RallyPhase.attack:
      case RallyPhase.counter:
        if (ev.grade == Grade.pp) {
          return ev.phase == RallyPhase.attack ? RallyCategory.attackPoint : RallyCategory.counterPoint;
        }
        if (ev.grade == Grade.nn) return RallyCategory.attackError;
        if (ev.grade == Grade.bloq) return RallyCategory.attackBlocked;
        break;
      case RallyPhase.block:
        return RallyCategory.blockPoint;
      case RallyPhase.genericError:
        return RallyCategory.genericError;
      case RallyPhase.opponentPoint:
        return RallyCategory.rivalPoint;
      case RallyPhase.opponentError:
        return RallyCategory.rivalError;
      case RallyPhase.sanction:
        // Sanción con punto: si el punto es propio, sancionaron al rival
        // (cuenta como error rival); si no, al equipo propio.
        return ev.pointWinner == TeamSide.own ? RallyCategory.rivalError : RallyCategory.genericError;
    }
    assert(false, 'Evento de cierre sin categoría: ${ev.phase.name} ${ev.grade}');
    return ev.pointWinner == TeamSide.own ? RallyCategory.otherWon : RallyCategory.otherLost;
  }

  /// Rallies cerrados de un set, en orden, cada uno con la rotación propia
  /// vigente mientras se jugó (offset 0..5, misma unidad que
  /// `MatchController._rotationOffsetOwn`). A diferencia de
  /// `MatchController.resume` (que solo necesita la rotación final y suma
  /// las rotaciones manuales al final), acá cada rotación manual se aplica
  /// recién a partir del rally en el que se hizo.
  static List<({RallyEvent event, int offset})> _replayRotations(MatchSet set) {
    final manual = [...set.manualRotations]..sort((a, b) => a.rallyNumber.compareTo(b.rallyNumber));
    var nextManual = 0;
    var offset = 0;
    var serving = set.startingServer;
    final out = <({RallyEvent event, int offset})>[];
    for (final ev in set.events) {
      if (!_isClosing(ev)) continue;
      while (nextManual < manual.length && manual[nextManual].rallyNumber <= ev.rallyNumber) {
        offset = ((offset + manual[nextManual].steps) % 6 + 6) % 6;
        nextManual++;
      }
      out.add((event: ev, offset: offset));
      if (ev.pointWinner != serving) {
        if (ev.pointWinner == TeamSide.own) offset = (offset + 1) % 6;
        serving = ev.pointWinner!;
      }
    }
    return out;
  }

  /// Índice en `startingOrderOwn` del único armador de la formación inicial
  /// del set, o null si no hay ninguno o hay más de uno.
  static int? _setterSlot(VolleyMatch match, MatchSet set) {
    final positions = {for (final p in match.ownRoster) p.id: p.position};
    int? slot;
    for (var i = 0; i < set.startingOrderOwn.length; i++) {
      if (positions[set.startingOrderOwn[i]] == PlayerPosition.armador) {
        if (slot != null) return null;
        slot = i;
      }
    }
    return slot;
  }

  /// Rendimiento por rotación (spec 3.2 y 3.3). La rotación se etiqueta por
  /// la posición en cancha del armador (P1 = armador en zona 1); los sets
  /// sin un armador identificable van aparte, como R1..R6.
  static RotationStats computeRotations(VolleyMatch match, {int? setNumber}) {
    final setterRows = [for (var p = 1; p <= 6; p++) RotationRow('P$p')];
    final fallbackRows = [for (var r = 1; r <= 6; r++) RotationRow('R$r')];
    final fallbackSets = <int>[];
    final total = RotationRow('Total');

    for (final set in _selectedSets(match, setNumber)) {
      final slot = _setterSlot(match, set);
      final rallies = _replayRotations(set);
      if (slot == null && rallies.isNotEmpty) fallbackSets.add(set.setNumber);
      for (final r in rallies) {
        final ev = r.event;
        final category = classifyClosing(ev);
        final row = slot == null ? fallbackRows[r.offset] : setterRows[((slot - r.offset) % 6 + 6) % 6];
        row.add(category, serving: ev.servingTeamBefore, winner: ev.pointWinner!);
        total.add(category, serving: ev.servingTeamBefore, winner: ev.pointWinner!);
      }
    }

    return RotationStats(
      setterRows: setterRows,
      fallbackRows: fallbackRows,
      fallbackSets: fallbackSets,
      total: total,
    );
  }

  /// Evolución del marcador de cada set de la selección (spec 3.4). Los
  /// sets sin ningún rally cerrado no se incluyen.
  static List<SetTimeline> computeTimelines(VolleyMatch match, {int? setNumber}) {
    final out = <SetTimeline>[];
    for (final set in _selectedSets(match, setNumber)) {
      final closing = set.events.where(_isClosing).toList();
      if (closing.isEmpty) continue;
      final marks = <int>[];
      for (final s in set.substitutions) {
        if (s.isLiberoAction) continue;
        final before = closing.where((ev) => ev.rallyNumber < s.rallyNumber).length;
        if (before > 0 && before < closing.length) marks.add(before);
      }
      out.add(SetTimeline(
        setNumber: set.setNumber,
        points: [for (final ev in closing) TimelinePoint(ev.ownScoreAfter, ev.rivalScoreAfter, ev.pointWinner!)],
        substitutionMarks: marks.toSet().toList()..sort(),
      ));
    }
    return out;
  }

  /// Cuántos rallies terminaron en cada categoría (gráfico "Origen de los
  /// puntos").
  static PointOriginStats computePointOrigin(VolleyMatch match, {int? setNumber}) {
    final counts = <RallyCategory, int>{};
    for (final set in _selectedSets(match, setNumber)) {
      for (final ev in set.events) {
        if (!_isClosing(ev)) continue;
        final c = classifyClosing(ev);
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return PointOriginStats(counts);
  }

  // ---------------- Mapas de dirección (pestaña "Mapas", Etapa 2) ----------------
  //
  // Reglas en documents/spec-estadistica-visual.md, secciones 5.1 y 5.2.

  /// Toques de saque, ataque y contra del equipo propio como flechas. El
  /// origen se deduce del puesto del jugador y de si estaba adelante o atrás
  /// en ese rally (reproduciendo rotación y cambios del set); el destino es
  /// el centro de la zona registrada, con un desvío chico y fijo por toque
  /// para que no se encimen. Los toques sin zona no se dibujan (salvo los
  /// bloqueados, que terminan siempre en la red) y se cuentan aparte.
  static ShotMapData computeShots(VolleyMatch match, {int? setNumber}) {
    final positions = {for (final p in match.ownRoster) p.id: p.position};
    final shots = <CourtShot>[];
    final missing = <(String, ShotKind), int>{};

    for (final set in _selectedSets(match, setNumber)) {
      final manual = [...set.manualRotations]..sort((a, b) => a.rallyNumber.compareTo(b.rallyNumber));
      // Los cambios ya están en orden cronológico; no se reordenan porque dos
      // cambios del mismo rally sobre el mismo slot (p. ej. entra el líbero
      // y después se cambia por el otro) dependen de ese orden.
      final subs = set.substitutions;
      var nextManual = 0, nextSub = 0, offset = 0;
      var serving = set.startingServer;
      final order = List<String>.from(set.startingOrderOwn);

      for (final ev in set.events) {
        // Rotaciones manuales y cambios se hacen entre puntos y guardan el
        // número del rally que venía: valen desde ese rally en adelante.
        while (nextManual < manual.length && manual[nextManual].rallyNumber <= ev.rallyNumber) {
          offset = ((offset + manual[nextManual].steps) % 6 + 6) % 6;
          nextManual++;
        }
        while (nextSub < subs.length && subs[nextSub].rallyNumber <= ev.rallyNumber) {
          final s = subs[nextSub];
          if (s.slotIndex >= 0 && s.slotIndex < order.length) order[s.slotIndex] = s.playerInId;
          nextSub++;
        }

        final kind = _shotKindOf(ev);
        if (kind != null && ev.team == TeamSide.own && ev.playerIds.isNotEmpty) {
          final playerId = ev.playerIds.first;
          final slot = order.indexOf(playerId);
          final courtPos = slot < 0 ? null : ((slot - offset) % 6 + 6) % 6 + 1;
          final (ox, oy) = shotOrigin(kind, positions[playerId], courtPos);
          final result = ev.replay ? ShotResult.replay : shotResultOf(ev.grade, ev.missType);
          final center = ev.targetZone == null ? null : zoneCenter(ev.targetZone!, nineZones: set.nineHitZones);

          double? tx, ty;
          if (result == ShotResult.blocked || result == ShotResult.replay) {
            // Bloqueado o rejuego: la pelota no pasó la red; la flecha muere
            // enfrente del atacante, apenas inclinada hacia la zona a la que
            // iba (un rejuego nunca tiene zona: va derecho al bloqueo).
            tx = center == null ? ox : ox + (center.$1 - ox) * 0.1;
            ty = 0.52;
          } else if (result == ShotResult.net) {
            // A la red: igual que el bloqueado, pero sobre la red misma.
            tx = center == null ? ox : ox + (center.$1 - ox) * 0.15;
            ty = 0.503;
          } else if (center != null) {
            final (jx, jy) = _zoneJitter(ev.id);
            tx = center.$1 + jx;
            ty = center.$2 + jy;
            if (result == ShotResult.out) {
              // Afuera: la zona registrada marca la dirección; la flecha
              // sigue en esa dirección hasta salir de la cancha.
              (tx, ty) = _projectOut(ox, oy, tx, ty);
            }
          }

          if (tx == null || ty == null) {
            missing[(playerId, kind)] = (missing[(playerId, kind)] ?? 0) + 1;
          } else {
            shots.add(CourtShot(
              event: ev,
              playerId: playerId,
              kind: kind,
              result: result,
              originX: ox,
              originY: oy,
              targetX: tx,
              targetY: ty,
            ));
          }
        }

        if (_isClosing(ev) && ev.pointWinner != serving) {
          if (ev.pointWinner == TeamSide.own) offset = (offset + 1) % 6;
          serving = ev.pointWinner!;
        }
      }
    }
    return ShotMapData(shots, missing);
  }

  static ShotKind? _shotKindOf(RallyEvent ev) {
    switch (ev.phase) {
      case RallyPhase.serve:
        return ShotKind.serve;
      case RallyPhase.attack:
        return ShotKind.attack;
      case RallyPhase.counter:
        return ShotKind.counter;
      default:
        return null;
    }
  }

  /// Calificación → trazo (spec 5.2). Un NN es "afuera" o "a la red" si
  /// quien cargó lo indicó ([RallyEvent.missType], opcional); si no, es un
  /// "error" sin detalle.
  static ShotResult shotResultOf(String? grade, [String? missType]) {
    switch (grade) {
      case Grade.pp:
        return ShotResult.point;
      case Grade.bloq:
        return ShotResult.blocked;
      case Grade.nn:
        if (missType == MissType.out) return ShotResult.out;
        if (missType == MissType.net) return ShotResult.net;
        return ShotResult.error;
      default:
        return ShotResult.inPlay;
    }
  }

  /// Prolonga la recta origen → (x, y) hasta que sale de la mitad rival
  /// (por una lateral o por el fondo) y la deja un poco afuera.
  static (double, double) _projectOut(double ox, double oy, double x, double y) {
    final dx = x - ox, dy = y - oy;
    var t = double.infinity;
    if (dx < 0) t = math.min(t, (0 - x) / dx);
    if (dx > 0) t = math.min(t, (1 - x) / dx);
    if (dy < 0) t = math.min(t, (0 - y) / dy);
    if (t == double.infinity) return (x, -0.05);
    final len = math.sqrt(dx * dx + dy * dy);
    final extra = 0.05 / len; // un poco más allá de la línea
    final px = x + dx * (t + extra), py = y + dy * (t + extra);
    return (px.clamp(-0.1, 1.1), py.clamp(-0.12, 0.5));
  }

  /// Origen deducido de un toque (tabla de la spec 5.2). [courtPos] es la
  /// posición en cancha (1-6) del jugador en ese rally; null si no estaba en
  /// la formación (no debería pasar), y entonces se lo toma como delantero.
  static (double, double) shotOrigin(ShotKind kind, PlayerPosition? position, int? courtPos) {
    if (kind == ShotKind.serve) return (0.82, 1.06);
    final front = courtPos == null || courtPos == 2 || courtPos == 3 || courtPos == 4;
    switch (position) {
      case PlayerPosition.puntaReceptor:
        return front ? (0.13, 0.60) : (0.50, 0.77);
      case PlayerPosition.opuesto:
        return front ? (0.87, 0.60) : (0.85, 0.76);
      case PlayerPosition.central:
        return front ? (0.50, 0.59) : (0.50, 0.77);
      case PlayerPosition.armador:
        return (0.80, 0.56);
      case PlayerPosition.universal:
      case PlayerPosition.libero:
      case null:
        return _originByCourtPosition[courtPos] ?? (0.50, 0.59);
    }
  }

  static const _originByCourtPosition = {
    4: (0.13, 0.60),
    3: (0.50, 0.59),
    2: (0.87, 0.60),
    5: (0.15, 0.76),
    6: (0.50, 0.77),
    1: (0.85, 0.76),
  };

  /// Centro de una zona de la cancha rival (spec 5.1). Con 6 zonas la fila
  /// de fondo mide 6 m y la de red 3 m; con 9, la mitad rival se divide en
  /// tres franjas de 3 m. Null si la zona no existe en ese esquema.
  static (double, double)? zoneCenter(int zone, {required bool nineZones}) {
    const column = {1: 0, 6: 1, 5: 2, 9: 0, 8: 1, 7: 2, 2: 0, 3: 1, 4: 2};
    final col = column[zone];
    if (col == null) return null;
    final x = (col + 0.5) / 3;
    final back = zone == 1 || zone == 6 || zone == 5;
    final middle = zone == 9 || zone == 8 || zone == 7;
    if (nineZones) return (x, back ? 1 / 12 : (middle ? 0.25 : 5 / 12));
    if (middle) return null;
    return (x, back ? 1 / 6 : 5 / 12);
  }

  /// Desvío de ±0.05 en cada eje, derivado del id del evento (hash FNV-1a,
  /// estable entre ejecuciones): la misma jugada cae siempre en el mismo
  /// lugar del mapa.
  static (double, double) _zoneJitter(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    final jx = ((h & 0xFFFF) / 0xFFFF - 0.5) * 0.1;
    final jy = (((h >> 16) & 0xFFFF) / 0xFFFF - 0.5) * 0.1;
    return (jx, jy);
  }

  /// Jugadores con al menos un ataque o contra, ordenados por eficiencia de
  /// ataque (de mayor a menor). Sin la fila "No Asignado".
  static List<(PlayerStatLine, AttackSummary)> attackRanking(MatchStats stats) {
    final rows = [
      for (final l in stats.orderedRows)
        if (l.playerId != unassignedId && AttackSummary.of(l).total > 0) (l, AttackSummary.of(l)),
    ];
    rows.sort((a, b) => b.$2.efficiency!.compareTo(a.$2.efficiency!));
    return rows;
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
