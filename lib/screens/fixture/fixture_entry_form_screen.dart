import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixture_entry.dart';
import '../../models/team.dart';
import '../../state/app_data_controller.dart';
import '../../utils/id_gen.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';

/// Alta o edición de una fila del fixture. Los campos y los controles son los
/// mismos que los de "Nuevo Partido" (fecha, rival con combo de equipo
/// precargado + nombre libre, torneo, instancia, categoría, cancha), más
/// notas. Con [entry] edita esa fila y muestra el botón de eliminar.
class FixtureEntryFormScreen extends StatefulWidget {
  final FixtureEntry? entry;
  const FixtureEntryFormScreen({super.key, this.entry});

  @override
  State<FixtureEntryFormScreen> createState() => _FixtureEntryFormScreenState();
}

class _FixtureEntryFormScreenState extends State<FixtureEntryFormScreen> {
  late final TextEditingController _rivalNameCtrl;
  late final TextEditingController _tournamentCtrl;
  late final TextEditingController _roundCtrl;
  late final TextEditingController _courtCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  String? _rivalTeamId;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _rivalNameCtrl = TextEditingController(text: e?.rivalTeamName ?? '');
    _tournamentCtrl = TextEditingController(text: e?.tournament ?? '');
    _roundCtrl = TextEditingController(text: e?.round ?? '');
    _courtCtrl = TextEditingController(text: e?.court ?? '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _rivalTeamId = e?.rivalTeamSourceId;
  }

  @override
  void dispose() {
    for (final c in [_rivalNameCtrl, _tournamentCtrl, _roundCtrl, _courtCtrl, _categoryCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final rival = _rivalNameCtrl.text.trim();
    if (rival.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresá el nombre del rival')));
      return;
    }
    final notes = _notesCtrl.text.trim();
    final entry = widget.entry ?? FixtureEntry(id: generateId('fixture_'), date: _date, rivalTeamName: rival);
    entry
      ..date = _date
      ..rivalTeamName = rival
      ..rivalTeamSourceId = _rivalTeamId
      ..tournament = _tournamentCtrl.text.trim()
      ..round = _roundCtrl.text.trim()
      ..court = _courtCtrl.text.trim()
      ..category = _categoryCtrl.text.trim()
      ..notes = notes.isEmpty ? null : notes;
    await context.read<AppDataController>().saveFixtureEntry(entry);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar del fixture'),
        content: Text('¿Eliminar el partido contra ${widget.entry!.rivalTeamName} del fixture?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppDataController>().deleteFixtureEntry(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<AppDataController>().teams;
    // Un equipo precargado que ya no existe no puede quedar como valor del combo.
    final selectedRival = teams.where((t) => t.id == _rivalTeamId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar partido del fixture' : 'Nuevo partido del fixture'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Eliminar',
              icon: Icon(Icons.delete_outline, color: errorColor(context)),
              onPressed: _delete,
            ),
          const ThemeToggleSwitch(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Rival', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _rivalNameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del equipo rival'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Team?>(
              key: ValueKey('rival-${selectedRival?.id}'),
              initialValue: selectedRival,
              decoration: const InputDecoration(labelText: 'Equipo rival precargado (opcional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguno')),
                ...teams.map((t) => DropdownMenuItem(value: t, child: Text(t.name))),
              ],
              onChanged: (v) => setState(() {
                _rivalTeamId = v?.id;
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
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
