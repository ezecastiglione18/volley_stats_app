import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../models/team.dart';
import '../../state/app_data_controller.dart';
import '../../utils/id_gen.dart';
import 'player_form_screen.dart';

class TeamFormScreen extends StatefulWidget {
  final Team team;
  final bool isNew;
  const TeamFormScreen({super.key, required this.team, this.isNew = false});

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  late TextEditingController _nameCtrl;
  late Team _team;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _nameCtrl = TextEditingController(text: _team.name);
  }

  Future<void> _save({bool showSnack = true}) async {
    _team.name = _nameCtrl.text.trim();
    if (_team.name.isEmpty) return;
    await context.read<AppDataController>().saveTeam(_team);
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Equipo guardado')));
    }
  }

  Future<void> _addPlayer() async {
    if (_team.players.length >= Team.maxPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo ${Team.maxPlayers} jugadores por equipo')),
      );
      return;
    }
    final newPlayer = Player(
      id: generateId('pl_'),
      firstName: '',
      lastName: '',
      number: 0,
      position: PlayerPosition.puntaReceptor,
    );
    final result = await Navigator.push<Player>(
      context,
      MaterialPageRoute(builder: (_) => PlayerFormScreen(player: newPlayer)),
    );
    if (result != null) {
      setState(() => _team.players.add(result));
      await _save(showSnack: false);
    }
  }

  Future<void> _editPlayer(Player p) async {
    final result = await Navigator.push<Player>(
      context,
      MaterialPageRoute(builder: (_) => PlayerFormScreen(player: p)),
    );
    if (result != null) {
      setState(() {
        final idx = _team.players.indexWhere((e) => e.id == result.id);
        if (idx != -1) _team.players[idx] = result;
      });
      await _save(showSnack: false);
    }
  }

  Future<void> _deletePlayer(Player p) async {
    setState(() => _team.players.removeWhere((e) => e.id == p.id));
    await _save(showSnack: false);
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar equipo'),
        content: Text('¿Seguro que querés eliminar "${_team.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<AppDataController>().deleteTeam(_team.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = [..._team.players]..sort((a, b) => a.number.compareTo(b.number));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Nuevo equipo' : 'Editar equipo'),
        actions: [
          if (!widget.isNew)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteTeam),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del equipo / club'),
                onChanged: (_) => _save(showSnack: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Jugadores (${players.length}/${Team.maxPlayers})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addPlayer,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: players.isEmpty
                  ? const Center(
                      child: Text('Sin jugadores todavía', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: players.length,
                      itemBuilder: (context, i) {
                        final p = players[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${p.number}')),
                            title: Text(p.fullName.isEmpty ? '(sin nombre)' : p.fullName),
                            subtitle: Text(p.position.label),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => _deletePlayer(p),
                            ),
                            onTap: () => _editPlayer(p),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
