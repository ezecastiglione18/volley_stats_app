import '../models/player.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

/// Una fila de la comparación de equipo entre dos partidos (A y B).
class CompareRow {
  const CompareRow({
    required this.metric,
    required this.a,
    required this.b,
    required this.delta,
    required this.improved,
    this.isPct = false,
    this.isRecord = false,
  });

  final String metric;

  /// Valores ya formateados para mostrar ("12", "38%", "3-1", "-").
  final String a;
  final String b;

  /// B − A. En los porcentajes, en puntos porcentuales; en los sets, cambio
  /// en la diferencia ganados − perdidos. Null si falta el dato en alguno.
  final int? delta;

  /// true = B mejora respecto de A, false = empeora, null = igual o sin dato.
  final bool? improved;

  final bool isPct;
  final bool isRecord;

  /// "+4", "-7", "0" o "-" si no hay dato; en los sets, ▲ / ▼ / =.
  String get deltaLabel {
    final d = delta;
    if (d == null) return '-';
    if (isRecord) return d > 0 ? '▲' : (d < 0 ? '▼' : '=');
    return d > 0 ? '+$d' : '$d';
  }
}

/// Comparador de dos partidos (documents/RallyStats-Funcionalidades-
/// Pendientes.pdf, sección 4). Todo sale de [StatsEngine.compute] y de los
/// sets ganados de [VolleyMatch]; acá solo se restan y se decide el sentido
/// de la mejora.
class MatchCompare {
  /// Filas de equipo de A contra B (partido completo).
  static List<CompareRow> compareMatches(VolleyMatch a, VolleyMatch b) => compareTeam(
        a: StatsEngine.compute(a),
        b: StatsEngine.compute(b),
        setsA: (a.ownSetsWon, a.rivalSetsWon),
        setsB: (b.ownSetsWon, b.rivalSetsWon),
      );

  static List<CompareRow> compareTeam({
    required MatchStats a,
    required MatchStats b,
    required (int, int) setsA,
    required (int, int) setsB,
  }) {
    final ta = a.team;
    final tb = b.team;
    final setDelta = (setsB.$1 - setsB.$2) - (setsA.$1 - setsA.$2);
    return [
      CompareRow(
        metric: 'Sets (ganados-perdidos)',
        a: '${setsA.$1}-${setsA.$2}',
        b: '${setsB.$1}-${setsB.$2}',
        delta: setDelta,
        improved: setDelta == 0 ? null : setDelta > 0,
        isRecord: true,
      ),
      _count('Puntos totales', ta.totalPts, tb.totalPts),
      _count('Puntos de saque', ta.saque.pp, tb.saque.pp),
      _count('Puntos de ataque', ta.ataque.pp, tb.ataque.pp),
      _count('Puntos de contra', ta.contra.pp, tb.contra.pp),
      _count('Puntos de bloqueo', ta.bloqueoPts, tb.bloqueoPts),
      _count('Errores de saque', ta.saque.nn, tb.saque.nn, lowerIsBetter: true),
      _count('Errores de ataque', ta.ataque.nn, tb.ataque.nn, lowerIsBetter: true),
      _count('Errores generales', ta.errGen, tb.errGen, lowerIsBetter: true),
      _pct('Eficacia de ataque', ta.ataque.pctPoint, tb.ataque.pctPoint),
      _pct('Eficacia de recepción', ta.recepcion.efficiency, tb.recepcion.efficiency),
      // Errores del rival: que suban es bueno para nosotros.
      _count('Errores del rival', a.rivalErrors.total, b.rivalErrors.total),
    ];
  }

  static CompareRow _count(String metric, int a, int b, {bool lowerIsBetter = false}) {
    final d = b - a;
    return CompareRow(
      metric: metric,
      a: '$a',
      b: '$b',
      delta: d,
      improved: d == 0 ? null : (lowerIsBetter ? d < 0 : d > 0),
    );
  }

  /// Los porcentajes se redondean antes de restar, para que el delta
  /// coincida con la resta de lo que se ve en pantalla.
  static CompareRow _pct(String metric, double? a, double? b) {
    final pa = a == null ? null : (a * 100).round();
    final pb = b == null ? null : (b * 100).round();
    final d = pa == null || pb == null ? null : pb - pa;
    return CompareRow(
      metric: metric,
      a: pa == null ? '-' : '$pa%',
      b: pb == null ? '-' : '$pb%',
      delta: d,
      improved: d == null || d == 0 ? null : d > 0,
      isPct: true,
    );
  }

  /// Jugadores presentes en los planteles de los dos partidos (mismo
  /// [Player.id], o sea, armados desde el mismo equipo), ordenados por el
  /// número con el que jugaron B.
  static List<Player> sharedPlayers(VolleyMatch a, VolleyMatch b) {
    final idsA = {for (final p in a.ownRoster) p.id};
    return b.ownRoster.where((p) => idsA.contains(p.id)).toList()..sort((x, y) => x.number.compareTo(y.number));
  }
}
