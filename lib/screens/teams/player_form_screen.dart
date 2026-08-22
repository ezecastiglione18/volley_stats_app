import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../../utils/age_utils.dart';
import '../../widgets/theme_toggle_switch.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player player;
  const PlayerFormScreen({super.key, required this.player});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _number;
  late TextEditingController _height;
  late TextEditingController _weight;
  late TextEditingController _blockReach;
  late TextEditingController _attackReach;
  late TextEditingController _age;
  late PlayerPosition _position;
  DominantHand? _hand;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _firstName = TextEditingController(text: p.firstName);
    _lastName = TextEditingController(text: p.lastName);
    _number = TextEditingController(text: p.number == 0 ? '' : '${p.number}');
    _height = TextEditingController(text: p.heightCm?.toStringAsFixed(0) ?? '');
    _weight = TextEditingController(text: p.weightKg?.toStringAsFixed(0) ?? '');
    _blockReach = TextEditingController(text: p.blockReachCm?.toStringAsFixed(0) ?? '');
    _attackReach = TextEditingController(text: p.attackReachCm?.toStringAsFixed(0) ?? '');
    _birthDate = p.birthDate;
    _age = TextEditingController(
        text: _birthDate != null ? '${calculateAge(_birthDate!)}' : (p.age?.toString() ?? ''));
    _position = p.position;
    _hand = p.dominantHand;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _age.text = '${calculateAge(picked)}';
      });
    }
  }

  void _clearBirthDate() {
    setState(() {
      _birthDate = null;
      _age.clear();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final manualAge = int.tryParse(_age.text.trim());
    final result = Player(
      id: widget.player.id,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      number: int.tryParse(_number.text.trim()) ?? 0,
      position: _position,
      heightCm: double.tryParse(_height.text.trim()),
      weightKg: double.tryParse(_weight.text.trim()),
      dominantHand: _hand,
      blockReachCm: double.tryParse(_blockReach.text.trim()),
      attackReachCm: double.tryParse(_attackReach.text.trim()),
      birthDate: _birthDate,
      age: _birthDate != null ? calculateAge(_birthDate!) : manualAge,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jugador'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: Form(
        key: _formKey,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Apellido *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Nombre *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de camiseta *'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Número inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DominantHand?>(
            initialValue: _hand,
            decoration: const InputDecoration(labelText: 'Mano hábil (opcional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin especificar')),
              ...DominantHand.values
                  .map((h) => DropdownMenuItem(value: h, child: Text(h.label))),
            ],
            onChanged: (v) => setState(() => _hand = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PlayerPosition>(
            initialValue: _position,
            decoration: const InputDecoration(labelText: 'Posición *'),
            items: PlayerPosition.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (v) => setState(() => _position = v ?? _position),
          ),
          const SizedBox(height: 20),
          const Text('Edad (opcional)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_birthDate == null
                ? 'Fecha de nacimiento (opcional)'
                : 'Nace el ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
            trailing: _birthDate == null
                ? const Icon(Icons.calendar_today)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Quitar fecha de nacimiento',
                    onPressed: _clearBirthDate,
                  ),
            onTap: _pickBirthDate,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _age,
            enabled: _birthDate == null,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Edad (opcional)',
              helperText: _birthDate != null
                  ? 'Calculada automáticamente a partir de la fecha de nacimiento'
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Datos físicos (opcional)',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Altura (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _blockReach,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Alcance en bloqueo (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _attackReach,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Alcance en ataque (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: _save, child: const Text('Guardar jugador')),
        ],
        ),
        ),
      ),
    );
  }
}
