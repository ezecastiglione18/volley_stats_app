import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/match_set.dart';
import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/sanction_event.dart';
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

  /// Rotación acumulada del rival, en la misma unidad que [_rotationOffsetOwn]
  /// pero solo para ubicar a su armador: avanza 1 cada vez que el rival gana
  /// el saque en un side-out. No llevamos identidad del resto de su equipo.
  int _rivalRotationOffset = 0;
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
    controller._rivalRotationOffset = 0;
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
          } else {
            controller._rivalRotationOffset = (controller._rivalRotationOffset + 1) % 6;
          }
          controller._servingTeam = ev.pointWinner!;
        }
        controller._rallyCounter++;
        controller._currentRallyServerId = null;
      }
    }

    if (set.finished) {
      // Si todavía no se confirmó con confirmSetFinished (ver `locked`), el
      // set queda "pendiente": no se fuerza needsNextSetSetup ni se marca el
      // partido como finalizado, para poder seguir deshaciendo si hace falta.
      if (set.locked) {
        if (match.isMatchOver) {
          match.status = MatchStatus.finished;
        } else {
          controller.needsNextSetSetup = true;
        }
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

  /// Posición actual (1-6) del armador rival, solo si se cargó su posición
  /// inicial al armar la formación de este set (dato opcional). Se recalcula
  /// rotando 1 puesto cada vez que el rival gana el saque en un side-out;
  /// es puramente informativo, no llevamos el resto de su rotación.
  int? get rivalSetterPosition {
    final start = currentSet.rivalSetterStartPosition;
    if (start == null) return null;
    return ((start - 1 - _rivalRotationOffset) % 6 + 6) % 6 + 1;
  }

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

  /// Posición en cancha (1-6) del jugador propio [playerId], o null si no
  /// está en cancha en este momento.
  int? courtPositionOf(String playerId) {
    final slot = currentSet.currentOrderOwn.indexOf(playerId);
    if (slot == -1) return null;
    return _courtPositionOfSlot(slot);
  }

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
  /// (candidatos para entrar en un cambio), sin contar a quienes una sanción
  /// les impide volver a jugar ahora mismo (ver [isBarredFromPlay]).
  List<Player> get benchPlayers {
    final onCourt = currentSet.currentOrderOwn.toSet();
    return match.ownRoster
        .where((p) => !onCourt.contains(p.id) && !isBarredFromPlay(p.id))
        .toList();
  }

  /// true si [playerId] no puede volver a jugar en este momento del partido
  /// por una sanción (Regla 21 de la FIVB): una Expulsión lo deja afuera
  /// solo por el resto del set en que se dio (vuelve a estar disponible en
  /// los sets siguientes), y una Descalificación lo deja afuera por el resto
  /// del PARTIDO (cualquier set desde ese momento en adelante).
  bool isBarredFromPlay(String playerId) {
    for (final set in match.sets) {
      for (final s in set.sanctions) {
        if (s.team != TeamSide.own ||
            s.targetKind != SanctionTargetKind.player ||
            s.targetPlayerId != playerId) {
          continue;
        }
        if (s.outcome == SanctionOutcome.descalificacion) return true;
        if (s.outcome == SanctionOutcome.expulsion && set.setNumber == currentSet.setNumber) {
          return true;
        }
      }
    }
    return false;
  }

  /// Inicia un nuevo set con el orden de rotación y el equipo que saca.
  void startSet({
    required int setNumber,
    required List<String> startingOrderOwn,
    required TeamSide startingServer,
    bool trackHitZones = true,
    String? defensiveLiberoId,
    String? receptionLiberoId,
    bool autoLiberoBackRowSwap = true,
  }) {
    final set = MatchSet(
      setNumber: setNumber,
      startingOrderOwn: startingOrderOwn,
      startingServer: startingServer,
      trackHitZones: trackHitZones,
      defensiveLiberoId: defensiveLiberoId,
      receptionLiberoId: receptionLiberoId,
      autoLiberoBackRowSwap: autoLiberoBackRowSwap,
    );
    match.sets.add(set);
    match.status = MatchStatus.inProgress;
    _rotationOffsetOwn = 0;
    _rivalRotationOffset = 0;
    _servingTeam = startingServer;
    _rallyCounter = 1;
    needsNextSetSetup = false;
    _stage = _servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    // Si la formación elegida ya deja a algún central en el fondo (saque
    // propio o del rival), no hace falta esperar a un side-out: se evalúa
    // el automatismo del líbero también acá.
    _maybeAutoSubLiberoForCentralInBackRow();
    notifyListeners();
  }

  // Ninguna acción de carga queda habilitada una vez que el set llegó a su
  // puntaje de cierre (aunque todavía no se haya confirmado con el botón
  // "Confirmar fin de set"): no hay más jugadas que registrar.
  bool get actionServeEnabled => _stage == RallyStage.serveOwn && !currentSet.finished;
  bool get actionReceptionEnabled => _stage == RallyStage.receiveOwn && !currentSet.finished;
  bool get actionAttackEnabled => _stage == RallyStage.attackK1Own && !currentSet.finished;
  bool get actionCounterEnabled => _stage == RallyStage.defending && !currentSet.finished;
  bool get actionBlockEnabled => _stage == RallyStage.defending && !currentSet.finished;
  // "Punto rival" (nos gana el punto con ataque/contra) solo tiene sentido
  // mientras la pelota puede llegar a terminar del lado rival: mientras
  // recibimos su saque o defendemos su ataque/contra.
  bool get actionOpponentButtonsEnabled =>
      (_stage == RallyStage.receiveOwn || _stage == RallyStage.defending) && !currentSet.finished;

  // "Error rival" además puede darse mientras es nuestro turno de atacar o
  // contraatacar (p. ej. un toque de red del rival antes de que la pelota
  // llegue a nuestro jugador), así que se habilita también en
  // `attackK1Own`, no solo mientras esperamos su punto.
  bool get actionOpponentErrorEnabled =>
      (_stage == RallyStage.receiveOwn ||
          _stage == RallyStage.attackK1Own ||
          _stage == RallyStage.defending) &&
      !currentSet.finished;
  bool get actionGenericErrorEnabled => !currentSet.finished;

  // ---------------- Registro de acciones ----------------

  void logServe(String playerId, String grade, {int? targetZone}) {
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
      targetZone: targetZone,
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
      // Una recepción "Vendida" (V-) manda la pelota descontrolada al lado
      // rival: el punto sigue, pero del lado de la defensa (Contra/Bloqueo/
      // Error Genérico/Punto rival/Error rival), no de nuestro ataque.
      _stage = grade == Grade.vNeg ? RallyStage.defending : RallyStage.attackK1Own;
      notifyListeners();
    }
  }

  void logAttack(String playerId, String grade, {int? targetZone}) {
    _logAttackOrCounter(RallyPhase.attack, playerId, grade, targetZone: targetZone);
  }

  void logCounter(String playerId, String grade, {int? targetZone}) {
    _logAttackOrCounter(RallyPhase.counter, playerId, grade, targetZone: targetZone);
  }

  void _logAttackOrCounter(RallyPhase phase, String playerId, String grade, {int? targetZone}) {
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
      targetZone: targetZone,
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

  /// [rivalActionType] indica con qué tocó el rival para ganar el punto
  /// (ver [RivalAction]: solo `attack` o `counter` tienen sentido acá).
  void logOpponentPoint({required String rivalActionType}) {
    _addEvent(
      phase: RallyPhase.opponentPoint,
      team: TeamSide.rival,
      grade: null,
      endsRally: true,
      winner: TeamSide.rival,
      rivalActionType: rivalActionType,
    );
  }

  /// [rivalActionType] indica qué tocó el rival y falló (ver [RivalAction]).
  void logOpponentError({String rivalActionType = RivalAction.generic}) {
    _addEvent(
      phase: RallyPhase.opponentError,
      team: TeamSide.rival,
      grade: null,
      endsRally: true,
      winner: TeamSide.own,
      rivalActionType: rivalActionType,
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

  /// Cambios regulares que todavía se pueden hacer en el set actual (un
  /// número muy grande si el partido tiene cambios "sin límite").
  int get substitutionsRemaining {
    if (match.config.hasUnlimitedSubstitutions) return 1 << 30;
    return (match.config.maxSubstitutionsPerSet - currentSet.substitutionsUsedOwn)
        .clamp(0, match.config.maxSubstitutionsPerSet);
  }

  bool get canRegisterSubstitution => substitutionsRemaining > 0;

  /// Líberos declarados para el partido (hasta 2), sin duplicados.
  List<String> get declaredLiberoIds {
    final ids = <String>{};
    if (currentSet.defensiveLiberoId != null) ids.add(currentSet.defensiveLiberoId!);
    if (currentSet.receptionLiberoId != null) ids.add(currentSet.receptionLiberoId!);
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

  int _courtPositionOfSlot(int slotIndex) => ((slotIndex - _rotationOffsetOwn) % 6 + 6) % 6 + 1;

  bool _slotIsBackRow(int slotIndex) {
    final pos = _courtPositionOfSlot(slotIndex);
    return pos == 1 || pos == 5 || pos == 6;
  }

  /// true si algún líbero (cualquiera) está en cancha en este momento: la
  /// regla de la FIVB es que solo puede haber UN líbero en cancha a la vez,
  /// aunque el equipo haya declarado dos.
  bool get _anyLiberoOnCourt {
    for (var i = 0; i < 6; i++) {
      if (_slotState(i).liberoOnCourtId != null) return true;
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
    // El líbero no puede sacar: si este puesto está a punto de sacar (está
    // en posición 1 y el saque es nuestro), no se puede meter un líbero ahí.
    if (_courtPositionOfSlot(slot) == 1 && _servingTeam == TeamSide.own) return false;
    if (st.lastLiberoActionRally == _rallyCounter) return false;
    if (_anyLiberoOnCourt) return false; // solo puede haber un líbero en cancha a la vez
    return true;
  }

  void bringLiberoIn(String liberoId, String playerOutId, {bool auto = false}) {
    if (!canBringLiberoIn(liberoId, playerOutId)) return;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    _applySubstitution(
      slotIndex: slot,
      playerInId: liberoId,
      countsAgainstLimit: false,
      isLiberoAction: true,
      auto: auto,
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
  void swapLiberoToOther(int slotIndex, {bool auto = false}) {
    if (!canSendLiberoOut(slotIndex)) return;
    final st = _slotState(slotIndex);
    final other = declaredLiberoIds.where((id) => id != st.liberoOnCourtId).toList();
    if (other.isEmpty) return;
    _applySubstitution(
      slotIndex: slotIndex,
      playerInId: other.first,
      countsAgainstLimit: false,
      isLiberoAction: true,
      auto: auto,
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

  /// true si el último cambio registrado en el set se puede deshacer: tiene
  /// que existir alguno y no puede ser automático (los automáticos responden
  /// a una regla del reglamento —central reemplazado por el líbero receptor,
  /// o líbero forzado a salir al rotar a la fila delantera—, no a un error
  /// de carga, así que deshacerlos dejaría la cancha en un estado ilegal).
  bool get canUndoLastSubstitution =>
      !currentSet.locked &&
      currentSet.substitutions.isNotEmpty &&
      !currentSet.substitutions.last.auto &&
      !(currentSet.sanctions.isNotEmpty &&
          currentSet.sanctions.last.linkedSubstitutionEventId ==
              currentSet.substitutions.last.id);

  /// Revierte en memoria un cambio ya registrado (devuelve al jugador que
  /// había salido y descuenta el cupo si correspondía), sin notificar ni
  /// persistir: lo hacen los métodos públicos que lo usan.
  void _revertSubstitution(SubstitutionEvent removed) {
    final set = currentSet;
    set.currentOrderOwn[removed.slotIndex] = removed.playerOutId;
    if (removed.countedAgainstLimit) {
      set.substitutionsUsedOwn = (set.substitutionsUsedOwn - 1).clamp(0, 1 << 30);
    }
  }

  /// Deshace el último cambio de jugador del set (regular o de líbero),
  /// devolviendo al jugador que había salido y, si el cambio deshecho
  /// contaba contra el cupo, sin que quede contado.
  void undoLastSubstitution() {
    if (!canUndoLastSubstitution) return;
    _revertSubstitution(currentSet.substitutions.removeLast());
    notifyListeners();
    _persist();
  }

  /// Si el equipo propio sacó con un central y perdió el punto, entra
  /// automáticamente el líbero receptor en su lugar (cambio libre), siempre
  /// que esté configurado, en fila trasera y no esté ya en cancha.
  void _maybeAutoSubCentralForLibero(String serverId) {
    final liberoId = currentSet.receptionLiberoId;
    if (liberoId == null || liberoId == serverId) return;
    if (playerById(serverId)?.position != PlayerPosition.central) return;
    if (!canBringLiberoIn(liberoId, serverId)) return;
    bringLiberoIn(liberoId, serverId, auto: true);
  }

  /// Si hay un líbero en cancha y el equipo declaró dos líberos distintos,
  /// se asegura de que sea el que corresponde según quién saca ahora: el
  /// defensor si sacamos nosotros, el receptor si saca el rival. Se dispara
  /// en cada cambio de saque (side-out) para que el líbero correcto quede
  /// siempre en cancha sin necesidad de un cambio manual.
  void _maybeAutoSwapLiberoForServe() {
    final liberoIds = declaredLiberoIds;
    if (liberoIds.length < 2) return;
    final desiredId = _servingTeam == TeamSide.own
        ? currentSet.defensiveLiberoId
        : currentSet.receptionLiberoId;
    if (desiredId == null) return;
    for (var slot = 0; slot < 6; slot++) {
      final st = _slotState(slot);
      if (st.liberoOnCourtId == null) continue;
      if (st.liberoOnCourtId != desiredId && canSendLiberoOut(slot)) {
        swapLiberoToOther(slot, auto: true);
      }
      return;
    }
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

  /// Si está activado `currentSet.autoLiberoBackRowSwap`, entra
  /// automáticamente el líbero que corresponda por un central que queda en
  /// la fila de fondo: el defensor si el saque es nuestro, o el receptor si
  /// saca el rival (incluido al arrancar el set, si ya arranca sacando el
  /// rival) — la misma condición que hoy sugiere manualmente el panel de
  /// cambio de líbero ("Central en el fondo"), pero aplicada sola.
  /// `canBringLiberoIn` ya se encarga de no meter al líbero en el puesto que
  /// está a punto de sacar (solo aplica cuando el saque es nuestro), así que
  /// acá no hace falta repetir esa exclusión.
  void _maybeAutoSubLiberoForCentralInBackRow() {
    if (!currentSet.autoLiberoBackRowSwap) return;
    final liberoId =
        _servingTeam == TeamSide.own ? currentSet.defensiveLiberoId : currentSet.receptionLiberoId;
    if (liberoId == null) return;
    for (final p in onCourtPlayers.where((p) => p.position == PlayerPosition.central)) {
      final pos = courtPositionOf(p.id);
      if (pos == null || (pos != 1 && pos != 5 && pos != 6)) continue;
      if (!canBringLiberoIn(liberoId, p.id)) continue;
      bringLiberoIn(liberoId, p.id, auto: true);
      return; // solo puede entrar un líbero a la vez.
    }
  }

  // ---------------- Sanciones ----------------
  //
  // Regla 21 de la FIVB (conducta incorrecta y sus sanciones), vigente
  // también en FeVA y en las federaciones metropolitanas. La sanción que
  // corresponde depende de la categoría de la conducta y de cuántas veces ya
  // se sancionó a esa misma persona por esa misma categoría en el partido
  // (no se resetea entre sets, Regla 21.4.1). El Castigo (otorga punto) se
  // resuelve reutilizando `_addEvent`/`_resolvePoint` con un `RallyEvent` de
  // fase `sanction`, para que deshacer y retomar el partido (`resume`)
  // funcionen gratis con la misma lógica que cualquier punto jugado. La
  // Expulsión/Descalificación de alguien en cancha se resuelve con una
  // sustitución obligatoria (Regla 15.8) vía [substituteForSanction].

  /// Todas las sanciones cargadas en el partido (de todos los sets): sirven
  /// para calcular la escala (vale para todo el partido, no solo el set en
  /// curso) y para mostrar el historial en el panel de carga.
  List<SanctionEvent> get matchSanctions => match.sets.expand((s) => s.sanctions).toList();

  /// Clave estable para agrupar sanciones de la misma persona/banco a la
  /// hora de contar ocurrencias.
  String _sanctionTargetKey(TeamSide team, SanctionTargetKind kind,
      {String? playerId, int? rivalNumber}) {
    if (team == TeamSide.own) {
      return kind == SanctionTargetKind.staff ? 'own:staff' : 'own:$playerId';
    }
    return kind == SanctionTargetKind.staff ? 'rival:staff' : 'rival:$rivalNumber';
  }

  int _sanctionOccurrenceCount({
    required TeamSide team,
    required SanctionTargetKind targetKind,
    String? targetPlayerId,
    int? rivalNumber,
    required SanctionCategory category,
  }) {
    final key =
        _sanctionTargetKey(team, targetKind, playerId: targetPlayerId, rivalNumber: rivalNumber);
    return matchSanctions.where((s) {
      if (s.category != category) return false;
      return _sanctionTargetKey(s.team, s.targetKind,
              playerId: s.targetPlayerId, rivalNumber: s.rivalNumber) ==
          key;
    }).length;
  }

  /// Qué sanción correspondería ahora mismo si se cargara esta conducta, y
  /// qué ocurrencia sería (para que el panel de carga pueda mostrar el
  /// resultado antes de confirmar), sin registrar nada todavía.
  ({int occurrence, SanctionOutcome outcome}) previewSanction({
    required TeamSide team,
    required SanctionTargetKind targetKind,
    String? targetPlayerId,
    int? rivalNumber,
    required SanctionCategory category,
  }) {
    final occurrence = _sanctionOccurrenceCount(
          team: team,
          targetKind: targetKind,
          targetPlayerId: targetPlayerId,
          rivalNumber: rivalNumber,
          category: category,
        ) +
        1;
    return (occurrence: occurrence, outcome: computeSanctionOutcome(category, occurrence));
  }

  /// Registra una sanción/tarjeta del árbitro y aplica su consecuencia
  /// (punto y saque al rival si corresponde). Si además obliga a abandonar
  /// la cancha a alguien que está jugando, hay que llamar después a
  /// [substituteForSanction] con el reemplazo elegido (ver
  /// [eligibleReplacementsForSanction]).
  SanctionEvent registerSanction({
    required TeamSide team,
    required SanctionTargetKind targetKind,
    String? targetPlayerId,
    int? rivalNumber,
    required SanctionCategory category,
  }) {
    final rallyNumberAtSanction = _rallyCounter;
    final preview = previewSanction(
      team: team,
      targetKind: targetKind,
      targetPlayerId: targetPlayerId,
      rivalNumber: rivalNumber,
      category: category,
    );
    final occurrence = preview.occurrence;
    final outcome = preview.outcome;

    String? linkedRallyEventId;
    if (outcome.awardsPoint) {
      final winner = team == TeamSide.own ? TeamSide.rival : TeamSide.own;
      _addEvent(
        phase: RallyPhase.sanction,
        team: team,
        playerIds: targetPlayerId == null ? [] : [targetPlayerId],
        endsRally: true,
        winner: winner,
      );
      linkedRallyEventId = currentSet.events.last.id;
    }

    final sanction = SanctionEvent(
      id: generateId('san_'),
      setNumber: currentSet.setNumber,
      rallyNumber: rallyNumberAtSanction,
      team: team,
      targetKind: targetKind,
      targetPlayerId: targetPlayerId,
      rivalNumber: rivalNumber,
      category: category,
      occurrence: occurrence,
      outcome: outcome,
      linkedRallyEventId: linkedRallyEventId,
      ownScoreAfter: currentSet.ownScore,
      rivalScoreAfter: currentSet.rivalScore,
      timestamp: DateTime.now(),
    );
    currentSet.sanctions.add(sanction);
    notifyListeners();
    _persist();
    return sanction;
  }

  /// Suplentes elegibles para reemplazar a [playerOutId] (en cancha) por
  /// expulsión/descalificación (Regla 15.8): primero el suplente regular si
  /// todavía tiene cupo (sustitución legal normal); si no, cualquier
  /// suplente del banco salvo los líberos declarados (sustitución
  /// excepcional: no cuenta contra el límite, pero queda registrada).
  List<Player> eligibleReplacementsForSanction(String playerOutId) {
    if (canRegisterSubstitution && canSubOutRegular(playerOutId)) {
      final regular = eligibleRegularBenchFor(playerOutId);
      if (regular.isNotEmpty) return regular;
    }
    final liberoIds = declaredLiberoIds.toSet();
    return benchPlayers.where((p) => !liberoIds.contains(p.id)).toList();
  }

  /// true si reemplazar a [playerOutId] con [playerInId] es la sustitución
  /// legal normal (cuenta contra el cupo) en vez de la sustitución
  /// excepcional de la Regla 15.7 (libre, no cuenta).
  bool _isRegularSanctionReplacement(String playerOutId, String playerInId) =>
      canRegisterSubstitution &&
      canSubOutRegular(playerOutId) &&
      eligibleRegularBenchFor(playerOutId).any((p) => p.id == playerInId);

  /// Reemplazo obligatorio de un jugador expulsado/descalificado (Regla
  /// 15.8): se llama después de [registerSanction] cuando su resultado
  /// obliga a salir de cancha y la persona sancionada estaba jugando.
  void substituteForSanction(String sanctionEventId, String playerOutId, String playerInId) {
    final idx = currentSet.sanctions.indexWhere((s) => s.id == sanctionEventId);
    if (idx == -1) return;
    final slot = currentSet.currentOrderOwn.indexOf(playerOutId);
    if (slot == -1) return;
    final regular = _isRegularSanctionReplacement(playerOutId, playerInId);
    _applySubstitution(
      slotIndex: slot,
      playerInId: playerInId,
      countsAgainstLimit: regular,
      isLiberoAction: false,
    );
    final old = currentSet.sanctions[idx];
    currentSet.sanctions[idx] = SanctionEvent(
      id: old.id,
      setNumber: old.setNumber,
      rallyNumber: old.rallyNumber,
      team: old.team,
      targetKind: old.targetKind,
      targetPlayerId: old.targetPlayerId,
      rivalNumber: old.rivalNumber,
      category: old.category,
      occurrence: old.occurrence,
      outcome: old.outcome,
      linkedRallyEventId: old.linkedRallyEventId,
      linkedSubstitutionEventId: currentSet.substitutions.last.id,
      ownScoreAfter: old.ownScoreAfter,
      rivalScoreAfter: old.rivalScoreAfter,
      timestamp: old.timestamp,
    );
    notifyListeners();
    _persist();
  }

  /// Deshace el último evento cargado (corrige un toque mal tocado).
  void undoLast() {
    final set = currentSet;
    if (set.locked || set.events.isEmpty) return;
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
      if (removed.pointWinner != removed.servingTeamBefore) {
        if (removed.pointWinner == TeamSide.own) {
          _rotationOffsetOwn = (_rotationOffsetOwn - 1) % 6;
        } else {
          _rivalRotationOffset = (_rivalRotationOffset - 1) % 6;
        }
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
        case RallyPhase.sanction:
          // Estas fases siempre terminan el punto; no deberían caer acá.
          _stage = RallyStage.defending;
          break;
      }
    }
    notifyListeners();
    _persist();
  }

  /// true si hay algo para deshacer con [undoLastAction]: una jugada, una
  /// sanción, o un cambio manual (los automáticos no cuentan como acción
  /// propia, siempre se deshacen junto con la jugada que los disparó).
  bool get canUndoLastAction =>
      !currentSet.locked &&
      (currentSet.events.isNotEmpty ||
          (currentSet.substitutions.isNotEmpty && !currentSet.substitutions.last.auto) ||
          currentSet.sanctions.isNotEmpty);

  /// Deshace la última acción cargada en el set, sea una jugada (saque,
  /// ataque, punto/error rival, etc.), una sanción/tarjeta, o un cambio de
  /// jugador manual, lo que haya pasado más recientemente. Los cambios
  /// automáticos que hayan quedado colgando al final del log de cambios se
  /// revierten primero, pero solo si de verdad son lo más reciente que pasó
  /// en el set (comparando contra el último evento y la última sanción): un
  /// automático viejo, ya superado en el tiempo por una sanción o jugada
  /// posterior, no se toca acá — deshacer esa jugada tiene que deshacer sus
  /// propios automáticos, no los de un punto anterior que ya quedó resuelto.
  void undoLastAction() {
    while (true) {
      final lastSub = currentSet.substitutions.isNotEmpty ? currentSet.substitutions.last : null;
      if (lastSub == null || !lastSub.auto) break;
      final lastEvent = currentSet.events.isNotEmpty ? currentSet.events.last : null;
      final lastSanction = currentSet.sanctions.isNotEmpty ? currentSet.sanctions.last : null;
      final subIsMostRecent =
          (lastEvent == null || !lastEvent.timestamp.isAfter(lastSub.timestamp)) &&
          (lastSanction == null || !lastSanction.timestamp.isAfter(lastSub.timestamp));
      if (!subIsMostRecent) break;
      _revertSubstitution(currentSet.substitutions.removeLast());
    }
    final lastSanction = currentSet.sanctions.isNotEmpty ? currentSet.sanctions.last : null;
    final lastSub = currentSet.substitutions.isNotEmpty ? currentSet.substitutions.last : null;
    final lastEvent = currentSet.events.isNotEmpty ? currentSet.events.last : null;

    // Si el último cambio es el reemplazo obligatorio de la última sanción
    // (Expulsión/Descalificación), se deshacen juntos como una sola acción:
    // el cambio se cargó en un segundo paso, así que puede ser más nuevo por
    // timestamp que la sanción, pero no es una acción independiente de ella.
    if (lastSanction != null &&
        lastSub != null &&
        lastSanction.linkedSubstitutionEventId == lastSub.id) {
      currentSet.sanctions.removeLast();
      currentSet.substitutions.removeLast();
      _revertSubstitution(lastSub);
      notifyListeners();
      _persist();
      return;
    }

    final sanctionIsLatest = lastSanction != null &&
        (lastSub == null || !lastSub.timestamp.isAfter(lastSanction.timestamp)) &&
        (lastEvent == null || !lastEvent.timestamp.isAfter(lastSanction.timestamp));

    if (sanctionIsLatest) {
      currentSet.sanctions.removeLast();
      if (lastSanction.linkedRallyEventId != null) {
        undoLast(); // el RallyEvent vinculado es exactamente set.events.last.
        return;
      }
      notifyListeners();
      _persist();
      return;
    }

    if (lastSub != null && (lastEvent == null || lastSub.timestamp.isAfter(lastEvent.timestamp))) {
      currentSet.substitutions.removeLast();
      _revertSubstitution(lastSub);
      notifyListeners();
      _persist();
    } else if (lastEvent != null) {
      undoLast();
    } else {
      notifyListeners();
      _persist();
    }
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

  static const _rivalErrorTypePool = [
    RivalAction.serve,
    RivalAction.attack,
    RivalAction.counter,
    RivalAction.generic,
  ];

  String _randomRivalErrorType() => _rivalErrorTypePool[_rng.nextInt(_rivalErrorTypePool.length)];

  int? _randomZone() => currentSet.trackHitZones ? 1 + _rng.nextInt(6) : null;

  /// Juega un punto completo a partir del estado actual, eligiendo al azar
  /// jugador/calificación/resultado en cada toque, reutilizando los mismos
  /// métodos `log*` que usan los botones de carga manual. Pensado para
  /// probar la app rápido sin cargar cada toque a mano.
  void simulateOnePoint() {
    if (currentSet.finished) return;
    final rallyBefore = _rallyCounter;
    var guard = 0;
    while (_rallyCounter == rallyBefore && guard < 60) {
      guard++;
      switch (_stage) {
        case RallyStage.serveOwn:
          logServe(_randomPlayerId(), _randomGrade(_serveGradePool), targetZone: _randomZone());
          break;
        case RallyStage.receiveOwn:
          logReception(_randomPlayerId(), _randomGrade(_receptionGradePool));
          break;
        case RallyStage.attackK1Own:
          logAttack(_randomPlayerId(), _randomGrade(_attackGradePool), targetZone: _randomZone());
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
      logCounter(_randomPlayerId(), _randomGrade(_attackGradePool), targetZone: _randomZone());
    } else if (roll < 0.65) {
      final blockers = onCourtPlayers..shuffle(_rng);
      logBlockPoint(blockers.take(1 + _rng.nextInt(2)).map((p) => p.id).toList());
    } else if (roll < 0.8) {
      logGenericError(playerId: _rng.nextBool() ? _randomPlayerId() : null);
    } else if (roll < 0.9) {
      logOpponentPoint(
          rivalActionType: _rng.nextBool() ? RivalAction.attack : RivalAction.counter);
    } else {
      logOpponentError(rivalActionType: _randomRivalErrorType());
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
    while (!currentSet.finished && guard < 500) {
      simulateOnePoint();
      if (!currentSet.finished) {
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
    int? targetZone,
    String? rivalActionType,
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
      targetZone: set.trackHitZones ? targetZone : null,
      rivalActionType: rivalActionType,
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
      // Side-out: el equipo que gana pasa a sacar y rota (la del rival es
      // solo para ubicar a su armador; no llevamos el resto de su equipo).
      if (winner == TeamSide.own) {
        _rotationOffsetOwn = (_rotationOffsetOwn + 1) % 6;
        _releaseLiberosRotatingToFrontRow();
      } else {
        _rivalRotationOffset = (_rivalRotationOffset + 1) % 6;
      }
      _servingTeam = winner;
      _maybeAutoSwapLiberoForServe();
      // Se evalúa acá (con _servingTeam ya actualizado) y no solo dentro de
      // la rama "winner == own" de arriba: corre para los dos lados del
      // side-out, y el propio método elige el líbero defensor o el
      // receptor según a quién le tocó sacar ahora.
      _maybeAutoSubLiberoForCentralInBackRow();
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
      // OJO: acá NO se marca match.status = finished ni needsNextSetSetup —
      // eso queda pendiente de que se confirme con confirmSetFinished(), así
      // el árbitro todavía puede revertir el último punto y se puede seguir
      // deshaciendo hasta ese momento (ver [canConfirmSetFinished]).
      notifyListeners();
      return;
    }

    _stage = _servingTeam == TeamSide.own ? RallyStage.serveOwn : RallyStage.receiveOwn;
    notifyListeners();
  }

  /// true una vez que el set en curso llegó a su puntaje de cierre pero
  /// todavía no se confirmó con [confirmSetFinished] (el árbitro todavía
  /// podría revertir el último punto).
  bool get canConfirmSetFinished => currentSet.finished && !currentSet.locked;

  /// Confirma que el set (o, si es el decisivo, el partido entero) terminó
  /// de verdad: a partir de acá el set queda bloqueado y no se puede
  /// deshacer ningún punto más.
  void confirmSetFinished() {
    if (!canConfirmSetFinished) return;
    currentSet.locked = true;
    if (match.isMatchOver) {
      match.status = MatchStatus.finished;
    } else {
      needsNextSetSetup = true;
    }
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    await StorageService.instance.saveMatch(match);
  }
}
