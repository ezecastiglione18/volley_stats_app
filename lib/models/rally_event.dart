/// Fase / categoría de la acción registrada.
enum RallyPhase {
  serve, // Saque
  reception, // Recepción
  attack, // Ataque (K1, tras recepción propia)
  counter, // Contra (K2+, tras defensa/bloqueo)
  block, // Bloqueo (punto de bloqueo)
  genericError, // Error General (rotación, 4 toques, etc.)
  opponentPoint, // Punto Rival (no atribuible a jugador propio)
  opponentError, // Error Rival (no forzado)
}

/// A qué equipo pertenece la acción (siempre relativo a "mi equipo").
enum TeamSide { own, rival }

/// Códigos de calificación usados en las distintas fases.
/// Saque / Ataque / Contra: PP, P, N, NN (+ BLOQ para ataque/contra bloqueado)
/// Recepción: PP, P, EXCL (!), N, VNEG (V-), NN
class Grade {
  static const pp = 'PP';
  static const p = 'P';
  static const n = 'N';
  static const nn = 'NN';
  static const excl = '!';
  static const vNeg = 'V-';
  static const bloq = 'BLOQ';
}

/// Subtipo de la jugada rival que originó un error propio a favor (Error
/// Rival: qué tocó el rival y falló) o un punto directo del rival (Punto
/// Rival: con qué tocó el rival para ganar el punto). Se guarda en
/// [RallyEvent.rivalActionType]; en partidos cargados antes de este campo
/// queda `null` (la estadística lo trata como "genérico" en errores y "sin
/// clasificar" en puntos).
class RivalAction {
  static const serve = 'serve';
  static const attack = 'attack';
  static const counter = 'counter';
  static const generic = 'generic';
}

class RallyEvent {
  final String id;
  final int setNumber;
  final int rallyNumber; // número de punto dentro del set
  final RallyPhase phase;
  final TeamSide team; // equipo que ejecuta la acción
  final List<String> playerIds; // jugadores propios involucrados (0-2)
  final String? grade; // código de calificación (puede ser null)
  final bool endsRally;
  final TeamSide? pointWinner; // solo si endsRally == true
  final TeamSide servingTeamBefore; // quién sacaba antes de este evento
  final int ownScoreAfter;
  final int rivalScoreAfter;
  final DateTime timestamp;

  /// Zona de cancha (1-6) a la que fue dirigido el toque. Solo aplica a
  /// saque, ataque y contra, y solo si el set tiene activado el registro de
  /// zonas (`MatchSet.trackHitZones`); en el resto de los casos es null.
  final int? targetZone;

  /// Solo para `opponentError`/`opponentPoint`: con qué tocó el rival (ver
  /// [RivalAction]). Null en el resto de las fases.
  final String? rivalActionType;

  RallyEvent({
    required this.id,
    required this.setNumber,
    required this.rallyNumber,
    required this.phase,
    required this.team,
    this.playerIds = const [],
    this.grade,
    required this.endsRally,
    this.pointWinner,
    required this.servingTeamBefore,
    required this.ownScoreAfter,
    required this.rivalScoreAfter,
    required this.timestamp,
    this.targetZone,
    this.rivalActionType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'rallyNumber': rallyNumber,
        'phase': phase.name,
        'team': team.name,
        'playerIds': playerIds,
        'grade': grade,
        'endsRally': endsRally,
        'pointWinner': pointWinner?.name,
        'servingTeamBefore': servingTeamBefore.name,
        'ownScoreAfter': ownScoreAfter,
        'rivalScoreAfter': rivalScoreAfter,
        'timestamp': timestamp.toIso8601String(),
        'targetZone': targetZone,
        'rivalActionType': rivalActionType,
      };

  factory RallyEvent.fromJson(Map<dynamic, dynamic> json) => RallyEvent(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        rallyNumber: (json['rallyNumber'] as num).toInt(),
        phase: RallyPhase.values.firstWhere((e) => e.name == json['phase']),
        team: TeamSide.values.firstWhere((e) => e.name == json['team']),
        playerIds: ((json['playerIds'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        grade: json['grade'] as String?,
        endsRally: json['endsRally'] as bool? ?? false,
        pointWinner: json['pointWinner'] == null
            ? null
            : TeamSide.values.firstWhere((e) => e.name == json['pointWinner']),
        servingTeamBefore: json['servingTeamBefore'] == null
            ? TeamSide.own
            : TeamSide.values.firstWhere((e) => e.name == json['servingTeamBefore']),
        ownScoreAfter: (json['ownScoreAfter'] as num?)?.toInt() ?? 0,
        rivalScoreAfter: (json['rivalScoreAfter'] as num?)?.toInt() ?? 0,
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                DateTime.now(),
        targetZone: (json['targetZone'] as num?)?.toInt(),
        rivalActionType: json['rivalActionType'] as String?,
      );
}
