import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/team.dart';
import '../../state/app_data_controller.dart';
import '../../utils/id_gen.dart';
import '../../utils/sample_team.dart';
import 'team_form_screen.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  Future<void> _loadSampleTeam(BuildContext context) async {
    final appData = context.read<AppDataController>();
    if (appData.teams.any((t) => t.name == 'UTN BA')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El equipo de ejemplo "UTN BA" ya existe')),
      );
      return;
    }
    await appData.saveTeam(buildSampleTeamUtnBa());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipo de ejemplo "UTN BA" agregado')),
      );
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
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Cargar equipo de ejemplo',
            onPressed: () => _loadSampleTeam(context),
          ),
        ],
      ),
      body: teams.isEmpty
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
