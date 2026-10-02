import 'package:flutter/material.dart';

import '../../../models/rally_event.dart';
import '../../../models/stat_line.dart';
import '../../../models/visual_stats.dart';
import '../../../models/volley_match.dart';
import '../../../services/stats_engine.dart';
import '../../../widgets/charts/chart_palette.dart';
import '../../../widgets/charts/court_shots_chart.dart';

/// Pestaña "Mapas" de Estadísticas (Etapa 2 de la spec): una flecha por
/// toque de saque, ataque o contra, desde donde salió (deducido) hasta la
/// zona donde cayó. Vista por defecto: el mapa con su resumen; la tabla por
/// zona queda a un toque ("Ver como tabla por zona").
class CourtMapsTab extends StatefulWidget {
  const CourtMapsTab({
    super.key,
    required this.match,
    required this.setNumber,
    required this.setSelector,
    required this.visibleKinds,
  });

  final VolleyMatch match;
  final int? setNumber;
  final Widget setSelector;

  /// Mapas elegidos en Configuración (ver `VisualStatsPreferences`).
  final Set<ShotKind> visibleKinds;

  @override
  State<CourtMapsTab> createState() => _CourtMapsTabState();
}

class _CourtMapsTabState extends State<CourtMapsTab> {
  ShotKind _kind = ShotKind.attack;
  String? _playerId; // null = todo el equipo
  String? _selectedEventId; // id del evento de la flecha tocada

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final kinds = [for (final k in ShotKind.values) if (widget.visibleKinds.contains(k)) k];
    if (kinds.isEmpty) {
      return _message(
        context,
        Icons.visibility_off_outlined,
        'Ocultaste todos los mapas. Podés volver a mostrarlos en Configuración → Estadística visual en pantalla.',
      );
    }
    if (!kinds.contains(_kind)) _kind = kinds.contains(ShotKind.attack) ? ShotKind.attack : kinds.first;

    final stats = StatsEngine.compute(widget.match, setNumber: widget.setNumber);
    final data = StatsEngine.computeShots(widget.match, setNumber: widget.setNumber);
    final zones = StatsEngine.computeZones(widget.match, setNumber: widget.setNumber);

    final players = [
      for (final l in stats.orderedRows)
        if (l.playerId != unassignedId && touchStatsOf(l, _kind).total > 0) l,
    ];
    if (_playerId != null && !players.any((l) => l.playerId == _playerId)) _playerId = null;
    final line = _playerId == null ? stats.team : players.firstWhere((l) => l.playerId == _playerId);
    final shots = data.where(_kind, playerId: _playerId);
    final selected = shots.where((s) => s.event.id == _selectedEventId).firstOrNull;
    final summary = shotSummary(touchStatsOf(line, _kind));
    final missing = data.missingZone(_kind, playerId: _playerId);
    final palette = ChartPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        widget.setSelector,
        const SizedBox(height: 8),
        if (kinds.length > 1)
          SegmentedButton<ShotKind>(
            segments: [for (final k in kinds) ButtonSegment(value: k, label: Text(k.shortLabel))],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _selectedEventId = null;
            }),
          ),
        const SizedBox(height: 10),
        if (players.isEmpty)
          _inlineNote(context, 'No hay toques de ${_kind.label.toLowerCase()} cargados.')
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('Todos', _playerId == null, () => _pick(null)),
              for (final l in players) _chip('#${l.number} ${_shortName(l.displayName)}', _playerId == l.playerId, () => _pick(l.playerId)),
            ]),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (shots.isEmpty)
                    _inlineNote(
                      context,
                      'Estos toques no tienen zona de destino registrada, así que no se pueden dibujar. La zona '
                      'se activa al armar la formación de cada set (opción premium).',
                    )
                  else
                    CourtShotsChart(
                      shots: shots,
                      selected: selected,
                      onShotTap: (s) => setState(() => _selectedEventId = s?.event.id),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    _SelectedShotCard(shot: selected, stats: stats, onClose: () => setState(() => _selectedEventId = null)),
                  ],
                  const SizedBox(height: 10),
                  ShotLegend(results: [
                    ShotResult.point,
                    ShotResult.inPlay,
                    ShotResult.error,
                    if (_kind != ShotKind.serve) ShotResult.blocked,
                    for (final r in [ShotResult.out, ShotResult.net])
                      if (shots.any((s) => s.result == r)) r,
                  ]),
                  const SizedBox(height: 12),
                  Row(

                    children: [
                      _stat('${summary.total}', 'Total', palette.text),
                      _stat('${summary.points}', 'Puntos', palette.positive),
                      _stat('${summary.inPlay}', 'Adentro', palette.slate),
                      _stat('${summary.errors}', 'Errores', palette.negative),
                      _stat(summary.efficiency == null ? '—' : signedPct(summary.efficiency!), 'Eficiencia',
                          (summary.efficiency ?? 0) >= 0 ? palette.positive : palette.negative),
                    ],
                  ),
                  if (missing > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      missing == 1
                          ? '1 toque sin zona de destino (no se dibuja, pero cuenta en el resumen).'
                          : '$missing toques sin zona de destino (no se dibujan, pero cuentan en el resumen).',
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ],
                  if (shots.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'El origen de cada flecha se deduce del puesto del jugador y de su lugar en la rotación; '
                      'el destino es la zona registrada. Tocá una flecha para ver el detalle.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('Ver como tabla por zona', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                _ZoneTable(
                  byZone: _zoneMap(zones, _kind, _playerId),
                  zoneList: zones.displayZones,
                  includeBloq: _kind != ShotKind.serve,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _pick(String? playerId) => setState(() {
        _playerId = playerId;
        _selectedEventId = null;
      });

  static Map<int, TouchStats>? _zoneMap(ZoneStats z, ShotKind kind, String? playerId) {
    switch (kind) {
      case ShotKind.serve:
        return playerId == null ? z.serveByZone : z.serveByZoneByPlayer[playerId];
      case ShotKind.attack:
        return playerId == null ? z.attackByZone : z.attackByZoneByPlayer[playerId];
      case ShotKind.counter:
        return playerId == null ? z.counterByZone : z.counterByZoneByPlayer[playerId];
    }
  }

  /// "Gómez, Ana" → "Gómez".
  static String _shortName(String displayName) => displayName.split(',').first.trim();

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  /// Un número del resumen: ocupa una parte igual de la fila y se achica si
  /// no entra (celulares angostos).
  Widget _stat(String value, String label, Color color) => Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );

  Widget _inlineNote(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _message(BuildContext context, IconData icon, String text) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          widget.setSelector,
          const SizedBox(height: 40),
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
        ],
      );
}

/// Detalle de la flecha tocada: set, marcador, jugador y calificación.
class _SelectedShotCard extends StatelessWidget {
  const _SelectedShotCard({required this.shot, required this.stats, required this.onClose});

  final CourtShot shot;
  final MatchStats stats;
  final VoidCallback onClose;

  static const _gradeLabels = {
    Grade.pp: 'PP · Punto',
    Grade.p: 'P · Positiva',
    Grade.n: 'N · Negativa',
    Grade.nn: 'NN · Error',
    Grade.bloq: 'BLOQ · Bloqueado',
  };

  @override
  Widget build(BuildContext context) {
    final ev = shot.event;
    final player = stats.byPlayer[shot.playerId];
    final color = shotColor(shot.result, ChartPalette.of(context));
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            '${player == null ? '' : '#${player.number} ${player.displayName} · '}${shot.kind.label} '
            '${_gradeLabels[ev.grade] ?? ev.grade ?? ''}\n'
            'Set ${ev.setNumber} · rally ${ev.rallyNumber} · marcador ${ev.ownScoreAfter}-${ev.rivalScoreAfter}'
            '${ev.targetZone == null ? '' : ' · zona ${ev.targetZone}'}',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose, tooltip: 'Cerrar'),
      ]),
    );
  }
}

/// Tabla por zona del mapa elegido (equipo o jugador).
class _ZoneTable extends StatelessWidget {
  const _ZoneTable({required this.byZone, required this.zoneList, required this.includeBloq});

  final Map<int, TouchStats>? byZone;
  final List<int> zoneList;
  final bool includeBloq;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = byZone;
    if (data == null || data.values.every((s) => s.total == 0)) {
      return Text('Sin toques con zona registrada.', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    final headers = ['Zona', 'Total', 'PP', 'P', 'N', if (includeBloq) 'BLOQ', 'NN'];
    List<String> cells(String label, TouchStats s) =>
        [label, '${s.total}', '${s.pp}', '${s.p}', '${s.n}', if (includeBloq) '${s.bloq}', '${s.nn}'];
    final total = TouchStats();
    for (final s in data.values) {
      total
        ..pp += s.pp
        ..p += s.p
        ..n += s.n
        ..nn += s.nn
        ..bloq += s.bloq;
    }
    TableRow row(List<String> values, {bool bold = false, Color? bg}) => TableRow(
          decoration: bg == null ? null : BoxDecoration(color: bg),
          children: [
            for (final v in values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(v,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.bold : null)),
              ),
          ],
        );
    return Table(
      border: TableBorder(horizontalInside: BorderSide(color: scheme.outline, width: 0.6)),
      children: [
        row(headers, bold: true, bg: scheme.surfaceContainerHighest),
        for (final z in zoneList) row(cells('$z', data[z] ?? TouchStats())),
        row(cells('Total', total), bold: true, bg: scheme.secondary.withValues(alpha: 0.16)),
      ],
    );
  }
}
