import 'player.dart';

/// Conteo de calificaciones para Saque / Ataque / Contra (escala PP/P/N/NN,
/// con BLOQ adicional para ataque y contra).
class TouchStats {
  int pp = 0;
  int p = 0;
  int n = 0;
  int nn = 0;
  int bloq = 0; // solo aplica a Ataque / Contra

  int get total => pp + p + n + nn + bloq;
}

/// Conteo de calificaciones de Recepción (escala PP/P/!/N/V-/NN).
class ReceptionStats {
  int pp = 0;
  int p = 0;
  int excl = 0;
  int n = 0;
  int vNeg = 0;
  int nn = 0;

  int get total => pp + p + excl + n + vNeg + nn;

  /// Efectividad = (PP + P) / Total, tal como en la planilla original.
  double? get efficiency => total == 0 ? null : (pp + p) / total;
}

class PlayerStatLine {
  final String playerId;
  final String displayName;
  final int number;

  /// Posición del jugador (null para la fila "No Asignado" o "Total Equipo").
  final PlayerPosition? position;

  final TouchStats saque = TouchStats();
  final TouchStats ataque = TouchStats();
  final TouchStats contra = TouchStats();
  int bloqueoPts = 0;
  int errGen = 0;
  final ReceptionStats recepcion = ReceptionStats();

  PlayerStatLine({
    required this.playerId,
    required this.displayName,
    required this.number,
    this.position,
  });

  int get totalPts => saque.pp + ataque.pp + contra.pp + bloqueoPts;

  int get totalErr =>
      saque.nn +
      ataque.bloq +
      ataque.nn +
      contra.bloq +
      contra.nn +
      errGen +
      recepcion.nn;
}

/// Estadística de saque y ataque (ataque + contra combinados) por zona de
/// cancha de destino (1-6), solo con los toques que tienen zona registrada.
class ZoneStats {
  final Map<int, TouchStats> serveByZone;
  final Map<int, TouchStats> attackByZone;

  /// Igual que [serveByZone] / [attackByZone], pero desglosado por jugador
  /// (clave = playerId). Cada jugador solo aparece si tuvo al menos un
  /// toque con zona registrada.
  final Map<String, Map<int, TouchStats>> serveByZoneByPlayer;
  final Map<String, Map<int, TouchStats>> attackByZoneByPlayer;

  ZoneStats({
    required this.serveByZone,
    required this.attackByZone,
    required this.serveByZoneByPlayer,
    required this.attackByZoneByPlayer,
  });

  bool get hasAnyData =>
      serveByZone.values.any((s) => s.total > 0) || attackByZone.values.any((s) => s.total > 0);
}
