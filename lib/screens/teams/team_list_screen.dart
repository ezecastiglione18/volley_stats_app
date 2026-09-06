import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/team.dart';
import '../../models/volley_match.dart';
import '../../services/paywall_launcher.dart';
import '../../services/team_export_service.dart';
import '../../state/app_data_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/id_gen.dart';
import '../../utils/sample_team.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'team_form_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  bool _busy = false;

  Future<void> _loadSampleTeam() async {
    final appData = context.read<AppDataController>();
    if (appData.teams.any((t) => t.name == 'Club Atlético Central')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El equipo de ejemplo "Club Atlético Central" ya existe')),
      );
      return;
    }
    await appData.saveTeam(buildSampleTeam());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipo de ejemplo "Club Atlético Central" agregado')),
      );
    }
  }

  Future<void> _importTeam() async {
    final appData = context.read<AppDataController>();
    setState(() => _busy = true);
    try {
      final bundle = await TeamExportService.pickTeamJson();
      if (bundle == null) return; // cancelado

      final teamJson = Map<String, dynamic>.from(bundle['team'] as Map);
      // Si el id ya existe localmente, se importa como copia con id nuevo
      // para no pisar el equipo que ya estaba guardado en este dispositivo
      // (mismo criterio que ya usa la importación de partidos).
      if (appData.teams.any((t) => t.id == teamJson['id'])) {
        teamJson['id'] = generateId('team_');
      }
      final team = Team.fromJson(teamJson);
      await appData.saveTeam(team);

      final matchesJson = (bundle['matches'] as List?) ?? [];
      final isPremium = context.read<SubscriptionController>().isPremium;
      var imported = 0;
      var hitLimit = false;
      for (final raw in matchesJson) {
        final matchJson = Map<String, dynamic>.from(raw as Map);
        // Reapuntar al id del equipo ya resuelto arriba (puede haber
        // cambiado si chocaba con uno local) para no perder el vínculo que
        // hace que estos partidos cuenten en la estadística acumulada del
        // equipo importado.
        matchJson['ownTeamSourceId'] = team.id;
        if (appData.matches.any((m) => m.id == matchJson['id'])) {
          matchJson['id'] = generateId('match_');
        }
        final match = VolleyMatch.fromJson(matchJson);
        try {
          await appData.saveMatch(match, isPremium: isPremium);
          imported++;
        } on MatchArchiveLimitException {
          hitLimit = true;
          break;
        }
      }

      if (!mounted) return;
      final msg = StringBuffer('Equipo "${team.name}" importado');
      if (matchesJson.isNotEmpty) {
        msg.write(
            ' con $imported de ${matchesJson.length} partido${matchesJson.length == 1 ? '' : 's'}');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      if (hitLimit) {
        await showRallyStatsPaywall(context);
      }
    } on TeamImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo importar: ${e.message}')));
      }
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
    final appData = context.watch<AppDataController>();
    final teams = appData.teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos'),
        actions: [
          const ThemeToggleSwitch(),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Cargar equipo de ejemplo',
            onPressed: _busy ? null : _loadSampleTeam,
          ),
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_upload_outlined),
            tooltip: 'Importar equipo',
            onPressed: _busy ? null : _importTeam,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: teams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no creaste ningún equipo.\nTocá el botón + para agregar el primero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: teams.length,
                itemBuilder: (context, i) {
                  final team = teams[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups)),
                      title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${team.players.length} jugadores'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TeamFormScreen(team: team)),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final newTeam = Team(id: generateId('team_'), name: '');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeamFormScreen(team: newTeam, isNew: true)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo equipo'),
      ),
    );
  }
}
