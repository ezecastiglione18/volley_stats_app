/// Rotación manual del equipo propio dentro de un set (sin side-out), solo
/// disponible si el partido tiene activado `MatchConfig.allowManualRotation`.
/// Queda en el log del set igual que un punto o un cambio, para que
/// "Deshacer última acción" la pueda revertir y `MatchController.resume` la
/// vuelva a aplicar al retomar el partido.
class ManualRotationEvent {
  final String id;
  final int setNumber;
  final int rallyNumber;

  /// +1 = un puesto hacia adelante (como en un side-out: 2→1, 1→6...);
  /// -1 = un puesto hacia atrás (1→2, 6→1...).
  final int steps;

  final DateTime timestamp;

  ManualRotationEvent({
    required this.id,
    required this.setNumber,
    required this.rallyNumber,
    required this.steps,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'rallyNumber': rallyNumber,
        'steps': steps,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ManualRotationEvent.fromJson(Map<dynamic, dynamic> json) => ManualRotationEvent(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        rallyNumber: (json['rallyNumber'] as num?)?.toInt() ?? 1,
        steps: (json['steps'] as num?)?.toInt() ?? 1,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}
