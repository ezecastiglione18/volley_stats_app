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
