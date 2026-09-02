import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../services/scouting_engine.dart';
import '../../state/app_data_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'match_summary_screen.dart';

/// Lista de rivales ya enfrentados (con al menos un partido cargado), como
/// puerta de entrada al scouting agregado de cada uno (ver
/// [RivalScoutingDetailScreen]). Se arma solo con los partidos que ya están
/// en el archivo (sección "Archivo de Partidos"), sin depender de nada
/// externo.
class RivalScoutingScreen extends StatelessWidget {
  const RivalScoutingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<AppDataController>().matches;
    final rivals = ScoutingEngine.rivalNames(matches);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scouting de rivales'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: rivals.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay partidos cargados con un rival para poder armar scouting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rivals.length,
                itemBuilder: (context, i) {
                  final name = rivals[i];
                  final report = ScoutingEngine.buildReport(name, matches);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.assessment_outlined)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${report.matchesPlayed} partido${report.matchesPlayed == 1 ? '' : 's'} · '
                        '${report.matchesWon}V - ${report.matchesLost}D',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RivalScoutingDetailScreen(rivalName: name)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Detalle agregado contra un rival puntual: récord de partidos, de qué
/// falla más (para presionar) y con qué nos gana más puntos (para reforzar
/// la defensa), más el historial de partidos jugados contra él.
class RivalScoutingDetailScreen extends StatelessWidget {
  final String rivalName;
  const RivalScoutingDetailScreen({super.key, required this.rivalName});

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<AppDataController>().matches;
    final report = ScoutingEngine.buildReport(rivalName, matches);
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(rivalName)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Partidos',
                    value: '${report.matchesPlayed}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Ganados',
                    value: '${report.matchesWon}',
                    color: successColor(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Perdidos',
                    value: '${report.matchesLost}',
                    color: errorColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Para la próxima vez', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _InsightRow(
                      icon: Icons.gpp_good_outlined,
                      color: successColor(context),
                      label: 'Le solemos ganar el punto por su error de',
                      value: report.rivalWeakestSpot,
                    ),
                    const SizedBox(height: 8),
                    _InsightRow(
                      icon: Icons.warning_amber_outlined,
                      color: warningColor(context),
                      label: 'Nos suele ganar el punto con su',
                      value: report.rivalStrongestWeapon,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Errores del rival (nos dan el punto)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _BreakdownBar(label: 'Saque', value: report.errors.serve, total: report.errors.total),
                    _BreakdownBar(label: 'Ataque', value: report.errors.attack, total: report.errors.total),
                    _BreakdownBar(
                        label: 'Contraataque', value: report.errors.counter, total: report.errors.total),
                    _BreakdownBar(
                        label: 'Genérico', value: report.errors.generic, total: report.errors.total),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Puntos que gana el rival con su toque',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _BreakdownBar(label: 'Ataque', value: report.points.attack, total: report.points.total),
                    _BreakdownBar(
                        label: 'Contraataque', value: report.points.counter, total: report.points.total),
                    if (report.points.unclassified > 0)
                      _BreakdownBar(
                          label: 'Sin clasificar (partidos viejos)',
                          value: report.points.unclassified,
                          total: report.points.total),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Historial de partidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final m in report.matches) _MatchRow(match: m, df: df),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InsightRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(text: '$label: '),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  const _BreakdownBar({required this.label, required this.value, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: surfaceAltColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final VolleyMatch match;
  final DateFormat df;
  const _MatchRow({required this.match, required this.df});

  @override
  Widget build(BuildContext context) {
    final finished = match.status == MatchStatus.finished;
    final won = finished && match.ownSetsWon > match.rivalSetsWon;
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          finished ? (won ? Icons.emoji_events_outlined : Icons.close) : Icons.hourglass_top,
          color: finished ? (won ? successColor(context) : errorColor(context)) : warningColor(context),
        ),
        title: Text('${df.format(match.date)}  ·  ${match.ownSetsWon} - ${match.rivalSetsWon}'),
        subtitle: match.tournament.isNotEmpty ? Text(match.tournament) : null,
        onTap: finished
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: match)),
                )
            : null,
      ),
    );
  }
}
