/// Uno o más líberos que quedan sin poder jugar el resto del partido (Regla
/// 19.4.1 de la FIVB: lesión, enfermedad, expulsión o descalificación, o
/// porque el entrenador lo declara así) y, si con eso el equipo se queda sin
/// ningún líbero disponible, el jugador que pasa a ser el nuevo líbero hasta
/// el final del partido (redesignación, Regla 19.4.2). Queda en el log del
/// set igual que un cambio o una rotación manual, para que "Deshacer última
/// acción" lo pueda revertir y `MatchController.resume` no tenga que
/// reconstruir nada aparte: quién es líbero en cada momento se deriva de
/// estos eventos (ver `VolleyMatch.liberoIds`).
class LiberoUnableEvent {
  final String id;
  final int setNumber;
  final int rallyNumber;

  /// Líberos (de la planilla o redesignados antes) que no pueden volver a
  /// jugar en el resto del partido.
  final List<String> unableLiberoIds;

  /// Jugador redesignado como líbero (no puede estar en cancha en ese
  /// momento ni ser el reemplazado por el líbero). Null si solo se declaró
  /// a un líbero sin poder jugar y el equipo todavía tiene otro.
  final String? newLiberoId;

  /// Si el líbero que no puede seguir estaba en cancha: el cambio de líbero
  /// con el que salió (vuelve el jugador al que reemplazaba, entra el otro
  /// líbero o directamente el redesignado). Se deshace junto con este evento.
  final String? linkedSubstitutionEventId;

  final DateTime timestamp;

  LiberoUnableEvent({
    required this.id,
    required this.setNumber,
    required this.rallyNumber,
    required this.unableLiberoIds,
    this.newLiberoId,
    this.linkedSubstitutionEventId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'rallyNumber': rallyNumber,
        'unableLiberoIds': unableLiberoIds,
        'newLiberoId': newLiberoId,
        'linkedSubstitutionEventId': linkedSubstitutionEventId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LiberoUnableEvent.fromJson(Map<dynamic, dynamic> json) => LiberoUnableEvent(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        rallyNumber: (json['rallyNumber'] as num?)?.toInt() ?? 1,
        unableLiberoIds:
            ((json['unableLiberoIds'] as List?) ?? []).map((e) => e.toString()).toList(),
        newLiberoId: json['newLiberoId'] as String?,
        linkedSubstitutionEventId: json['linkedSubstitutionEventId'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}
