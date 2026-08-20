import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../../widgets/theme_toggle_switch.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player player;
  const PlayerFormScreen({super.key, required this.player});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _number;
  late TextEditingController _height;
  late TextEditingController _weight;
  late PlayerPosition _position;
  DominantHand? _hand;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _firstName = TextEditingController(text: p.firstName);
    _lastName = TextEditingController(text: p.lastName);
    _number = TextEditingController(text: p.number == 0 ? '' : '${p.number}');
    _height = TextEditingController(text: p.heightCm?.toStringAsFixed(0) ?? '');
    _weight = TextEditingController(text: p.weightKg?.toStringAsFixed(0) ?? '');
    _position = p.position;
    _hand = p.dominantHand;
  }

  void _save() {
    final result = Player(
      id: widget.player.id,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      number: int.tryParse(_number.text.trim()) ?? 0,
      position: _position,
      heightCm: double.tryParse(_height.text.trim()),
      weightKg: double.tryParse(_weight.text.trim()),
      dominantHand: _hand,
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
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Apellido'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de camiseta'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PlayerPosition>(
            initialValue: _position,
            decoration: const InputDecoration(labelText: 'Posición'),
            items: PlayerPosition.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (v) => setState(() => _position = v ?? _position),
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
          DropdownButtonFormField<DominantHand?>(
            initialValue: _hand,
            decoration: const InputDecoration(labelText: 'Mano de ataque'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin especificar')),
              ...DominantHand.values
                  .map((h) => DropdownMenuItem(value: h, child: Text(h.label))),
            ],
            onChanged: (v) => setState(() => _hand = v),
          ),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: _save, child: const Text('Guardar jugador')),
        ],
        ),
      ),
    );
  }
}
