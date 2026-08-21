import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_config.dart';
import '../../models/team.dart';
import '../../state/app_data_controller.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'roster_screen.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _rivalNameCtrl = TextEditingController();
  final _tournamentCtrl = TextEditingController();
  final _roundCtrl = TextEditingController();
  final _courtCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  Team? _ownTeam;
  Team? _rivalTeam;
  final MatchConfig _config = MatchConfig();
  bool _configExpanded = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  //bool get _canContinue => _ownTeam != null && _rivalNameCtrl.text.trim().isNotEmpty;

  void _continue() {
    if (_ownTeam == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Elegí tu equipo')));
      return;
    }
    if (_rivalNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresá el nombre del rival')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RosterScreen(
          ownTeam: _ownTeam!,
          rivalTeam: _rivalTeam,
          rivalTeamName: _rivalNameCtrl.text.trim(),
          tournament: _tournamentCtrl.text.trim(),
          round: _roundCtrl.text.trim(),
          court: _courtCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          date: _date,
          config: _config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<AppDataController>().teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Partido'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Mi equipo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Team>(
            initialValue: _ownTeam,
            hint: const Text('Seleccioná tu equipo'),
            items: teams
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _ownTeam = v),
          ),
          if (teams.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Primero creá un equipo desde la sección "Equipos".',
                  style: TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 18),
          const Text('Rival', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _rivalNameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del equipo rival'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<Team?>(
            initialValue: _rivalTeam,
            decoration: const InputDecoration(labelText: 'Equipo rival precargado (opcional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Ninguno')),
              ...teams.map((t) => DropdownMenuItem(value: t, child: Text(t.name))),
            ],
            onChanged: (v) => setState(() {
              _rivalTeam = v;
              if (v != null && _rivalNameCtrl.text.trim().isEmpty) {
                _rivalNameCtrl.text = v.name;
              }
            }),
          ),
          const SizedBox(height: 18),
          const Text('Datos del partido', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          TextField(
            controller: _tournamentCtrl,
            decoration: const InputDecoration(labelText: 'Torneo / Liga'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _roundCtrl,
            decoration: const InputDecoration(labelText: 'Instancia (fecha 3, cuartos, final...)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _courtCtrl,
                  decoration: const InputDecoration(labelText: 'Cancha / sede'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              initiallyExpanded: _configExpanded,
              onExpansionChanged: (v) => setState(() => _configExpanded = v),
              title: const Text('Configuración del partido',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'Mejor de ${_config.maxSets} · sets a ${_config.setPoints} · tie-break a ${_config.tieBreakPoints}'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _NumberField(
                        label: 'Cantidad máxima de sets',
                        value: _config.maxSets,
                        onChanged: (v) => setState(() => _config.maxSets = v),
                        min: 1,
                        max: 7,
                        allowedOdd: true,
                      ),
                      _NumberField(
                        label: 'Puntos para ganar un set (1º al 4º)',
                        value: _config.setPoints,
                        onChanged: (v) => setState(() => _config.setPoints = v),
                        min: 5,
                        max: 50,
                      ),
                      _NumberField(
                        label: 'Diferencia mínima (sets 1º al 4º)',
                        value: _config.setWinMargin,
                        onChanged: (v) => setState(() => _config.setWinMargin = v),
                        min: 1,
                        max: 5,
                      ),
                      _NumberField(
                        label: 'Puntos para ganar el tie-break',
                        value: _config.tieBreakPoints,
                        onChanged: (v) => setState(() => _config.tieBreakPoints = v),
                        min: 5,
                        max: 30,
                      ),
                      _NumberField(
                        label: 'Diferencia mínima (tie-break)',
                        value: _config.tieBreakWinMargin,
                        onChanged: (v) => setState(() => _config.tieBreakWinMargin = v),
                        min: 1,
                        max: 5,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _config.hasUnlimitedSubstitutions,
                        title: const Text('Cambios permitidos por set: sin límite'),
                        onChanged: (v) => setState(() {
                          _config.maxSubstitutionsPerSet =
                              (v ?? false) ? MatchConfig.unlimited : 6;
                        }),
                      ),
                      if (!_config.hasUnlimitedSubstitutions)
                        _NumberField(
                          label: 'Cambios permitidos por set',
                          value: _config.maxSubstitutionsPerSet,
                          onChanged: (v) => setState(() => _config.maxSubstitutionsPerSet = v),
                          min: 1,
                          max: 10,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Continuar: elegir planilla de 14'),
          ),
        ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final bool allowedOdd;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.allowedOdd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min
                ? () => onChanged(allowedOdd ? _prevOdd(value, min) : value - 1)
                : null,
          ),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max
                ? () => onChanged(allowedOdd ? _nextOdd(value, max) : value + 1)
                : null,
          ),
        ],
      ),
    );
  }

  int _nextOdd(int v, int max) {
    var n = v + 1;
    if (n % 2 == 0) n += 1;
    return n > max ? v : n;
  }

  int _prevOdd(int v, int min) {
    var n = v - 1;
    if (n % 2 == 0) n -= 1;
    return n < min ? v : n;
  }
}
