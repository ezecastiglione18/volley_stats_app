import 'package:flutter/material.dart';

import '../../models/match_config.dart';
import '../../models/player.dart';
import '../../models/team.dart';
import '../../widgets/theme_toggle_switch.dart';
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

  // Filtro de posición solo para lo que se muestra en la lista: no afecta
  // a [_selected], así que los jugadores elegidos se mantienen aunque se
  // cambie o limpie el filtro.
  PlayerPosition? _positionFilter;

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
    final filteredPlayers = _positionFilter == null
        ? players
        : players.where((p) => p.position == _positionFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Planilla — ${widget.ownTeam.name}'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Seleccionados: ${_selected.length}/$maxRoster',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (players.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _positionFilter == null,
                    onSelected: (_) => setState(() => _positionFilter = null),
                  ),
                  for (final pos in PlayerPosition.values)
                    ChoiceChip(
                      label: Text(pos.shortLabel),
                      selected: _positionFilter == pos,
                      onSelected: (_) => setState(() => _positionFilter = pos),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (players.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Este equipo no tiene jugadores cargados')),
                  )
                else if (filteredPlayers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No hay jugadores en esa posición')),
                  )
                else
                  ...filteredPlayers.map((p) {
                    final checked = _selected.contains(p.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (_) => _toggle(p),
                      title: Text('#${p.number} ${p.fullName}'),
                      subtitle: Text(p.position.label),
                    );
                  }),
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
      ),
    );
  }
}
