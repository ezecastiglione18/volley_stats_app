import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../services/paywall_launcher.dart';
import '../../state/app_data_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/theme.dart';

/// Papelera del archivo: los partidos eliminados quedan acá 30 días
/// (`AppDataController.trashedMatches`), con los días que le quedan a cada
/// uno, "Restaurar" (sin premium respeta el tope de 3) y "Eliminar
/// definitivamente". Con la nube activada es la misma en todos los
/// dispositivos de la cuenta.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  Future<void> _restore(BuildContext context, VolleyMatch match) async {
    final appData = context.read<AppDataController>();
    final isPremium = context.read<SubscriptionController>().isPremium;
    try {
      await appData.restoreMatch(match.id, isPremium: isPremium);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Partido restaurado: ${match.ownTeamName} vs ${match.rivalTeamName}')));
      }
    } on MatchArchiveLimitException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El archivo ya tiene 3 partidos (el máximo de la versión free). Eliminá uno o '
              'suscribite a premium para restaurar este; mientras tanto sigue en la papelera.')));
      await showRallyStatsPaywall(context);
    }
  }

  Future<void> _deleteForever(BuildContext context, VolleyMatch match) async {
    final appData = context.read<AppDataController>();
    final cloud = appData.sync?.enabled ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar definitivamente'),
        content: Text(
          'Se borra "${match.ownTeamName} vs ${match.rivalTeamName}" de este dispositivo'
          '${cloud ? ' y de la nube' : ''} y no se puede deshacer. ¿Confirmás?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorColor(ctx), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await appData.deleteMatch(match.id);
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataController>();
    final trashed = appData.trashedMatches;
    final df = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Papelera')),
      body: SafeArea(
        top: false,
        child: trashed.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'La papelera está vacía.\nLos partidos que elimines quedan acá 30 días.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: trashed.length,
                itemBuilder: (context, i) {
                  final m = trashed[i];
                  final days = appData.trashDaysLeft(m);
                  final left = days <= 0
                      ? 'Se borra al volver a abrir la app'
                      : 'Se borra en $days ${days == 1 ? 'día' : 'días'}';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.ownTeamName} vs ${m.rivalTeamName}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${df.format(m.date)}'
                            '${m.tournament.isNotEmpty ? ' · ${m.tournament}' : ''}'
                            ' · Sets: ${m.ownSetsWon} - ${m.rivalSetsWon}'
                            '${m.status == MatchStatus.finished ? '' : ' (en curso)'}',
                          ),
                          Text(left, style: TextStyle(color: warningColor(context), fontSize: 13)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _deleteForever(context, m),
                                child: Text('Eliminar definitivamente',
                                    style: TextStyle(color: errorColor(context))),
                              ),
                              TextButton.icon(
                                onPressed: () => _restore(context, m),
                                icon: const Icon(Icons.restore),
                                label: const Text('Restaurar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
