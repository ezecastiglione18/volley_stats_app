import 'package:flutter/material.dart';

import '../../../models/player.dart';
import 'grouped_ficha_row.dart';

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
        builder: (ctx, setState) => SafeArea(
          top: false,
          child: Padding(
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
                groupedFichaRow(
                  players,
                  isSelected: (p) => selected.contains(p.id),
                  onSelect: (p) => setState(() {
                    if (selected.contains(p.id)) {
                      selected.remove(p.id);
                    } else {
                      selected.add(p.id);
                    }
                  }),
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
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ActionChip(
                label: const Text('No asignado'),
                onPressed: () {
                  Navigator.pop(ctx);
                  onConfirm(null);
                },
              ),
              const SizedBox(height: 8),
              groupedFichaRow(
                players,
                isSelected: (_) => false,
                onSelect: (p) {
                  Navigator.pop(ctx);
                  onConfirm(p.id);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
