import 'package:flutter/material.dart';

import '../../models/match_config.dart';
import '../../models/player.dart';
import '../../models/team.dart';
import 'lineup_screen.dart';

class RosterScreen extends StatefulWidget {
  final Team ownTeam;
  final Team? rivalTeam;
  final String rivalTeamName;
  final String tournament;
  final String round;
  final String court;
  final String category;
  final DateTime date;
  final MatchConfig config;

  const RosterScreen({
    super.key,
    required this.ownTeam,
    required this.rivalTeam,
    required this.rivalTeamName,
    required this.tournament,
    required this.round,
    required this.court,
    required this.category,
    required this.date,
    required this.config,
  });

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final Set<String> _selected = {};
  static const int maxRoster = 14;

  String? _defensiveLiberoId;
  String? _receptionLiberoId;

  void _toggle(Player p) {
    setState(() {
      if (_selected.contains(p.id)) {
        _selected.remove(p.id);
        if (_defensiveLiberoId == p.id) _defensiveLiberoId = null;
        if (_receptionLiberoId == p.id) _receptionLiberoId = null;
      } else {
        if (_selected.length >= maxRoster) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya seleccionaste 14 jugadores')),
          );
          return;
        }
        _selected.add(p.id);
      }
    });
  }

  void _continue() {
    if (_selected.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná al menos 6 jugadores')),
      );
      return;
    }
    final roster = widget.ownTeam.players.where((p) => _selected.contains(p.id)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineupScreen(
          ownTeamName: widget.ownTeam.name,
          ownTeamSourceId: widget.ownTeam.id,
          rivalTeamName: widget.rivalTeamName,
          rivalTeamSourceId: widget.rivalTeam?.id,
          tournament: widget.tournament,
          round: widget.round,
          court: widget.court,
          category: widget.category,
          date: widget.date,
          config: widget.config,
          roster: roster,
          defensiveLiberoId: _defensiveLiberoId,
          receptionLiberoId: _receptionLiberoId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.ownTeam.players]..sort((a, b) => a.number.compareTo(b.number));
    final selectedLiberos = players
        .where((p) => _selected.contains(p.id) && p.position == PlayerPosition.libero)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Planilla — ${widget.ownTeam.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Seleccionados: ${_selected.length}/$maxRoster',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView(
              children: [
                if (players.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Este equipo no tiene jugadores cargados')),
                  )
                else
                  ...players.map((p) {
                    final checked = _selected.contains(p.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (_) => _toggle(p),
                      title: Text('#${p.number} ${p.fullName}'),
                      subtitle: Text(p.position.label),
                    );
                  }),
                if (selectedLiberos.isNotEmpty) ...[
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Roles de líbero (opcional)',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const Text(
                          'Podés asignar un líbero para la defensa cuando saca tu equipo y otro '
                          'para la recepción cuando saca el rival. También puede ser el mismo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: _defensiveLiberoId,
                          decoration:
                              const InputDecoration(labelText: 'Líbero defensor (cuando sacamos)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Ninguno')),
                            for (final p in selectedLiberos)
                              DropdownMenuItem(value: p.id, child: Text('#${p.number} ${p.fullName}')),
                          ],
                          onChanged: (v) => setState(() => _defensiveLiberoId = v),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: _receptionLiberoId,
                          decoration: const InputDecoration(
                              labelText: 'Líbero receptor (cuando saca el rival)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Ninguno')),
                            for (final p in selectedLiberos)
                              DropdownMenuItem(value: p.id, child: Text('#${p.number} ${p.fullName}')),
                          ],
                          onChanged: (v) => setState(() => _receptionLiberoId = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _continue,
              child: const Text('Continuar: formación inicial'),
            ),
          ),
        ],
      ),
    );
  }
}
