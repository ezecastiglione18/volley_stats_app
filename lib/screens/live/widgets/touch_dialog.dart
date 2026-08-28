import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../utils/grade_labels.dart';
import 'grouped_ficha_row.dart';
import 'hit_zone_picker.dart';

/// Muestra un modal para elegir jugador (si corresponde), calificar el
/// toque y, si [trackZone] está activo, elegir la zona de destino (opcional).
Future<void> showTouchDialog({
  required BuildContext context,
  required String title,
  required List<Player> players,
  String? fixedPlayerId, // si no es null, no se pide elegir jugador
  required List<GradeOption> grades,
  bool trackZone = false,
  required void Function(String playerId, String grade, int? targetZone) onConfirm,
}) async {
  String? selected = fixedPlayerId ?? (players.length == 1 ? players.first.id : null);
  int? selectedZone;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              // Con planteles grandes (hasta 16 jugadores) más zona de
              // destino y calificación, el contenido puede no entrar en la
              // altura de un celular: sin scroll se corta sin avisar.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (fixedPlayerId == null) ...[
                        const Text('Jugador', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        groupedFichaRow(
                          players,
                          isSelected: (p) => selected == p.id,
                          onSelect: (p) => setState(() => selected = p.id),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (trackZone) ...[
                        HitZonePicker(
                          selectedZone: selectedZone,
                          onChanged: (z) => setState(() => selectedZone = z),
                        ),
                        const SizedBox(height: 18),
                      ],
                      const Text('Calificación', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: grades.length <= 2 ? grades.length : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.9,
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
                                    onConfirm(selected!, g.code, selectedZone);
                                  },
                            child: Text(g.label,
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
