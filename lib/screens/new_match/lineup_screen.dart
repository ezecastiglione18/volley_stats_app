import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_config.dart';
import '../../models/player.dart';
import '../../models/rally_event.dart';
import '../../models/volley_match.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../utils/id_gen.dart';
import '../live/live_match_screen.dart';

class LineupScreen extends StatefulWidget {
  final String ownTeamName;
  final String? ownTeamSourceId;
  final String rivalTeamName;
  final String? rivalTeamSourceId;
  final String tournament;
  final String round;
  final String court;
  final String category;
  final DateTime date;
  final MatchConfig config;
  final List<Player> roster;

  // Si se pasa un [existingController], esta pantalla configura el
  // siguiente set de un partido ya en curso en lugar de crear uno nuevo.
  final MatchController? existingController;

  const LineupScreen({
    super.key,
    required this.ownTeamName,
    required this.ownTeamSourceId,
    required this.rivalTeamName,
    required this.rivalTeamSourceId,
    required this.tournament,
    required this.round,
    required this.court,
    required this.category,
    required this.date,
    required this.config,
    required this.roster,
    this.existingController,
  });

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  final Map<int, String?> _positions = {1: null, 2: null, 3: null, 4: null, 5: null, 6: null};
  TeamSide _startingServer = TeamSide.own;
  int? _rivalSetterPos;

  bool get _isNextSet => widget.existingController != null;

  List<Player> _availableFor(int pos) {
    final used = _positions.entries
        .where((e) => e.key != pos && e.value != null)
        .map((e) => e.value)
        .toSet();
    return widget.roster.where((p) => !used.contains(p.id)).toList();
  }

  bool get _complete => _positions.values.every((v) => v != null);

  Future<void> _start() async {
    if (!_complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asigná un jugador a cada una de las 6 posiciones')),
      );
      return;
    }
    final order = List.generate(6, (i) => _positions[i + 1]!);

    if (_isNextSet) {
      final controller = widget.existingController!;
      final setNumber = controller.match.sets.length + 1;
      controller.startSet(
        setNumber: setNumber,
        startingOrderOwn: order,
        startingServer: _startingServer,
      );
      controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
      await context.read<AppDataController>().saveMatch(controller.match);
      if (!mounted) return;
      Navigator.pop(context); // vuelve a la pantalla en vivo, que ya observa este mismo controller
      return;
    }

    final match = VolleyMatch(
      id: generateId('match_'),
      date: widget.date,
      tournament: widget.tournament,
      round: widget.round,
      court: widget.court,
      category: widget.category,
      ownTeamName: widget.ownTeamName,
      ownTeamSourceId: widget.ownTeamSourceId,
      ownRoster: widget.roster,
      rivalTeamName: widget.rivalTeamName,
      rivalTeamSourceId: widget.rivalTeamSourceId,
      config: widget.config,
    );
    final controller = MatchController(match);
    controller.startSet(
      setNumber: 1,
      startingOrderOwn: order,
      startingServer: _startingServer,
    );
    controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
    await context.read<AppDataController>().saveMatch(match);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LiveMatchScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Orden visual de la cancha (fila delantera 4-3-2, fila trasera 5-6-1).
    const frontRow = [4, 3, 2];
    const backRow = [5, 6, 1];

    return Scaffold(
      appBar: AppBar(title: Text(_isNextSet ? 'Formación — set siguiente' : 'Formación inicial')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('¿Quién saca primero?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<TeamSide>(
            segments: [
              ButtonSegment(value: TeamSide.own, label: Text(widget.ownTeamName)),
              ButtonSegment(value: TeamSide.rival, label: Text(widget.rivalTeamName)),
            ],
            selected: {_startingServer},
            onSelectionChanged: (s) => setState(() => _startingServer = s.first),
          ),
          const SizedBox(height: 20),
          Text('Formación de ${widget.ownTeamName}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Fila delantera (4 - 3 - 2)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          Row(children: frontRow.map((p) => Expanded(child: _posDropdown(p))).toList()),
          const SizedBox(height: 8),
          const Text('Fila trasera (5 - 6 - 1, el 1 saca)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          Row(children: backRow.map((p) => Expanded(child: _posDropdown(p))).toList()),
          const SizedBox(height: 24),
          const Text('Armador rival (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Solo a modo informativo: en qué posición arranca.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int?>(
            initialValue: _rivalSetterPos,
            decoration: const InputDecoration(labelText: 'Posición del armador rival'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin especificar')),
              for (final p in [1, 2, 3, 4, 5, 6])
                DropdownMenuItem(value: p, child: Text('Posición $p')),
            ],
            onChanged: (v) => setState(() => _rivalSetterPos = v),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _start,
            child: Text(_isNextSet
                ? 'Comenzar set ${(widget.existingController!.match.sets.length + 1)}'
                : 'Comenzar partido'),
          ),
        ],
      ),
    );
  }

  Widget _posDropdown(int pos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: DropdownButtonFormField<String?>(
        initialValue: _positions[pos],
        decoration: InputDecoration(labelText: 'Pos. $pos'),
        isExpanded: true,
        items: _availableFor(pos)
            .map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '#${p.number} ${p.fullName} · ${p.position.shortLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        selectedItemBuilder: (context) => _availableFor(pos)
            .map((p) => Text('#${p.number}', overflow: TextOverflow.ellipsis))
            .toList(),
        onChanged: (v) => setState(() => _positions[pos] = v),
      ),
    );
  }
}
