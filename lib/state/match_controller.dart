import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/match_set.dart';
import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/substitution_event.dart';
import '../models/volley_match.dart';
import '../services/storage_service.dart';
import '../utils/id_gen.dart';

/// Etapa actual dentro del punto en curso: determina qué botones están
/// habilitados en la pantalla de carga en vivo.
enum RallyStage {
  serveOwn, // Mi equipo va a sacar.
  receiveOwn, // Rival sacó, esperando recepción propia.
  attackK1Own, // Recepción propia resuelta, ataque de primera bola.
  defending, // Pelota del lado rival: bloqueo / contra / puntos genéricos.
}

/// Estado de emparejamiento vigente de un puesto de rotación, derivado de
/// reproducir `MatchSet.substitutions` para ese slot. Ver comentario en la
/// sección "Cambios de jugador" de [MatchController] para las reglas.
class _SlotSubState {
  String? regularSubstituteId;
  bool regularOutUsed = false;
  bool regularReturnUsed = false;
  String? liberoOnCourtId;
  String? liberoReplacedPlayerId;
  int? lastLiberoActionRally;
}

class MatchController extends ChangeNotifier {
  VolleyMatch match;
  int _rotationOffsetOwn = 0;
  TeamSide _servingTeam = TeamSide.own;
  RallyStage _stage = RallyStage.serveOwn;
  int _rallyCounter = 1;
  bool needsNextSetSetup = false;

  /// Jugador que ejecutó el saque en el punto que está en curso (solo si
  /// sacó el equipo propio). Se usa para el cambio automático central ->
  /// líbero receptor si se pierde el punto. Se limpia al terminar el punto.
  String? _currentRallyServerId;

  MatchController(this.match);

  /// Reconstruye el estado en memoria (rotación, quién saca, etapa de la
  /// jugada) a partir del log de eventos del último set, para poder seguir
  /// cargando un partido que ya estaba en curso.
  static MatchController resume(VolleyMatch match) {
    final controller = MatchController(match);
    if (match.sets.isEmpty) return controller;
    final set = match.sets.last;

    controller._rotationOffsetOwn = 0;
    controller._servingTeam = set.startingServer;
    controller._rallyCounter = 1;

    for (final ev in set.events) {
      if (ev.phase == RallyPhase.serve && ev.team == TeamSide.own && ev.playerIds.isNotEmpty) {
        controller._currentRallyServerId = ev.playerIds.first;
      }
      if (ev.endsRally && ev.pointWinner != null) {
        final wasServing = controller._servingTeam;
        if (ev.pointWinner != wasServing) {
          if (ev.pointWinner == TeamSide.own) {
            controller._rotationOffsetOwn = (controller._rotationOffsetOwn + 1) % 6;
          }
          controller._servingTeam = ev.pointWinner!;
        }
        controller._rallyCounter++;
        controller._currentRallyServerId = null;
      }
    }

    if (set.finished) {
      if (match.ownSetsWon >= match.config.setsToWin ||
          match.rivalSetsWon >= match.config.setsToWin) {
        match.status = MatchStatus.finished;
      } else {
        controller.needsNextSetSetup = true;
      }
      return controller;
    }

    if (set.events.isEmpty) {
      controller._stage =
          controller._servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    } else {
      final last = set.events.last;
      if (last.endsRally) {
        controller._stage =
            controller._servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
      } else if (last.phase == RallyPhase.reception) {
        controller._stage = RallyStage.attackK1Own;
      } else {
        // Saque en juego, ataque o contra no terminales -> queda a la
        // espera de la respuesta (bloqueo/contra/errores).
        controller._stage = RallyStage.defending;
      }
    }
    return controller;
  }

  MatchSet get currentSet => match.sets.last;
  RallyStage get stage => _stage;
  TeamSide get servingTeam => _servingTeam;
  int get rotationOffsetOwn => _rotationOffsetOwn;

  /// Jugador propio actualmente en la posición [pos] (1 a 6), considerando
  /// los cambios de jugador ya realizados en este set.
  String playerAtPosition(int pos) {
    final order = currentSet.currentOrderOwn;
    if (order.length < 6) return '';
    return order[(pos - 1 + _rotationOffsetOwn) % 6];
  }

  /// Mapa posición(1-6) -> jugador propio, para mostrar la cancha.
  Map<int, String> get onCourtOwn =>
      {for (var pos = 1; pos <= 6; pos++) pos: playerAtPosition(pos)};

  Player? playerById(String id) {
    for (final p in match.ownRoster) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Jugadores propios elegibles para atacar / bloquear ahora mismo
  /// (todo el equipo en cancha; no se fuerza la regla de línea de 3m).
  List<Player> get onCourtPlayers =>
      onCourtOwn.values.map(playerById).whereType<Player>().toList();

  /// Jugadores propios del roster que no están en cancha en este momento
  /// (candidatos para entrar en un cambio).
  List<Player> get benchPlayers {
    final onCourt = currentSet.currentOrderOwn.toSet();
    return match.ownRoster.where((p) => !onCourt.contains(p.id)).toList();
  }

  /// Inicia un nuevo set con el orden de rotación y el equipo que saca.
  void startSet({
    required int setNumber,
    required List<String> startingOrderOwn,
    required TeamSide startingServer,
  }) {
    final set = MatchSet(
      setNumber: setNumber,
      startingOrderOwn: startingOrderOwn,
      startingServer: startingServer,
    );
    match.sets.add(set);
    match.status = MatchStatus.inProgress;
    _rotationOffsetOwn = 0;
    _servingTeam = startingServer;
    _rallyCounter = 1;
    needsNextSetSetup = false;
    _stage = _servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    notifyListeners();
  }

  bool get actionServeEnabled => _stage == RallyStage.serveOwn;
  bool get actionReceptionEnabled => _stage == RallyStage.receiveOwn;
  bool get actionAttackEnabled => _stage == RallyStage.attackK1Own;
  bool get actionCounterEnabled => _stage == RallyStage.defending;
  bool get actionBlockEnabled => _stage == RallyStage.defending;
  bool get actionOpponentButtonsEnabled =>
      _stage == RallyStage.receiveOwn || _stage == RallyStage.defending;
  bool get actionGenericErrorEnabled => true;

  // ---------------- Registro de acciones ----------------

  void logServe(String playerId, String grade) {
    _currentRallyServerId = playerId;
    final terminal = grade == Grade.pp || grade == Grade.nn;
    final winner = grade == Grade.pp
        ? TeamSide.own
        : (grade == Grade.nn ? TeamSide.rival : null);
    _addEvent(
      phase: RallyPhase.serve,
      team: TeamSide.own,
      playerIds: [playerId],
      grade: grade,
      endsRally: terminal,
      winner: winner,
    );
    if (!terminal) {
      _stage = RallyStage.defending;
      notifyListeners();
    }
  }

  void logReception(String playerId, String grade) {
    final terminal = grade == Grade.nn;
    _addEvent(
      phase: RallyPhase.reception,
      team: TeamSide.own,
      playerIds: [playerId],
      grade: grade,
      endsRally: terminal,
      winner: terminal ? TeamSide.rival : null,
    );
    if (!terminal) {
      _stage = RallyStage.attackK1Own;
      notifyListeners();
    }
  }

  void logAttack(String playerId, String grade) {
    _logAttackOrCounter(RallyPhase.attack, playerId, grade);
  }

  void logCounter(String playerId, String grade) {
    _logAttackOrCounter(RallyPhase.counter, playerId, grade);
  }

  void _logAttackOrCounter(RallyPhase phase, String playerId, String grade) {
    final terminal = grade == Grade.pp || grade == Grade.nn || grade == Grade.bloq;
    final winner = grade == Grade.pp
        ? TeamSide.own
        : (terminal ? TeamSide.rival : null);
    _addEvent(
      phase: phase,
      team: TeamSide.own,
      playerIds: [playerId],
      grade: grade,
      endsRally: terminal,
      winner: winner,
    );
    if (!terminal) {
      _stage = RallyStage.defending;
      notifyListeners();
    }
  }

  void logBlockPoint(List<String> blockerIds) {
    _addEvent(
      phase: RallyPhase.block,
      team: TeamSide.own,
      playerIds: blockerIds,
      grade: null,
      endsRally: true,
      winner: TeamSide.own,
    );
  }

  void logGenericError({String? playerId}) {
    _addEvent(
      phase: RallyPhase.genericError,
      team: TeamSide.own,
      playerIds: playerId == null ? [] : [playerId],
      grade: null,
      endsRally: true,
      winner: TeamSide.rival,
    );
  }

  void logOpponentPoint() {
    _addEvent(
      phase: RallyPhase.opponentPoint,
      team: TeamSide.rival,
      grade: null,
      endsRally: true,
      winner: TeamSide.rival,
    );
  }

  void logOpponentError() {
    _addEvent(
      phase: RallyPhase.opponentError,
      team: TeamSide.rival,
      grade: null,
      endsRally: true,
      winner: TeamSide.own,
    );
  }

  // ---------------- Cambios de jugador ----------------
  //
  // Reglas de la FIVB (Regla 15.6 cambios regulares y Regla 19.3 líbero;
  // FeVA y FMV disputan sus torneos bajo el mismo reglamento oficial de la
  // FIVB, sin variantes en esta materia):
  //  - Cambio regular: el titular de un puesto puede salir por UN suplente
  //    fijo, una sola vez, y ese mismo suplente solo puede volver a salir
  //    por el titular, también una sola vez (como máximo 2 cambios "gastan"
  //    el cupo de ese puesto: titular->suplente y suplente->titular). Nunca
  //    puede intervenir un líbero en un cambio regular.
  //  - Cambio de líbero: no cuenta contra el límite de cambios, es
  //    ilimitado (con al menos una jugada entre dos cambios de líbero en el
  //    mismo puesto), solo puede entrar cuando ese puesto está en fila
  //    trasera (1, 5 o 6), y el líbero en cancha solo puede salir por el
  //    jugador específico al que reemplazó (o por el otro líbero declarado,
  //    si el equipo declaró dos).

  /// Cambios regulares ya usados en el set (no cuenta cambios de líbero).
  int get substitutionsUsedOwn => currentSet.substitutionsUsedOwn;

  /// Cambios regulares que todavía se pueden hacer en el set actual.
  int get substitutionsRemaining =>
      (match.config.maxSubstitutionsPerSet - currentSet.substitutionsUsedOwn)
          .clamp(0, match.config.maxSubstitutionsPerSet);

  bool get canRegisterSubstitution => substitutionsRemaining > 0;

  /// Líberos declarados para el partido (hasta 2), sin duplicados.
  List<String> get declaredLiberoIds {
    final ids = <String>{};
    if (match.defensiveLiberoId != null) ids.add(match.defensiveLiberoId!);
    if (match.receptionLiberoId != null) ids.add(match.receptionLiberoId!);
    return ids.toList();
  }

  /// Reconstruye, reproduciendo el historial de cambios de este set, el
  /// estado vigente de emparejamiento (regular y de líbero) de un puesto de
  /// rotación (slot 0-5, índice fijo dentro de `startingOrderOwn`).
  _SlotSubState _slotState(int slotIndex) {
    final st = _SlotSubState();
    for (final sub in currentSet.substitutions.where((s) => s.slotIndex == slotIndex)) {
      if (sub.isLiberoAction) {
        st.lastLiberoActionRally = sub.rallyNumber;
        final outIsLibero = playerById(sub.playerOutId)?.position == PlayerPosition.libero;
        if (!outIsLibero) {
          // Un jugador regular sale, entra un líbero.
          st.liberoOnCourtId = sub.playerInId;
          st.liberoReplacedPlayerId = sub.playerOutId;
        } else if (playerById(sub.playerInId)?.position == PlayerPosition.libero) {
          // Líbero por líbero: se mantiene quién fue el reemplazado original.
          st.liberoOnCourtId = sub.playerInId;
        } else {
          // Vuelve el jugador reemplazado: sale el líbero.
          st.liberoOnCourtId = null;
          st.liberoReplacedPlayerId = null;
        }
      } else {
        if (!st.regularOutUsed) {
          st.regularSubstituteId = sub.playerInId;
          st.regularOutUsed = true;
        } else {
          st.regularReturnUsed = true;
        }
      }
    }
    return st;
  }

  bool _slotIsBackRow(int slotIndex) {
    final pos = ((slotIndex - _rotationOffsetOwn) % 6 + 6) % 6 + 1;
    return pos == 1 || pos == 5 || pos == 6;
  }

  bool _liberoOnCourtInAnySlot(String liberoId) {
    for (var i = 0; i < 6; i++) {
      if (_slotState(i).liberoOnCourtId == liberoId) return true;
    }
    return false;
  }

  // ---- Cambio regular ----

  /// true si [playerOutId] (en cancha) todavía puede salir por un cambio
  /// regular, según el emparejamiento fijo de su puesto.
  bool canSubOutRegular(String playerOutId) {
    if (playerById(playerOutId)?.position == PlayerPosition.libero) return false;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    if (slot == -1) return false;
    final st = _slotState(slot);
    if (st.liberoOnCourtId != null) return false; // el líbero tapa el puesto
    final starterId = currentSet.startingOrderOwn[slot];
    if (playerOutId == starterId) return !st.regularOutUsed;
    if (playerOutId == st.regularSubstituteId) return !st.regularReturnUsed;
    return false;
  }

  /// Jugadores del banco habilitados para entrar por [playerOutId] mediante
  /// un cambio regular (excluye líberos, que nunca entran por esta vía, y
  /// jugadores ya atados como suplentes fijos de otro puesto).
  List<Player> eligibleRegularBenchFor(String playerOutId) {
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    if (slot == -1) return [];
    final st = _slotState(slot);
    if (playerOutId == st.regularSubstituteId) {
      final starter = playerById(currentSet.startingOrderOwn[slot]);
      return starter == null ? [] : [starter];
    }
    final lockedElsewhere = <String>{};
    for (var i = 0; i < 6; i++) {
      if (i == slot) continue;
      final s = _slotState(i);
      if (s.regularSubstituteId != null) lockedElsewhere.add(s.regularSubstituteId!);
    }
    return benchPlayers
        .where((p) => p.position != PlayerPosition.libero && !lockedElsewhere.contains(p.id))
        .toList();
  }

  /// Cambio regular manual: [playerOutId] en cancha, [playerInId] en banco.
  void substitutePlayer({required String playerOutId, required String playerInId}) {
    if (!canRegisterSubstitution) return;
    if (!canSubOutRegular(playerOutId)) return;
    if (!eligibleRegularBenchFor(playerOutId).any((p) => p.id == playerInId)) return;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    _applySubstitution(
      slotIndex: slot,
      playerInId: playerInId,
      countsAgainstLimit: true,
      isLiberoAction: false,
    );
  }

  // ---- Cambio de líbero ----

  /// true si [liberoId] (declarado) puede entrar en lugar de [playerOutId].
  bool canBringLiberoIn(String liberoId, String playerOutId) {
    if (!declaredLiberoIds.contains(liberoId)) return false;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    if (slot == -1) return false;
    final st = _slotState(slot);
    if (st.liberoOnCourtId != null) return false;
    if (!_slotIsBackRow(slot)) return false;
    if (st.lastLiberoActionRally == _rallyCounter) return false;
    if (_liberoOnCourtInAnySlot(liberoId)) return false;
    return true;
  }

  void bringLiberoIn(String liberoId, String playerOutId) {
    if (!canBringLiberoIn(liberoId, playerOutId)) return;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    _applySubstitution(
      slotIndex: slot,
      playerInId: liberoId,
      countsAgainstLimit: false,
      isLiberoAction: true,
    );
  }

  /// true si el líbero del puesto [slotIndex] puede salir ahora (por el
  /// jugador que reemplazó, o intercambiarse por el otro líbero declarado).
  bool canSendLiberoOut(int slotIndex) {
    final st = _slotState(slotIndex);
    if (st.liberoOnCourtId == null) return false;
    return st.lastLiberoActionRally != _rallyCounter;
  }

  /// Saca al líbero de [slotIndex] y hace volver al jugador que reemplazó.
  void sendLiberoOut(int slotIndex) {
    if (!canSendLiberoOut(slotIndex)) return;
    final st = _slotState(slotIndex);
    _applySubstitution(
      slotIndex: slotIndex,
      playerInId: st.liberoReplacedPlayerId!,
      countsAgainstLimit: false,
      isLiberoAction: true,
    );
  }

  /// Cambia el líbero en cancha en [slotIndex] por el otro líbero declarado
  /// (sigue reemplazando, a todos los efectos, al mismo jugador original).
  void swapLiberoToOther(int slotIndex) {
    if (!canSendLiberoOut(slotIndex)) return;
    final st = _slotState(slotIndex);
    final other = declaredLiberoIds.where((id) => id != st.liberoOnCourtId).toList();
    if (other.isEmpty) return;
    if (_liberoOnCourtInAnySlot(other.first)) return;
    _applySubstitution(
      slotIndex: slotIndex,
      playerInId: other.first,
      countsAgainstLimit: false,
      isLiberoAction: true,
    );
  }

  void _applySubstitution({
    required int slotIndex,
    required String playerInId,
    required bool countsAgainstLimit,
    required bool isLiberoAction,
    bool auto = false,
  }) {
    final set = currentSet;
    final playerOutId = set.currentOrderOwn[slotIndex];
    set.currentOrderOwn[slotIndex] = playerInId;
    if (countsAgainstLimit) set.substitutionsUsedOwn++;
    final courtPos = ((slotIndex - _rotationOffsetOwn) % 6 + 6) % 6 + 1;
    set.substitutions.add(SubstitutionEvent(
      id: generateId('sub_'),
      setNumber: set.setNumber,
      rallyNumber: _rallyCounter,
      slotIndex: slotIndex,
      position: courtPos,
      playerOutId: playerOutId,
      playerInId: playerInId,
      countedAgainstLimit: countsAgainstLimit,
      isLiberoAction: isLiberoAction,
      auto: auto,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _persist();
  }

  /// Si el equipo propio sacó con un central y perdió el punto, entra
  /// automáticamente el líbero receptor en su lugar (cambio libre), siempre
  /// que esté configurado, en fila trasera y no esté ya en cancha.
  void _maybeAutoSubCentralForLibero(String serverId) {
    final liberoId = match.receptionLiberoId;
    if (liberoId == null || liberoId == serverId) return;
    if (playerById(serverId)?.position != PlayerPosition.central) return;
    if (!canBringLiberoIn(liberoId, serverId)) return;
    bringLiberoIn(liberoId, serverId);
  }

  /// Al rotar, un líbero no puede quedar en fila delantera: si su puesto
  /// pasa a posición 2, 3 o 4, sale obligatoriamente por el jugador que
  /// había reemplazado (cambio libre y automático).
  void _releaseLiberosRotatingToFrontRow() {
    for (var slot = 0; slot < 6; slot++) {
      final st = _slotState(slot);
      if (st.liberoOnCourtId == null || _slotIsBackRow(slot)) continue;
      _applySubstitution(
        slotIndex: slot,
        playerInId: st.liberoReplacedPlayerId!,
        countsAgainstLimit: false,
        isLiberoAction: true,
        auto: true,
      );
    }
  }

  /// Deshace el último evento cargado (corrige un toque mal tocado).
  void undoLast() {
    final set = currentSet;
    if (set.events.isEmpty) return;
    final removed = set.events.removeLast();

    if (removed.endsRally && removed.pointWinner != null) {
      // Revertir marcador.
      if (removed.pointWinner == TeamSide.own) {
        set.ownScore = (set.ownScore - 1).clamp(0, 1 << 30);
      } else {
        set.rivalScore = (set.rivalScore - 1).clamp(0, 1 << 30);
      }
      // Restaurar quién sacaba antes de este punto y, si hubo side-out a
      // favor propio, revertir la rotación que se disparó.
      if (removed.pointWinner != removed.servingTeamBefore &&
          removed.pointWinner == TeamSide.own) {
        _rotationOffsetOwn = (_rotationOffsetOwn - 1) % 6;
      }
      _servingTeam = removed.servingTeamBefore;

      set.finished = false;
      set.winner = null;
      match.status = MatchStatus.inProgress;
      needsNextSetSetup = false;
      _rallyCounter = (_rallyCounter - 1).clamp(1, 1 << 30);

      // Volvemos al comienzo de la jugada anterior.
      _stage = _servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    } else {
      // Se deshace un toque intermedio (no terminó el punto): volvemos a la
      // etapa en la que estábamos justo antes de cargarlo.
      switch (removed.phase) {
        case RallyPhase.serve:
          _stage = RallyStage.serveOwn;
          break;
        case RallyPhase.reception:
          _stage = RallyStage.receiveOwn;
          break;
        case RallyPhase.attack:
          _stage = RallyStage.attackK1Own;
          break;
        case RallyPhase.counter:
          _stage = RallyStage.defending;
          break;
        case RallyPhase.block:
        case RallyPhase.genericError:
        case RallyPhase.opponentPoint:
        case RallyPhase.opponentError:
          // Estas fases siempre terminan el punto; no deberían caer acá.
          _stage = RallyStage.defending;
          break;
      }
    }
    notifyListeners();
    _persist();
  }

  // ---------------- Simulación ----------------

  final Random _rng = Random();

  static const _serveGradePool = [Grade.pp, Grade.p, Grade.p, Grade.n, Grade.n, Grade.nn];
  static const _receptionGradePool = [
    Grade.pp,
    Grade.p,
    Grade.p,
    Grade.excl,
    Grade.n,
    Grade.vNeg,
    Grade.nn,
  ];
  static const _attackGradePool = [Grade.pp, Grade.pp, Grade.p, Grade.p, Grade.n, Grade.nn, Grade.bloq];

  String _randomPlayerId() {
    final players = onCourtPlayers;
    if (players.isEmpty) return '';
    return players[_rng.nextInt(players.length)].id;
  }

  String _randomGrade(List<String> pool) => pool[_rng.nextInt(pool.length)];

  /// Juega un punto completo a partir del estado actual, eligiendo al azar
  /// jugador/calificación/resultado en cada toque, reutilizando los mismos
  /// métodos `log*` que usan los botones de carga manual. Pensado para
  /// probar la app rápido sin cargar cada toque a mano.
  void simulateOnePoint() {
    if (needsNextSetSetup || match.status == MatchStatus.finished) return;
    final rallyBefore = _rallyCounter;
    var guard = 0;
    while (_rallyCounter == rallyBefore && guard < 60) {
      guard++;
      switch (_stage) {
        case RallyStage.serveOwn:
          logServe(_randomPlayerId(), _randomGrade(_serveGradePool));
          break;
        case RallyStage.receiveOwn:
          logReception(_randomPlayerId(), _randomGrade(_receptionGradePool));
          break;
        case RallyStage.attackK1Own:
          logAttack(_randomPlayerId(), _randomGrade(_attackGradePool));
          break;
        case RallyStage.defending:
          _simulateDefendingTouch();
          break;
      }
    }
  }

  void _simulateDefendingTouch() {
    final roll = _rng.nextDouble();
    if (roll < 0.45) {
      logCounter(_randomPlayerId(), _randomGrade(_attackGradePool));
    } else if (roll < 0.65) {
      final blockers = onCourtPlayers..shuffle(_rng);
      logBlockPoint(blockers.take(1 + _rng.nextInt(2)).map((p) => p.id).toList());
    } else if (roll < 0.8) {
      logGenericError(playerId: _rng.nextBool() ? _randomPlayerId() : null);
    } else if (roll < 0.9) {
      logOpponentPoint();
    } else {
      logOpponentError();
    }
  }

  /// Simula puntos aleatorios hasta que el set actual termine (o el partido,
  /// si era el último set). No configura el set siguiente: eso lo sigue
  /// pidiendo la pantalla en vivo, igual que en una carga manual. Entre
  /// punto y punto también simula cambios de jugador al azar (jugador por
  /// jugador, o líbero por líbero); el cambio central -> líbero receptor ya
  /// sale solo desde `_resolvePoint` cuando corresponde.
  void simulateRestOfSet() {
    var guard = 0;
    while (!needsNextSetSetup && match.status != MatchStatus.finished && guard < 500) {
      simulateOnePoint();
      if (!needsNextSetSetup && match.status != MatchStatus.finished) {
        _maybeSimulateRandomSubstitution();
      }
      guard++;
    }
  }

  void _maybeSimulateRandomSubstitution() {
    final roll = _rng.nextDouble();
    if (roll < 0.10) {
      // Cambio regular jugador por jugador, respetando el emparejamiento
      // fijo (titular <-> el mismo suplente) y el cupo de cambios del set.
      if (!canRegisterSubstitution) return;
      final candidates = onCourtPlayers.where((p) => canSubOutRegular(p.id)).toList();
      if (candidates.isEmpty) return;
      final playerOut = candidates[_rng.nextInt(candidates.length)];
      final bench = eligibleRegularBenchFor(playerOut.id);
      if (bench.isEmpty) return;
      final playerIn = bench[_rng.nextInt(bench.length)];
      substitutePlayer(playerOutId: playerOut.id, playerInId: playerIn.id);
    } else if (roll < 0.16) {
      // Cambio líbero por líbero (defensor <-> receptor), si hay dos
      // declarados y uno de ellos está en cancha en este momento.
      final liberos = declaredLiberoIds;
      if (liberos.length < 2) return;
      for (var slot = 0; slot < 6; slot++) {
        final st = _slotState(slot);
        if (st.liberoOnCourtId != null && liberos.contains(st.liberoOnCourtId)) {
          swapLiberoToOther(slot);
          return;
        }
      }
    }
  }

  // ---------------- Internals ----------------

  void _addEvent({
    required RallyPhase phase,
    required TeamSide team,
    List<String> playerIds = const [],
    String? grade,
    required bool endsRally,
    TeamSide? winner,
  }) {
    final set = currentSet;
    final servingBefore = _servingTeam;
    if (endsRally && winner != null) {
      if (winner == TeamSide.own) {
        set.ownScore++;
      } else {
        set.rivalScore++;
      }
    }
    final event = RallyEvent(
      id: generateId('ev_'),
      setNumber: set.setNumber,
      rallyNumber: _rallyCounter,
      phase: phase,
      team: team,
      playerIds: playerIds,
      grade: grade,
      endsRally: endsRally,
      pointWinner: winner,
      servingTeamBefore: servingBefore,
      ownScoreAfter: set.ownScore,
      rivalScoreAfter: set.rivalScore,
      timestamp: DateTime.now(),
    );
    set.events.add(event);

    if (endsRally && winner != null) {
      _resolvePoint(winner);
    }
    _persist();
  }

  void _resolvePoint(TeamSide winner) {
    final set = currentSet;
    final wasServing = _servingTeam;
    final serverIdForThisRally = _currentRallyServerId;
    _currentRallyServerId = null;

    _rallyCounter++;

    if (winner != wasServing) {
      // Side-out: el equipo que gana pasa a sacar y, si es el propio, rota.
      if (winner == TeamSide.own) {
        _rotationOffsetOwn = (_rotationOffsetOwn + 1) % 6;
        _releaseLiberosRotatingToFrontRow();
      }
      _servingTeam = winner;
    }

    if (winner == TeamSide.rival && wasServing == TeamSide.own && serverIdForThisRally != null) {
      _maybeAutoSubCentralForLibero(serverIdForThisRally);
    }

    final pointsToWin = match.config.pointsToWin(set.setNumber);
    final margin = match.config.winMargin(set.setNumber);
    final leader = set.ownScore > set.rivalScore ? set.ownScore : set.rivalScore;
    final diff = (set.ownScore - set.rivalScore).abs();

    if (leader >= pointsToWin && diff >= margin) {
      set.finished = true;
      set.winner = set.ownScore > set.rivalScore ? TeamSide.own : TeamSide.rival;
      if (match.ownSetsWon >= match.config.setsToWin ||
          match.rivalSetsWon >= match.config.setsToWin) {
        match.status = MatchStatus.finished;
      } else {
        needsNextSetSetup = true;
      }
      notifyListeners();
      return;
    }

    _stage = _servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.instance.saveMatch(match);
  }
}
