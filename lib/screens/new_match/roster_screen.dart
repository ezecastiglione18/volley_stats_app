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

  void _toggle(Player p) {
    setState(() {
      if (_selected.contains(p.id)) {
        _selected.remove(p.id);
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.ownTeam.players]..sort((a, b) => a.number.compareTo(b.number));

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
            child: players.isEmpty
                ? const Center(child: Text('Este equipo no tiene jugadores cargados'))
                : ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, i) {
                      final p = players[i];
                      final checked = _selected.contains(p.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (_) => _toggle(p),
                        title: Text('#${p.number} ${p.fullName}'),
                        subtitle: Text(p.position.label),
                      );
                    },
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
