import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../state/match_controller.dart';

/// Diálogo para declarar a un líbero sin poder jugar el resto del partido
/// (lesión, enfermedad o decisión del entrenador, Regla 19.4.1) y, si el
/// equipo se queda sin líbero disponible, redesignar a otro jugador como
/// líbero (Regla 19.4.2). Si el líbero que no puede seguir está en cancha,
/// pide además quién entra en su lugar. Con [onlyRedesignate] no se declara a
/// nadie (ya no queda ningún líbero disponible): solo se elige el nuevo.
/// Devuelve true si se registró algo.
Future<bool> showLiberoUnableDialog({
  required BuildContext context,
  required MatchController controller,
  bool onlyRedesignate = false,
}) async {
  final available = onlyRedesignate ? <String>[] : controller.rosterLiberoIds;
  final selected = <String>{if (available.length == 1) available.first};
  String? newLiberoId;
  String? courtReplacementId;

  String name(String id) {
    final p = controller.playerById(id);
    return p == null ? '?' : '#${p.number} ${p.lastName}';
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setState) {
        final canRedesignate = controller.redesignationAllowedAfter(selected);
        final candidates = canRedesignate ? controller.redesignationCandidates : <Player>[];
        if (!candidates.any((p) => p.id == newLiberoId)) newLiberoId = null;

        final slot = controller.liberoOnCourtSlot;
        final onCourtId = slot == -1 ? null : controller.currentSet.currentOrderOwn[slot];
        final leavesCourt = onCourtId != null &&
            (selected.contains(onCourtId) || !controller.rosterLiberoIds.contains(onCourtId));
        final courtOptions = leavesCourt
            ? controller.liberoCourtReplacementOptions(slot, unableIds: selected, newLiberoId: newLiberoId)
            : <String>[];
        if (!courtOptions.contains(courtReplacementId)) {
          courtReplacementId = courtOptions.isEmpty ? null : courtOptions.first;
        }

        final ready = (selected.isNotEmpty || newLiberoId != null) && (!onlyRedesignate || newLiberoId != null);

        return AlertDialog(
          title: Text(onlyRedesignate ? 'Redesignar líbero' : 'Líbero que no puede seguir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  onlyRedesignate
                      ? 'El equipo no tiene ningún líbero disponible. Podés nombrar como líbero, por el '
                          'resto del partido, a un jugador que no esté en cancha (salvo el que estaba '
                          'reemplazando el líbero). Regla 19.4 de la FIVB.'
                      : 'El líbero que marques no podrá volver a jugar en lo que queda del partido '
                          '(lesión, enfermedad o decisión del entrenador, Regla 19.4 de la FIVB).',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (!onlyRedesignate) ...[
                  const SizedBox(height: 12),
                  const Text('¿Qué líbero no puede seguir?', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final id in available)
                      FilterChip(
                        label: Text('${name(id)} · LIB'),
                        selected: selected.contains(id),
                        onSelected: (on) => setState(() => on ? selected.add(id) : selected.remove(id)),
                      ),
                  ]),
                ],
                if (canRedesignate) ...[
                  const SizedBox(height: 14),
                  const Text('Nuevo líbero', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    onlyRedesignate
                        ? 'Juega como líbero hasta el final del partido.'
                        : 'El equipo se queda sin líbero: podés redesignar uno ahora (juega como líbero '
                            'hasta el final del partido) o seguir sin líbero y hacerlo más tarde.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (candidates.isEmpty)
                    const Text('No hay ningún jugador en el banco que se pueda redesignar.',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (!onlyRedesignate)
                        ChoiceChip(
                          label: const Text('Sin redesignar'),
                          selected: newLiberoId == null,
                          onSelected: (_) => setState(() => newLiberoId = null),
                        ),
                      for (final p in candidates)
                        ChoiceChip(
                          label: Text('#${p.number} ${p.lastName} · ${p.position.shortLabel}'),
                          selected: newLiberoId == p.id,
                          onSelected: (_) => setState(() => newLiberoId = p.id),
                        ),
                    ]),
                ],
                if (leavesCourt && courtOptions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('${name(onCourtId)} está en cancha: ¿quién entra?',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final id in courtOptions)
                      ChoiceChip(
                        label: Text(id == newLiberoId
                            ? '${name(id)} (nuevo líbero)'
                            : controller.isLibero(id)
                                ? '${name(id)} · LIB'
                                : '${name(id)} (vuelve)'),
                        selected: courtReplacementId == id,
                        onSelected: (_) => setState(() => courtReplacementId = id),
                      ),
                  ]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: ready
                  ? () {
                      controller.declareLiberoUnable(
                        liberoIds: selected.toList(),
                        newLiberoId: newLiberoId,
                        courtReplacementId: courtReplacementId,
                      );
                      Navigator.pop(dctx, true);
                    }
                  : null,
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ),
  );
  return result == true;
}
