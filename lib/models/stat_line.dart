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

  /// % de punto directo, para Ataque/Contra = PP / Total.
  double? get pctPoint => total == 0 ? null : pp / total;

  /// % de efectividad de saque = (PP + P) / Total (bloq siempre 0 acá).
  double? get pctServe => total == 0 ? null : (pp + p) / total;
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

  /// Cantidad de tarjetas amarillas y rojas mostradas (una sanción puede
  /// contar para las dos a la vez, p. ej. Expulsión = roja + amarilla).
  int yellowCards = 0;
  int redCards = 0;

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

/// Errores del equipo rival por tipo de toque (los cuenta el equipo propio
/// al marcar "Error Rival" con la opción correspondiente). `generic` incluye
/// también los errores rivales cargados antes de este campo (sin subtipo
/// guardado).
class RivalErrorStats {
  int serve = 0;
  int attack = 0;
  int counter = 0;
  int generic = 0;

  int get total => serve + attack + counter + generic;
}

/// Puntos ganados por el rival con su propio toque (ataque o contra), sin
/// que medie un error propio. `unclassified` cubre los puntos rivales
/// cargados antes de este campo (sin subtipo guardado).
class RivalPointStats {
  int attack = 0;
  int counter = 0;
  int unclassified = 0;

  int get total => attack + counter + unclassified;
}

/// Sanciones/tarjetas mostradas al equipo rival (no se lleva roster rival
/// jugador por jugador, así que es un total de equipo, no por jugador).
class RivalSanctionStats {
  int yellowCards = 0;
  int redCards = 0;
}

/// Estadística de saque, ataque y contraataque por zona de cancha de
/// destino (1-9; las zonas 7-9 solo tienen datos en sets cargados con
/// "9 zonas"), solo con los toques que tienen zona registrada.
class ZoneStats {
  final Map<int, TouchStats> serveByZone;
  final Map<int, TouchStats> attackByZone;
  final Map<int, TouchStats> counterByZone;

  /// Igual que [serveByZone] / [attackByZone] / [counterByZone], pero
  /// desglosado por jugador (clave = playerId). Cada jugador solo aparece si
  /// tuvo al menos un toque con zona registrada.
  final Map<String, Map<int, TouchStats>> serveByZoneByPlayer;
  final Map<String, Map<int, TouchStats>> attackByZoneByPlayer;
  final Map<String, Map<int, TouchStats>> counterByZoneByPlayer;

  ZoneStats({
    required this.serveByZone,
    required this.attackByZone,
    required this.counterByZone,
    required this.serveByZoneByPlayer,
    required this.attackByZoneByPlayer,
    required this.counterByZoneByPlayer,
  });

  bool get hasAnyData =>
      serveByZone.values.any((s) => s.total > 0) ||
      attackByZone.values.any((s) => s.total > 0) ||
      counterByZone.values.any((s) => s.total > 0);

  /// true si algún toque se registró en las zonas 7-9 (franja media).
  bool get hasMiddleZoneData {
    for (var z = 7; z <= 9; z++) {
      if ((serveByZone[z]?.total ?? 0) > 0 ||
          (attackByZone[z]?.total ?? 0) > 0 ||
          (counterByZone[z]?.total ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  /// Zonas a mostrar en los reportes: 1-6 siempre, y 7-9 solo si hay algún
  /// toque registrado en ellas (para no sumar columnas vacías a los
  /// partidos cargados con 6 zonas).
  List<int> get displayZones => [for (var z = 1; z <= (hasMiddleZoneData ? 9 : 6); z++) z];
}
