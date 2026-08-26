import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../services/match_export_service.dart';
import '../../services/paywall_launcher.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/id_gen.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../live/live_match_screen.dart';
import 'match_summary_screen.dart';

class MatchArchiveScreen extends StatefulWidget {
  const MatchArchiveScreen({super.key});

  @override
  State<MatchArchiveScreen> createState() => _MatchArchiveScreenState();
}

class _MatchArchiveScreenState extends State<MatchArchiveScreen> {
  bool _busy = false;

  Future<void> _exportMatch(VolleyMatch match) async {
    setState(() => _busy = true);
    try {
      await MatchExportService.exportMatch(match);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importMatch() async {
    final appData = context.read<AppDataController>();
    setState(() => _busy = true);
    try {
      final json = await MatchExportService.pickMatchJson();
      if (json == null) return; // cancelado
      // Si el id ya existe localmente, se importa como copia con id nuevo
      // para no pisar el partido que ya estaba guardado en este dispositivo.
      if (appData.matches.any((m) => m.id == json['id'])) {
        json['id'] = generateId('match_');
      }
      final match = VolleyMatch.fromJson(json);
      final isPremium = context.read<SubscriptionController>().isPremium;
      await appData.saveMatch(match, isPremium: isPremium);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Partido importado: ${match.ownTeamName} vs ${match.rivalTeamName}')));
      }
    } on MatchArchiveLimitException {
      if (mounted) await showRallyStatsPaywall(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<AppDataController>().matches;
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo de Partidos'),
        actions: [
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_upload_outlined),
            tooltip: 'Importar partido',
            onPressed: _busy ? null : _importMatch,
          ),
          const ThemeToggleSwitch(),
        ],
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
                        } else if (v == 'export') {
                          await _exportMatch(m);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'export', child: Text('Exportar')),
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
