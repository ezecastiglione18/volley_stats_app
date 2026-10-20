import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../services/season_engine.dart';
import '../../state/app_data_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'widgets/stats_table.dart';

/// Panel de temporada: la estadística de un equipo sumando todos sus partidos
/// terminados, con filtros por equipo, torneo y rango de fechas. Hasta acá la
/// estadística existía solo partido por partido.
class SeasonStatsScreen extends StatefulWidget {
  const SeasonStatsScreen({super.key});

  @override
  State<SeasonStatsScreen> createState() => _SeasonStatsScreenState();
}

class _SeasonStatsScreenState extends State<SeasonStatsScreen> {
  static const _allTournaments = '__all__';
  static final _df = DateFormat('dd/MM/yyyy');

  late final List<VolleyMatch> _matches;
  late final List<SeasonTeamOption> _teams;

  String? _teamKey;
  String _tournament = _allTournaments;
  DateTimeRange? _range;
  SeasonReport? _report;

  @override
  void initState() {
    super.initState();
    _matches = context.read<AppDataController>().matches;
    _teams = SeasonEngine.teamOptions(_matches);
    _teamKey = _teams.isEmpty ? null : _teams.first.key;
    _recalculate();
  }

  /// El reporte se arma acá, al cambiar un filtro, y no dentro de `build`
  /// (que se vuelve a llamar por cualquier redibujado).
  void _recalculate() {
    final key = _teamKey;
    _report = key == null
        ? null
        : SeasonEngine.buildSeason(
            _matches,
            teamKey: key,
            tournament: _tournament == _allTournaments ? null : _tournament,
            range: _range,
          );
  }

  Future<void> _pickRange() async {
    final dates = [
      for (final m in _matches)
        if (m.status == MatchStatus.finished) m.date,
    ]..sort();
    final first = dates.isEmpty ? DateTime(2020) : dates.first;
    final now = DateTime.now();
    final last = dates.isEmpty || dates.last.isBefore(now) ? now : dates.last;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = picked;
      _recalculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi temporada'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: _teams.isEmpty
            ? const _EmptyState('Todavía no hay partidos terminados para armar la temporada.')
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _filters(),
                  const SizedBox(height: 16),
                  if (report == null || report.isEmpty)
                    const _EmptyState('No hay partidos terminados con estos filtros.')
                  else ...[
                    _indicators(report),
                    const SizedBox(height: 16),
                    StatsTable(
                      rows: report.rows,
                      total: report.total,
                      matchesPlayed: report.matchesPlayed,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _filters() {
    final tournaments =
        _teamKey == null ? <String>[] : SeasonEngine.tournaments(_matches, teamKey: _teamKey!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('team-$_teamKey'),
          initialValue: _teamKey,
          decoration: const InputDecoration(labelText: 'Equipo'),
          items: [
            for (final t in _teams) DropdownMenuItem(value: t.key, child: Text(t.label)),
          ],
          onChanged: (key) => setState(() {
            _teamKey = key;
            // Los torneos dependen del equipo: se vuelve a "Todos".
            _tournament = _allTournaments;
            _recalculate();
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('tournament-$_teamKey-$_tournament'),
          initialValue: _tournament,
          decoration: const InputDecoration(labelText: 'Torneo'),
          items: [
            const DropdownMenuItem(value: _allTournaments, child: Text('Todos')),
            for (final t in tournaments) DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (t) => setState(() {
            _tournament = t ?? _allTournaments;
            _recalculate();
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _range == null
                      ? 'Rango de fechas'
                      : '${_df.format(_range!.start)} — ${_df.format(_range!.end)}',
                ),
              ),
            ),
            if (_range != null)
              IconButton(
                tooltip: 'Quitar rango de fechas',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _range = null;
                  _recalculate();
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _indicators(SeasonReport r) {
    final reception = r.total.recepcion.efficiency;
    return Row(
      children: [
        Expanded(child: _Indicator(label: 'Partidos', value: '${r.matchesCount}')),
        const SizedBox(width: 8),
        Expanded(
          child: _Indicator(
            label: 'G - P',
            value: '${r.matchesWon} - ${r.matchesLost}',
            color: r.matchesWon >= r.matchesLost ? successColor(context) : errorColor(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _Indicator(label: 'Sets', value: '${r.setsFor} - ${r.setsAgainst}')),
        const SizedBox(width: 8),
        Expanded(
          child: _Indicator(
            label: 'Ef. recepción',
            value: reception == null ? '-' : '${(reception * 100).toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Indicator({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
