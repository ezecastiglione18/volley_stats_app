/// Registro de un cambio de jugador dentro de un set (manual o automático).
/// El estado vigente de emparejamientos (quién puede salir/entrar por quién)
/// se reconstruye reproduciendo esta lista en orden — no se persiste aparte.
class SubstitutionEvent {
  final String id;
  final int setNumber;
  final int rallyNumber;

  /// Índice fijo (0-5) dentro de `startingOrderOwn`/`currentOrderOwn`: es el
  /// "slot" de rotación afectado, no la posición en cancha (que cambia con
  /// la rotación). Sirve para reconstruir el emparejamiento titular/suplente
  /// y líbero/reemplazado de ese slot en particular.
  final int slotIndex;

  /// Posición en cancha (1-6) en el momento del cambio. Solo informativo.
  final int position;

  final String playerOutId;
  final String playerInId;

  /// false si el cambio es de líbero (libre, no descuenta del límite del set).
  final bool countedAgainstLimit;

  /// true si interviene un líbero (entrada, salida o líbero por líbero).
  final bool isLiberoAction;

  /// true si fue un cambio automático (central -> líbero receptor al perder
  /// el saque, o la salida forzada del líbero al rotar a la fila delantera).
  final bool auto;

  final DateTime timestamp;

  SubstitutionEvent({
    required this.id,
    required this.setNumber,
    required this.rallyNumber,
    required this.slotIndex,
    required this.position,
    required this.playerOutId,
    required this.playerInId,
    required this.countedAgainstLimit,
    required this.isLiberoAction,
    this.auto = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'rallyNumber': rallyNumber,
        'slotIndex': slotIndex,
        'position': position,
        'playerOutId': playerOutId,
        'playerInId': playerInId,
        'countedAgainstLimit': countedAgainstLimit,
        'isLiberoAction': isLiberoAction,
        'auto': auto,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SubstitutionEvent.fromJson(Map<dynamic, dynamic> json) => SubstitutionEvent(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        rallyNumber: (json['rallyNumber'] as num?)?.toInt() ?? 1,
        slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num).toInt(),
        playerOutId: json['playerOutId'] as String,
        playerInId: json['playerInId'] as String,
        countedAgainstLimit: json['countedAgainstLimit'] as bool? ?? true,
        isLiberoAction: json['isLiberoAction'] as bool? ?? false,
        auto: json['auto'] as bool? ?? false,
        timestamp:
            DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}
