import 'rally_event.dart';
import 'stat_line.dart';

/// Gráficos de la estadística visual: los de la pestaña "Gráficos" de
/// Estadísticas y los que se pueden incluir en el PDF del partido (cuáles
/// van al PDF se elige en Configuración, ver
/// `StorageService.loadPdfVisualCharts`). El orden de los valores es el
/// orden en que se muestran en los dos lados.
enum VisualChart {
  dashboard,
  rotations,
  sideOutBreak,
  timeline,
  pointOrigin,
  attackEfficiency,
  reception,
  heatmap,
}

extension VisualChartInfo on VisualChart {
  String get label {
    switch (this) {
      case VisualChart.dashboard:
        return 'Tablero rápido';
      case VisualChart.rotations:
        return 'Rendimiento por rotación';
      case VisualChart.sideOutBreak:
        return 'Side-out y break-point por rotación';
      case VisualChart.timeline:
        return 'Evolución del marcador';
      case VisualChart.pointOrigin:
        return 'Origen de los puntos';
      case VisualChart.attackEfficiency:
        return 'Eficiencia de ataque por jugador';
      case VisualChart.reception:
        return 'Recepción por jugador';
      case VisualChart.heatmap:
        return 'Mapa de calor por zona';
    }
  }

  String get description {
    switch (this) {
      case VisualChart.dashboard:
        return 'Side-out, break-point, eficiencia de ataque y errores no forzados.';
      case VisualChart.rotations:
        return 'Tabla P1–P6 y diferencia de puntos ganados y perdidos en cada rotación.';
      case VisualChart.sideOutBreak:
        return '% de rallies ganados recibiendo y sacando, en cada rotación.';
      case VisualChart.timeline:
        return 'Diferencia del marcador rally por rally, con las rachas marcadas.';
      case VisualChart.pointOrigin:
        return 'De dónde salen los puntos ganados y cómo se pierden los perdidos.';
      case VisualChart.attackEfficiency:
        return '(Puntos − errores − bloqueados) / total, ataque y contra juntos.';
      case VisualChart.reception:
        return 'Distribución PP / P / ! / N / V- / NN de cada receptor.';
      case VisualChart.heatmap:
        return 'Zonas de destino de saque, ataque y contra pintadas sobre la cancha.';
    }
  }
}

/// Fundamento de un mapa de dirección (pestaña "Mapas" y planilla por
/// jugador del PDF).
enum ShotKind { serve, attack, counter }

extension ShotKindInfo on ShotKind {
  String get label {
    switch (this) {
      case ShotKind.serve:
        return 'Saque';
      case ShotKind.attack:
        return 'Ataque';
      case ShotKind.counter:
        return 'Contraataque';
    }
  }

  /// Etiqueta corta para selectores angostos.
  String get shortLabel => this == ShotKind.counter ? 'Contra' : label;

  String get description {
    switch (this) {
      case ShotKind.serve:
        return 'Hacia dónde saca cada jugador y con qué resultado.';
      case ShotKind.attack:
        return 'Ataque de primera bola (K1), después de la recepción propia.';
      case ShotKind.counter:
        return 'Contraataque (K2+), después de una defensa o un bloqueo.';
    }
  }
}

/// Resultado de un toque, que define el trazo de su flecha (spec 5.2).
/// [out] y [net] llegan con la Etapa 3 (carga precisa); hasta entonces todo
/// NN se dibuja como [error].
enum ShotResult { point, inPlay, out, net, blocked, error }

extension ShotResultInfo on ShotResult {
  String get label {
    switch (this) {
      case ShotResult.point:
        return 'Punto';
      case ShotResult.inPlay:
        return 'Adentro, sin punto';
      case ShotResult.out:
        return 'Afuera';
      case ShotResult.net:
        return 'A la red';
      case ShotResult.blocked:
        return 'Bloqueado';
      case ShotResult.error:
        return 'Error';
    }
  }
}

/// Un toque dibujable como flecha: origen y destino en coordenadas de cancha
/// (ver `CourtGeometry`).
class CourtShot {
  const CourtShot({
    required this.event,
    required this.playerId,
    required this.kind,
    required this.result,
    required this.originX,
    required this.originY,
    required this.targetX,
    required this.targetY,
  });

  final RallyEvent event;
  final String playerId;
  final ShotKind kind;
  final ShotResult result;
  final double originX, originY, targetX, targetY;
}

/// Toques dibujables de una selección de sets, más cuántos no se pudieron
/// dibujar por no tener zona de destino.
class ShotMapData {
  ShotMapData(this.shots, this._missing);

  final List<CourtShot> shots;
  final Map<(String, ShotKind), int> _missing;

  /// Toques de [kind] sin zona registrada (no dibujados), de un jugador o,
  /// con [playerId] null, de todo el equipo.
  int missingZone(ShotKind kind, {String? playerId}) => _missing.entries
      .where((e) => e.key.$2 == kind && (playerId == null || e.key.$1 == playerId))
      .fold(0, (a, e) => a + e.value);

  List<CourtShot> where(ShotKind kind, {String? playerId}) =>
      [for (final s in shots) if (s.kind == kind && (playerId == null || s.playerId == playerId)) s];
}

/// Calificaciones de saque/ataque/contra de una fila según el fundamento.
TouchStats touchStatsOf(PlayerStatLine l, ShotKind kind) {
  switch (kind) {
    case ShotKind.serve:
      return l.saque;
    case ShotKind.attack:
      return l.ataque;
    case ShotKind.counter:
      return l.contra;
  }
}

/// Resumen de un mapa: total, puntos, adentro (P + N), errores (NN + BLOQ) y
/// eficiencia (PP − NN − BLOQ) / total.
({int total, int points, int inPlay, int errors, double? efficiency}) shotSummary(TouchStats t) => (
      total: t.total,
      points: t.pp,
      inPlay: t.p + t.n,
      errors: t.nn + t.bloq,
      efficiency: t.total == 0 ? null : (t.pp - t.nn - t.bloq) / t.total,
    );

/// Categoría de un rally según su evento de cierre (ver
/// `documents/spec-estadistica-visual.md`, sección 3.3). Cada rally cerrado
/// cae en exactamente una.
enum RallyCategory {
  // Ganados
  servePoint,
  attackPoint,
  counterPoint,
  blockPoint,
  rivalError,
  // Perdidos
  serveError,
  receptionError,
  attackError,
  attackBlocked,
  genericError,
  rivalPoint,
  // Eventos de cierre que no encajan en ninguna columna (no debería pasar;
  // ver el assert de StatsEngine.classifyClosing). Solo cuentan en G-P.
  otherWon,
  otherLost,
}

extension RallyCategoryInfo on RallyCategory {
  bool get isWon =>
      this == RallyCategory.servePoint ||
      this == RallyCategory.attackPoint ||
      this == RallyCategory.counterPoint ||
      this == RallyCategory.blockPoint ||
      this == RallyCategory.rivalError ||
      this == RallyCategory.otherWon;
}

/// Una fila de la tabla de rendimiento por rotación (estilo DataVolley,
/// captura 2 de la propuesta). [label] es "P1".."P6" (posición del armador)
/// o "R1".."R6" (rotación contada desde la formación inicial, para sets sin
/// un armador identificable), o "Total".
class RotationRow {
  RotationRow(this.label);

  final String label;

  int won = 0;
  int lost = 0;

  /// Adv −Pts: puntos directos del rival.
  int rivalPts = 0;

  /// Adv +Err: errores del rival (incluye sanciones al rival con punto).
  int rivalErr = 0;

  int servePts = 0;
  int attackPts = 0; // ataque + contra
  int blockPts = 0;

  int serveErr = 0;
  int recErr = 0;
  int attackErr = 0; // ataque + contra, NN
  int attackBl = 0; // ataque + contra, BLOQ
  int genErr = 0; // errores genéricos + sanciones propias con punto

  /// Rallies con saque propio / rival, y cuántos de cada uno se ganaron.
  int servingRallies = 0;
  int breakWon = 0;
  int receivingRallies = 0;
  int sideOutWon = 0;

  /// +Pts: puntos ganados por acción propia.
  int get ownPts => servePts + attackPts + blockPts;

  /// −Err: puntos perdidos por error propio.
  int get ownErr => serveErr + recErr + attackErr + attackBl + genErr;

  /// G-P: rallies ganados menos perdidos.
  int get diff => won - lost;

  int get rallies => won + lost;

  double? get sideOutPct => receivingRallies == 0 ? null : sideOutWon / receivingRallies;

  double? get breakPct => servingRallies == 0 ? null : breakWon / servingRallies;

  void add(RallyCategory category, {required TeamSide serving, required TeamSide winner}) {
    if (winner == TeamSide.own) {
      won++;
    } else {
      lost++;
    }
    if (serving == TeamSide.own) {
      servingRallies++;
      if (winner == TeamSide.own) breakWon++;
    } else {
      receivingRallies++;
      if (winner == TeamSide.own) sideOutWon++;
    }
    switch (category) {
      case RallyCategory.servePoint:
        servePts++;
        break;
      case RallyCategory.attackPoint:
      case RallyCategory.counterPoint:
        attackPts++;
        break;
      case RallyCategory.blockPoint:
        blockPts++;
        break;
      case RallyCategory.rivalError:
        rivalErr++;
        break;
      case RallyCategory.serveError:
        serveErr++;
        break;
      case RallyCategory.receptionError:
        recErr++;
        break;
      case RallyCategory.attackError:
        attackErr++;
        break;
      case RallyCategory.attackBlocked:
        attackBl++;
        break;
      case RallyCategory.genericError:
        genErr++;
        break;
      case RallyCategory.rivalPoint:
        rivalPts++;
        break;
      case RallyCategory.otherWon:
      case RallyCategory.otherLost:
        break;
    }
  }
}

/// Encabezados de la tabla de rendimiento por rotación (los mismos en la
/// pantalla y en el PDF; sin caracteres fuera de Latin-1 por el PDF).
const rotationTableHeaders = [
  'Rot.',
  'G-P',
  'Adv\n-Pts',
  'Adv\n+Err',
  '+Pts',
  '-Err',
  'Err\ngen.',
  'Saque\nPts',
  'Saque\nErr',
  'Rec.\nErr',
  'Ataque\nPts',
  'Ataque\nBl',
  'Ataque\nErr',
  'Bloq\nTot',
];

/// Celdas de una fila de la tabla de rotaciones, en el orden de
/// [rotationTableHeaders]. Los ceros se muestran como "." (como DataVolley)
/// y los puntos perdidos con signo menos.
List<String> rotationTableCells(RotationRow r) {
  String z(int v, {bool negative = false}) => v == 0 ? '.' : (negative ? '-$v' : '$v');
  return [
    r.label,
    r.diff == 0 ? '.' : (r.diff > 0 ? '+${r.diff}' : '${r.diff}'),
    z(r.rivalPts, negative: true),
    z(r.rivalErr),
    z(r.ownPts),
    z(r.ownErr, negative: true),
    z(r.genErr),
    z(r.servePts),
    z(r.serveErr),
    z(r.recErr),
    z(r.attackPts),
    z(r.attackBl),
    z(r.attackErr),
    z(r.blockPts),
  ];
}

/// Rendimiento por rotación de una selección de sets (ver
/// `StatsEngine.computeRotations`).
class RotationStats {
  RotationStats({
    required this.setterRows,
    required this.fallbackRows,
    required this.fallbackSets,
    required this.total,
  });

  /// P1..P6: rallies de los sets con un armador identificable.
  final List<RotationRow> setterRows;

  /// R1..R6: rallies de los sets sin un único armador en la formación
  /// inicial ([fallbackSets]). Vacío en la práctica casi siempre.
  final List<RotationRow> fallbackRows;
  final List<int> fallbackSets;

  /// Todos los rallies de la selección (P y R juntos).
  final RotationRow total;

  bool get hasData => total.rallies > 0;
  bool get hasSetterData => setterRows.any((r) => r.rallies > 0);
  bool get hasFallbackData => fallbackRows.any((r) => r.rallies > 0);

  /// Filas a mostrar como tabla principal: P1..P6 si hay datos con armador;
  /// si todos los sets de la selección carecen de armador, R1..R6.
  List<RotationRow> get mainRows => hasSetterData || !hasFallbackData ? setterRows : fallbackRows;

  /// true si además de [mainRows] hay filas R1..R6 que mostrar aparte
  /// (selección que mezcla sets con y sin armador identificable).
  bool get hasSeparateFallback => hasSetterData && hasFallbackData;
}

/// Marcador después de un rally cerrado.
class TimelinePoint {
  const TimelinePoint(this.own, this.rival, this.winner);
  final int own;
  final int rival;
  final TeamSide winner;
  int get diff => own - rival;
}

/// Racha de [length] puntos seguidos de [team], empezando en el rally de
/// índice [start] (0-based, dentro de `SetTimeline.points`).
class ScoreRun {
  const ScoreRun(this.start, this.length, this.team);
  final int start;
  final int length;
  final TeamSide team;
  int get end => start + length; // exclusivo
}

/// Evolución del marcador de un set, rally por rally.
class SetTimeline {
  SetTimeline({required this.setNumber, required this.points, required this.substitutionMarks});

  final int setNumber;
  final List<TimelinePoint> points;

  /// Cantidad de rallies cerrados antes de cada cambio de jugador (sin
  /// contar los de líbero): el cambio se dibuja entre el punto
  /// `mark - 1` y el `mark`.
  final List<int> substitutionMarks;

  int get ownScore => points.isEmpty ? 0 : points.last.own;
  int get rivalScore => points.isEmpty ? 0 : points.last.rival;

  /// Rachas de al menos [minLength] puntos seguidos del mismo equipo.
  List<ScoreRun> runs({int minLength = 4}) {
    final out = <ScoreRun>[];
    var i = 0;
    while (i < points.length) {
      var j = i + 1;
      while (j < points.length && points[j].winner == points[i].winner) {
        j++;
      }
      if (j - i >= minLength) out.add(ScoreRun(i, j - i, points[i].winner));
      i = j;
    }
    return out;
  }
}

/// Ataque + contra de una fila de estadística, con la eficiencia estándar
/// (puntos − errores − bloqueados) / total.
class AttackSummary {
  const AttackSummary({required this.total, required this.points, required this.errors});

  factory AttackSummary.of(PlayerStatLine l) => AttackSummary(
        total: l.ataque.total + l.contra.total,
        points: l.ataque.pp + l.contra.pp,
        errors: l.ataque.nn + l.ataque.bloq + l.contra.nn + l.contra.bloq,
      );

  final int total;
  final int points;

  /// NN + BLOQ.
  final int errors;

  double? get efficiency => total == 0 ? null : (points - errors) / total;
}

/// Errores no forzados del tablero rápido: saque NN + ataque NN + contra NN
/// + errores genéricos (no incluye bloqueados ni recepción NN).
int unforcedErrorsOf(PlayerStatLine l) => l.saque.nn + l.ataque.nn + l.contra.nn + l.errGen;

/// Cuántos rallies cayeron en cada [RallyCategory] (gráfico "Origen de los
/// puntos").
class PointOriginStats {
  PointOriginStats(this.counts);

  final Map<RallyCategory, int> counts;

  int count(RallyCategory c) => counts[c] ?? 0;

  int get won => counts.entries.where((e) => e.key.isWon).fold(0, (a, e) => a + e.value);
  int get lost => counts.entries.where((e) => !e.key.isWon).fold(0, (a, e) => a + e.value);
}
