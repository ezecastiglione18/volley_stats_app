import 'package:flutter/material.dart';

import '../../../models/stat_line.dart';
import '../../../models/visual_stats.dart';
import '../../../models/volley_match.dart';
import '../../../services/stats_engine.dart';
import '../../../widgets/charts/chart_palette.dart';
import '../../../widgets/charts/diverging_bar_chart.dart';
import '../../../widgets/charts/efficiency_bars_chart.dart';
import '../../../widgets/charts/grouped_pct_bar_chart.dart';
import '../../../widgets/charts/score_timeline_chart.dart';
import '../../../widgets/charts/stacked_bar.dart';
import '../../../widgets/charts/zone_heatmap.dart';

/// Pestaña "Gráficos" de Estadísticas: gráficos de equipo calculados del log
/// de eventos (ver documents/spec-estadistica-visual.md, Etapa 1). Cada
/// tarjeta se puede abrir a pantalla completa tocándola.
class VisualStatsTab extends StatelessWidget {
  const VisualStatsTab({
    super.key,
    required this.match,
    required this.setNumber,
    required this.setSelector,
    this.visibleCharts = const {...VisualChart.values},
  });

  final VolleyMatch match;
  final int? setNumber;

  /// Selector de set compartido con la pestaña "Tabla".
  final Widget setSelector;

  /// Gráficos elegidos en Configuración (ver `VisualStatsPreferences`).
  final Set<VisualChart> visibleCharts;

  @override
  Widget build(BuildContext context) {
    if (visibleCharts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          setSelector,
          const SizedBox(height: 40),
          Icon(Icons.visibility_off_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          const Text(
            'Ocultaste todos los gráficos. Podés volver a mostrarlos en Configuración → Estadística visual en '
            'pantalla.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    final rotations = StatsEngine.computeRotations(match, setNumber: setNumber);
    if (!rotations.hasData) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          setSelector,
          const SizedBox(height: 40),
          Icon(Icons.insights_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          const Text('Todavía no hay puntos cargados', textAlign: TextAlign.center),
        ],
      );
    }

    final stats = StatsEngine.compute(match, setNumber: setNumber);
    final timelines = StatsEngine.computeTimelines(match, setNumber: setNumber);
    final origin = StatsEngine.computePointOrigin(match, setNumber: setNumber);
    final zones = StatsEngine.computeZones(match, setNumber: setNumber);
    final palette = ChartPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        setSelector,
        const SizedBox(height: 8),
        _ChartCard(
          chart: VisualChart.dashboard,
          visible: visibleCharts.contains(VisualChart.dashboard),
          builder: (_) => DashboardTiles(rotations: rotations, stats: stats),
        ),
        _ChartCard(
          chart: VisualChart.rotations,
          visible: visibleCharts.contains(VisualChart.rotations),
          help: 'P1 = armador en zona 1. Cuántos puntos se ganaron menos cuántos se perdieron mientras el '
              'equipo estuvo en cada rotación.',
          builder: (expanded) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DivergingBarChart(
                labels: [for (final r in rotations.mainRows) r.label],
                values: [for (final r in rotations.mainRows) r.diff],
                height: expanded ? 280 : 190,
              ),
              const SizedBox(height: 10),
              RotationTable(rows: rotations.mainRows, total: rotations.total),
              if (rotations.hasSeparateFallback) ...[
                const SizedBox(height: 12),
                Text(
                  _fallbackNote(rotations.fallbackSets),
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
                const SizedBox(height: 6),
                RotationTable(rows: rotations.fallbackRows),
              ] else if (!rotations.hasSetterData) ...[
                const SizedBox(height: 6),
                Text(
                  'Sin un único armador en la formación inicial: las rotaciones se cuentan desde la '
                  'formación inicial (R1 = como arrancó el set).',
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Referencias — $rotationTableLegend',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _ChartCard(
          chart: VisualChart.sideOutBreak,
          visible: visibleCharts.contains(VisualChart.sideOutBreak),
          help: 'Side-out: % de rallies ganados cuando saca el rival. Break-point: % de rallies ganados '
              'con saque propio. Separa si una rotación falla recibiendo o sacando.',
          builder: (expanded) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GroupedPctBarChart(
                labels: [for (final r in rotations.mainRows) r.label],
                a: [for (final r in rotations.mainRows) r.sideOutPct],
                b: [for (final r in rotations.mainRows) r.breakPct],
                colorA: palette.sideOut,
                colorB: palette.breakPoint,
                height: expanded ? 260 : 180,
              ),
              const SizedBox(height: 6),
              ChartLegend(items: [('Side-out', palette.sideOut), ('Break-point', palette.breakPoint)]),
            ],
          ),
        ),
        _ChartCard(
          chart: VisualChart.timeline,
          visible: visibleCharts.contains(VisualChart.timeline),
          help: 'Cada columna es un rally: arriba de la línea el equipo va ganando, abajo perdiendo. Se marcan '
              'las rachas de 4 o más puntos y, con un triangulito, los cambios de jugador.',
          builder: (expanded) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in timelines) ...[
                Text('Set ${t.setNumber} · ${t.ownScore}-${t.rivalScore}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ScoreTimelineChart(timeline: t, height: expanded ? 230 : 160),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        _ChartCard(
          chart: VisualChart.pointOrigin,
          visible: visibleCharts.contains(VisualChart.pointOrigin),
          help: 'Si en "Perdidos" pesan más los errores propios que el punto rival, el equipo pierde más por '
              'errores propios que por mérito del rival.',
          builder: (_) => PointOriginBars(origin: origin),
        ),
        _ChartCard(
          chart: VisualChart.attackEfficiency,
          visible: visibleCharts.contains(VisualChart.attackEfficiency),
          help: 'Ataque + contra. Eficiencia = (puntos − errores − bloqueados) / total.',
          builder: (_) => AttackEfficiencyChart(stats: stats),
        ),
        _ChartCard(
          chart: VisualChart.reception,
          visible: visibleCharts.contains(VisualChart.reception),
          help: 'Cada barra suma el 100 % de las recepciones del jugador. A la derecha, la efectividad '
              '(PP + P) / total y la cantidad.',
          builder: (_) => ReceptionBars(stats: stats),
        ),
        _ChartCard(
          chart: VisualChart.heatmap,
          visible: visibleCharts.contains(VisualChart.heatmap),
          help: 'Zonas de la cancha rival a las que fue cada toque (solo los que tienen zona registrada). '
              'Más oscuro = más pelotas; debajo, el % que terminó en punto.',
          builder: (expanded) => ZoneHeatmapSection(zones: zones, maxWidth: expanded ? 420 : 300),
        ),
      ],
    );
  }

  static String _fallbackNote(List<int> sets) {
    final which = sets.length == 1 ? 'El set ${sets.first} se agrupó' : 'Los sets ${sets.join(', ')} se agruparon';
    return '$which aparte por no tener un único armador en la formación inicial (R1 = como arrancó el set):';
  }
}

/// Tarjeta de un gráfico: título, ayuda y contenido. Tocarla abre el mismo
/// gráfico a pantalla completa ([builder] recibe `expanded: true`).
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.chart, required this.builder, this.help, this.visible = true});

  final VisualChart chart;
  final String? help;
  final Widget Function(bool expanded) builder;

  /// false si el usuario lo ocultó en Configuración.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(chart.label)),
            body: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (help != null) ...[
                    Text(help!, style: TextStyle(fontSize: 13, color: muted)),
                    const SizedBox(height: 14),
                  ],
                  builder(true),
                ],
              ),
            ),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(chart.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Icon(Icons.open_in_full, size: 16, color: muted),
              ]),
              if (help != null) ...[
                const SizedBox(height: 3),
                Text(help!, style: TextStyle(fontSize: 11.5, color: muted)),
              ],
              const SizedBox(height: 10),
              builder(false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de cuatro indicadores: side-out, break-point, eficiencia de ataque
/// del equipo y errores no forzados.
class DashboardTiles extends StatelessWidget {
  const DashboardTiles({super.key, required this.rotations, required this.stats});

  final RotationStats rotations;
  final MatchStats stats;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final t = rotations.total;
    final attack = AttackSummary.of(stats.team);
    final unforced = unforcedErrorsOf(stats.team);
    String pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';
    final tiles = [
      _Kpi('Side-out', pct(t.sideOutPct), 'rallies ganados recibiendo (${t.sideOutWon}/${t.receivingRallies})',
          palette.sideOut),
      _Kpi('Break-point', pct(t.breakPct), 'rallies ganados sacando (${t.breakWon}/${t.servingRallies})',
          palette.breakPoint),
      _Kpi('Eficiencia de ataque', attack.total == 0 ? '—' : signedPct(attack.efficiency!), '(pts − err) / total',
          attack.total == 0 || attack.efficiency! >= 0 ? palette.positive : palette.negative),
      _Kpi('Errores no forzados', '$unforced', 'saque + ataque + genérico', palette.negative),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 4 : 2;
      final w = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final k in tiles) SizedBox(width: w, child: k)],
      );
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.sub, this.color);

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(sub, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Tabla de rendimiento por rotación con las columnas de la captura 2
/// (estilo DataVolley). Los ceros se muestran como ".".
class RotationTable extends StatelessWidget {
  const RotationTable({super.key, required this.rows, this.total});

  final List<RotationRow> rows;
  final RotationRow? total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ChartPalette.of(context);
    TableRow row(RotationRow r, {bool isTotal = false}) {
      final values = rotationTableCells(r);
      return TableRow(
        decoration: isTotal ? BoxDecoration(color: scheme.secondary.withValues(alpha: 0.16)) : null,
        children: [
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
              child: Text(
                values[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i <= 1 || i == 4 || i == 5 || isTotal ? FontWeight.bold : null,
                  color: i == 1 && r.diff != 0 ? (r.diff > 0 ? palette.positive : palette.negative) : null,
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(50),
        columnWidths: const {0: FixedColumnWidth(44), 1: FixedColumnWidth(44)},
        border: TableBorder(horizontalInside: BorderSide(color: scheme.outline, width: 0.6)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor),
            children: [
              for (final h in rotationTableHeaders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                  child: Text(h,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
          for (final r in rows) row(r),
          if (total != null) row(total!, isTotal: true),
        ],
      ),
    );
  }
}

/// Dos barras apiladas: de qué salieron los puntos ganados y cómo se
/// perdieron los perdidos.
class PointOriginBars extends StatelessWidget {
  const PointOriginBars({super.key, required this.origin});

  final PointOriginStats origin;

  static const wonCategories = [
    (RallyCategory.attackPoint, 'Ataque'),
    (RallyCategory.counterPoint, 'Contra'),
    (RallyCategory.blockPoint, 'Bloqueo'),
    (RallyCategory.servePoint, 'Saque'),
    (RallyCategory.rivalError, 'Error rival'),
    (RallyCategory.otherWon, 'Otros'),
  ];

  static const lostCategories = [
    (RallyCategory.attackError, 'Err. ataque'),
    (RallyCategory.attackBlocked, 'Bloqueado'),
    (RallyCategory.serveError, 'Err. saque'),
    (RallyCategory.receptionError, 'Err. recepción'),
    (RallyCategory.genericError, 'Err. genérico'),
    (RallyCategory.rivalPoint, 'Punto rival'),
    (RallyCategory.otherLost, 'Otros'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    Widget bar(String title, int total, List<(RallyCategory, String)> cats) => Row(children: [
          SizedBox(width: 92, child: Text('$title ($total)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
          Expanded(
            child: StackedBar(segments: [
              for (final (c, label) in cats) ChartSegment(label, origin.count(c), _colorFor(palette, c)),
            ]),
          ),
        ]);
    final legend = [
      for (final (c, label) in [...wonCategories, ...lostCategories])
        if (origin.count(c) > 0) (label, _colorFor(palette, c)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar('Ganados', origin.won, wonCategories),
        const SizedBox(height: 6),
        bar('Perdidos', origin.lost, lostCategories),
        const SizedBox(height: 8),
        ChartLegend(items: legend),
      ],
    );
  }

  // El bloqueado se separa del error de ataque (los dos van en rojo en el
  // resto de la app) con un rojo más oscuro, para poder distinguirlos.
  static Color _colorFor(ChartPalette p, RallyCategory c) =>
      c == RallyCategory.attackBlocked ? const Color(0xFFB71C1C) : p.categoryColor(c);
}

/// Eficiencia de ataque (ataque + contra) por jugador, de mayor a menor.
class AttackEfficiencyChart extends StatelessWidget {
  const AttackEfficiencyChart({super.key, required this.stats});

  final MatchStats stats;

  static List<EfficiencyRow> rowsFor(MatchStats stats) => [
        for (final (line, a) in StatsEngine.attackRanking(stats))
          EfficiencyRow(
            label: '#${line.number} ${line.displayName}',
            efficiency: a.efficiency!,
            detail: '${a.points} pts · ${a.errors} err · ${a.total} tot',
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(stats);
    if (rows.isEmpty) return const _EmptyNote('No hay ataques cargados.');
    return EfficiencyBarsChart(rows: rows);
  }
}

/// Una barra al 100 % por receptor, con los colores de las calificaciones.
class ReceptionBars extends StatelessWidget {
  const ReceptionBars({super.key, required this.stats});

  final MatchStats stats;

  static const gradeColors = [kChartPositive, kChartPositiveLight, kChartExcl, kChartWarning, kChartSold, kChartNegative];
  static const gradeLabels = ['PP', 'P', '!', 'N', 'V-', 'NN'];

  static List<int> counts(ReceptionStats r) => [r.pp, r.p, r.excl, r.n, r.vNeg, r.nn];

  @override
  Widget build(BuildContext context) {
    final players = stats.orderedRows.where((l) => l.recepcion.total > 0).toList();
    if (players.isEmpty) return const _EmptyNote('No hay recepciones cargadas.');
    final palette = ChartPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in players)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(
                width: 92,
                child: Text(l.playerId == unassignedId ? l.displayName : '#${l.number} ${l.displayName}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Expanded(
                child: StackedBar(
                  showPercent: true,
                  segments: [
                    for (var i = 0; i < 6; i++) ChartSegment(gradeLabels[i], counts(l.recepcion)[i], gradeColors[i]),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 64,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${(l.recepcion.efficiency! * 100).round()}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: palette.positive)),
                    TextSpan(text: ' (${l.recepcion.total})', style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ]),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        ChartLegend(items: [for (var i = 0; i < 6; i++) (gradeLabels[i], gradeColors[i])]),
      ],
    );
  }
}

/// Mapa de calor con selector Saque / Ataque / Contra.
class ZoneHeatmapSection extends StatefulWidget {
  const ZoneHeatmapSection({super.key, required this.zones, this.maxWidth = 300});

  final ZoneStats zones;
  final double maxWidth;

  @override
  State<ZoneHeatmapSection> createState() => _ZoneHeatmapSectionState();
}

class _ZoneHeatmapSectionState extends State<ZoneHeatmapSection> {
  int _kind = 1; // 0 saque, 1 ataque, 2 contra

  @override
  Widget build(BuildContext context) {
    final zones = widget.zones;
    if (!zones.hasAnyData) return const _EmptyNote('No hay zonas de destino registradas.');
    final byZone = [zones.serveByZone, zones.attackByZone, zones.counterByZone][_kind];
    return Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Saque')),
            ButtonSegment(value: 1, label: Text('Ataque')),
            ButtonSegment(value: 2, label: Text('Contra')),
          ],
          selected: {_kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 10),
        ZoneHeatmap(byZone: byZone, nineZones: zones.hasMiddleZoneData, maxWidth: widget.maxWidth),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
