import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../state/match_controller.dart';

/// Bottom sheet para registrar un cambio durante el set. Tiene dos modos:
/// - Cambio regular: titular <-> el mismo suplente fijo, cuenta contra el
///   cupo de cambios del set.
/// - Cambio de líbero: entra/sale un líbero declarado, siempre por el mismo
///   jugador al que reemplazó (o por el otro líbero declarado); libre, no
///   cuenta contra el cupo, y solo en puestos de fila trasera.
Future<void> showSubstitutionDialog({
  required BuildContext context,
  required MatchController controller,
}) async {
  var liberoMode = false;
  String? playerOutId;

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
                const Text('Cambio de jugador',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Cambio regular')),
                    ButtonSegment(value: true, label: Text('Cambio de líbero')),
                  ],
                  selected: {liberoMode},
                  onSelectionChanged: (s) => setState(() {
                    liberoMode = s.first;
                    playerOutId = null;
                  }),
                ),
                const SizedBox(height: 14),
                if (liberoMode)
                  _LiberoPanel(controller: controller, setState: setState)
                else
                  _RegularPanel(
                    controller: controller,
                    playerOutId: playerOutId,
                    onPlayerOutSelected: (id) => setState(() => playerOutId = id),
                    setState: setState,
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _RegularPanel extends StatelessWidget {
  final MatchController controller;
  final String? playerOutId;
  final ValueChanged<String?> onPlayerOutSelected;
  final StateSetter setState;

  const _RegularPanel({
    required this.controller,
    required this.playerOutId,
    required this.onPlayerOutSelected,
    required this.setState,
  });

  @override
  Widget build(BuildContext context) {
    final onCourt = controller.onCourtPlayers;
    final playerOut = playerOutId == null ? null : controller.playerById(playerOutId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cambios usados: ${controller.substitutionsUsedOwn} / ${controller.match.config.maxSubstitutionsPerSet}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          'Cada titular tiene un único suplente fijo: puede salir por él una vez y '
          'volver a entrar una vez más, siempre entre esos dos mismos jugadores.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        const Text('¿Quién sale?', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: onCourt.map((p) {
            final canGo = controller.canSubOutRegular(p.id);
            final isSel = playerOutId == p.id;
            return ChoiceChip(
              label: Text('#${p.number} ${p.lastName}'),
              selected: isSel,
              onSelected: canGo ? (_) => onPlayerOutSelected(isSel ? null : p.id) : null,
              backgroundColor: canGo ? null : Colors.grey.shade200,
              labelStyle: canGo ? null : TextStyle(color: Colors.grey.shade500),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('¿Quién entra?', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (playerOut == null)
          const Text('Elegí primero quién sale.', style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          Builder(builder: (context) {
            final bench = controller.eligibleRegularBenchFor(playerOut.id);
            final blocked = !controller.canRegisterSubstitution;
            if (bench.isEmpty) {
              return const Text('No hay suplente disponible para este jugador.',
                  style: TextStyle(fontSize: 12, color: Colors.grey));
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bench.map((p) {
                return ActionChip(
                  label: Text('#${p.number} ${p.lastName}'),
                  backgroundColor: blocked ? Colors.grey.shade200 : null,
                  onPressed: blocked
                      ? null
                      : () {
                          controller.substitutePlayer(playerOutId: playerOut.id, playerInId: p.id);
                          Navigator.pop(context);
                        },
                );
              }).toList(),
            );
          }),
      ],
    );
  }
}

class _LiberoPanel extends StatelessWidget {
  final MatchController controller;
  final StateSetter setState;

  const _LiberoPanel({required this.controller, required this.setState});

  @override
  Widget build(BuildContext context) {
    final liberoIds = controller.declaredLiberoIds;
    if (liberoIds.isEmpty) {
      return const Text(
        'No hay líberos configurados para este partido (se eligen al armar la planilla de 14).',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final onCourt = controller.onCourtPlayers;
    final rows = <Widget>[];

    // Líbero(s) actualmente en cancha: se pueden sacar (vuelve el jugador
    // reemplazado) o cambiar por el otro líbero declarado.
    for (var slot = 0; slot < 6; slot++) {
      // Buscamos si hay un líbero en este puesto consultando quién ocupa el
      // slot y si su posición es líbero.
      final playerId = controller.currentSet.currentOrderOwn[slot];
      final player = controller.playerById(playerId);
      if (player?.position != PlayerPosition.libero) continue;
      final canOut = controller.canSendLiberoOut(slot);
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text('En cancha: #${player!.number} ${player.lastName} (líbero)')),
            TextButton(
              onPressed: canOut
                  ? () {
                      controller.sendLiberoOut(slot);
                      setState(() {});
                    }
                  : null,
              child: const Text('Sacar'),
            ),
            if (liberoIds.length > 1)
              TextButton(
                onPressed: canOut
                    ? () {
                        controller.swapLiberoToOther(slot);
                        setState(() {});
                      }
                    : null,
                child: const Text('Cambiar por el otro líbero'),
              ),
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'El líbero solo puede entrar en un puesto de fila trasera y solo puede '
          'salir por el mismo jugador al que reemplazó.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (rows.isNotEmpty) ...rows,
        const Text('Hacer entrar a un líbero', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...onCourt.where((p) => p.position != PlayerPosition.libero).map((p) {
          final options = liberoIds.where((id) => controller.canBringLiberoIn(id, p.id)).toList();
          if (options.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Por #${p.number} ${p.lastName}:'),
                ...options.map((liberoId) {
                  final libero = controller.playerById(liberoId);
                  return ActionChip(
                    label: Text('#${libero?.number} ${libero?.lastName}'),
                    onPressed: () {
                      controller.bringLiberoIn(liberoId, p.id);
                      setState(() {});
                    },
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
