import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../live/live_match_screen.dart';
import 'match_summary_screen.dart';

class MatchArchiveScreen extends StatelessWidget {
  const MatchArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<AppDataController>().matches;
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo de Partidos'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: matches.isEmpty
          ? const Center(
              child: Text('Todavía no hay partidos guardados', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final m = matches[i];
                final finished = m.status == MatchStatus.finished;
                final statusColor = finished ? successColor(context) : warningColor(context);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.16),
                      child: Icon(
                        finished ? Icons.check : Icons.play_arrow,
                        color: statusColor,
                      ),
                    ),
                    title: Text('${m.ownTeamName} vs ${m.rivalTeamName}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${df.format(m.date)}'
                      '${m.tournament.isNotEmpty ? ' · ${m.tournament}' : ''}'
                      '\nSets: ${m.ownSetsWon} - ${m.rivalSetsWon}'
                      '${finished ? '' : ' (en curso)'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') {
                          await context.read<AppDataController>().deleteMatch(m.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                    onTap: () {
                      if (finished) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: m)),
                        );
                      } else {
                        final controller = MatchController.resume(m);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LiveMatchScreen(controller: controller)),
                        );
                      }
                    },
                  ),
                );
              },
            ),
      ),
    );
  }
}
