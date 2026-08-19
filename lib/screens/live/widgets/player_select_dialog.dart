import 'package:flutter/material.dart';

import '../../../models/player.dart';

/// Selección múltiple de jugadores (por ejemplo, para un bloqueo doble).
Future<void> showMultiPlayerDialog({
  required BuildContext context,
  required String title,
  required List<Player> players,
  required void Function(List<String> playerIds) onConfirm,
}) async {
  final selected = <String>{};
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Podés elegir uno o más jugadores (bloqueo doble/triple).',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((p) {
                  final isSel = selected.contains(p.id);
                  return FilterChip(
                    label: Text('#${p.number} ${p.lastName}'),
                    selected: isSel,
                    onSelected: (v) => setState(() {
                      if (v) {
                        selected.add(p.id);
                      } else {
                        selected.remove(p.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        onConfirm(selected.toList());
                      },
                child: const Text('Confirmar punto de bloqueo'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Selección de un único jugador, con opción "No asignado".
Future<void> showSinglePlayerDialog({
  required BuildContext context,
  required String title,
  required List<Player> players,
  required void Function(String? playerId) onConfirm,
}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('No asignado'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm(null);
                  },
                ),
                ...players.map((p) => ActionChip(
                      label: Text('#${p.number} ${p.lastName}'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm(p.id);
                      },
                    )),
              ],
            ),
          ],
        ),
      );
    },
  );
}
