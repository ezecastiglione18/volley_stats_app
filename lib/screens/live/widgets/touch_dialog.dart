import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../utils/grade_labels.dart';

/// Muestra un modal para elegir jugador (si corresponde) y calificar el
/// toque. Devuelve (playerId, grade) o null si se canceló.
Future<void> showTouchDialog({
  required BuildContext context,
  required String title,
  required List<Player> players,
  String? fixedPlayerId, // si no es null, no se pide elegir jugador
  required List<GradeOption> grades,
  required void Function(String playerId, String grade) onConfirm,
}) async {
  String? selected = fixedPlayerId ?? (players.length == 1 ? players.first.id : null);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (fixedPlayerId == null) ...[
                  const Text('Jugador', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: players.map((p) {
                      final isSel = selected == p.id;
                      return ChoiceChip(
                        label: Text('#${p.number} ${p.lastName}'),
                        selected: isSel,
                        onSelected: (_) => setState(() => selected = p.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                ],
                const Text('Calificación', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: grades.length <= 4 ? grades.length : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.3,
                  children: grades.map((g) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: g.color,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: selected == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onConfirm(selected!, g.code);
                            },
                      child: Text(g.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
                if (selected == null && fixedPlayerId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Elegí un jugador para habilitar la calificación',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}
