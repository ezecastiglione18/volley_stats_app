import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/match_set.dart';
import '../models/player.dart';
import '../models/rally_event.dart';
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

class MatchController extends ChangeNotifier {
  VolleyMatch match;
  int _rotationOffsetOwn = 0;
  TeamSide _servingTeam = TeamSide.own;
  RallyStage _stage = RallyStage.serveOwn;
  int _rallyCounter = 1;
  bool needsNextSetSetup = false;

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
      if (ev.endsRally && ev.pointWinner != null) {
        final wasServing = controller._servingTeam;
        if (ev.pointWinner != wasServing) {
          if (ev.pointWinner == TeamSide.own) {
            controller._rotationOffsetOwn = (controller._rotationOffsetOwn + 1) % 6;
          }
          controller._servingTeam = ev.pointWinner!;
        }
        controller._rallyCounter++;
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

  /// Jugador propio actualmente en la posición [pos] (1 a 6).
  String playerAtPosition(int pos) {
    final order = currentSet.startingOrderOwn;
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
  /// pidiendo la pantalla en vivo, igual que en una carga manual.
  void simulateRestOfSet() {
    var guard = 0;
    while (!needsNextSetSetup && match.status != MatchStatus.finished && guard < 500) {
      simulateOnePoint();
      guard++;
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

    if (winner != wasServing) {
      // Side-out: el equipo que gana pasa a sacar y, si es el propio, rota.
      if (winner == TeamSide.own) {
        _rotationOffsetOwn = (_rotationOffsetOwn + 1) % 6;
      }
      _servingTeam = winner;
    }

    _rallyCounter++;

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
