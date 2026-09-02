import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../models/team.dart';
import '../../state/app_data_controller.dart';
import '../../utils/id_gen.dart';
import '../../widgets/theme_toggle_switch.dart';
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
  late TextEditingController _headCoachCtrl;
  late TextEditingController _assistantCoachCtrl;
  late TextEditingController _auxiliaryCtrl;
  late TextEditingController _doctorCtrl;
  late TextEditingController _physicalTrainerCtrl;
  late Team _team;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _nameCtrl = TextEditingController(text: _team.name);
    _headCoachCtrl = TextEditingController(text: _team.headCoach ?? '');
    _assistantCoachCtrl = TextEditingController(text: _team.assistantCoach ?? '');
    _auxiliaryCtrl = TextEditingController(text: _team.auxiliary ?? '');
    _doctorCtrl = TextEditingController(text: _team.doctor ?? '');
    _physicalTrainerCtrl = TextEditingController(text: _team.physicalTrainer ?? '');
  }

  Future<void> _save({bool showSnack = true}) async {
    _team.name = _nameCtrl.text.trim();
    if (_team.name.isEmpty) return;
    _team.headCoach = _headCoachCtrl.text.trim().isEmpty ? null : _headCoachCtrl.text.trim();
    _team.assistantCoach =
        _assistantCoachCtrl.text.trim().isEmpty ? null : _assistantCoachCtrl.text.trim();
    _team.auxiliary = _auxiliaryCtrl.text.trim().isEmpty ? null : _auxiliaryCtrl.text.trim();
    _team.doctor = _doctorCtrl.text.trim().isEmpty ? null : _doctorCtrl.text.trim();
    _team.physicalTrainer =
        _physicalTrainerCtrl.text.trim().isEmpty ? null : _physicalTrainerCtrl.text.trim();
    await context.read<AppDataController>().saveTeam(_team);
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Equipo guardado')));
    }
  }

  Future<void> _addPlayer() async {
    if (_team.players.length >= Team.maxPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: const Text('Máximo ${Team.maxPlayers} jugadores por equipo')),
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

  /// Resumen de una línea del cuerpo técnico cargado, para mostrar en la
  /// fila colapsada sin ocupar el espacio de los 5 campos.
  String get _staffSummary {
    final entries = <String>[];
    void add(String label, String value) {
      final v = value.trim();
      if (v.isNotEmpty) entries.add('$label: $v');
    }

    add('Entrenador', _headCoachCtrl.text);
    add('Asistente', _assistantCoachCtrl.text);
    add('Auxiliar', _auxiliaryCtrl.text);
    add('Médico', _doctorCtrl.text);
    add('Prep. físico', _physicalTrainerCtrl.text);
    return entries.isEmpty ? 'Sin cargar' : entries.join(' · ');
  }

  /// Abre los 5 campos del cuerpo técnico en una hoja modal en vez de
  /// mostrarlos siempre fijos en la pantalla principal.
  Future<void> _editStaff() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Cuerpo técnico (opcional)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _headCoachCtrl,
                    decoration: const InputDecoration(labelText: 'Entrenador'),
                    onChanged: (_) => _save(showSnack: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _assistantCoachCtrl,
                    decoration: const InputDecoration(labelText: 'Asistente de entrenador'),
                    onChanged: (_) => _save(showSnack: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _auxiliaryCtrl,
                    decoration: const InputDecoration(labelText: 'Auxiliar'),
                    onChanged: (_) => _save(showSnack: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _doctorCtrl,
                    decoration: const InputDecoration(labelText: 'Médico'),
                    onChanged: (_) => _save(showSnack: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _physicalTrainerCtrl,
                    decoration: const InputDecoration(labelText: 'Preparador físico'),
                    onChanged: (_) => _save(showSnack: false),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
    // Los TextField de la hoja modal usan los mismos controllers: refrescar
    // acá para que el resumen colapsado muestre lo recién editado.
    if (mounted) setState(() {});
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
          const ThemeToggleSwitch(),
          if (!widget.isNew)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteTeam),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del equipo / club'),
                      onChanged: (_) => _save(showSnack: false),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: const Text('Cuerpo técnico (opcional)'),
                        subtitle: Text(_staffSummary, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _editStaff,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                ],
              ),
            ),
            if (players.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Sin jugadores todavía', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = players[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                p.photoPath == null ? null : FileImage(File(p.photoPath!)),
                            child: p.photoPath == null ? Text('${p.number}') : null,
                          ),
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
                    childCount: players.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
