import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../models/rally_event.dart' show TeamSide;
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
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              // El plantel puede tener hasta 16 jugadores: sin scroll, el
              // contenido no entra en la altura de un celular y se corta sin
              // avisar (no hay overflow visible, solo desaparecen jugadores).
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Cambio de jugador',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('Deshacer último cambio'),
                            onPressed: controller.canUndoLastSubstitution
                                ? () {
                                    controller.undoLastSubstitution();
                                    setState(() {});
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Cambio deshecho')),
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
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
                        _RegularWizard(
                          controller: controller,
                          playerOutId: playerOutId,
                          onPlayerOutSelected: (id) => setState(() => playerOutId = id),
                        ),
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

/// Wizard de "cambio regular", en el mismo espíritu que el de sanciones
/// (`sanction_dialog.dart`): paso 1 elige quién sale, paso 2 quién entra,
/// ambos desde un desplegable en vez de una grilla de fichas (con hasta 16
/// jugadores en el plantel, una grilla no siempre entra en el alto visible
/// del bottom sheet). Al elegir a quién entra se pide confirmación antes de
/// aplicar el cambio.
class _RegularWizard extends StatefulWidget {
  final MatchController controller;
  final String? playerOutId;
  final ValueChanged<String?> onPlayerOutSelected;

  const _RegularWizard({
    required this.controller,
    required this.playerOutId,
    required this.onPlayerOutSelected,
  });

  @override
  State<_RegularWizard> createState() => _RegularWizardState();
}

class _RegularWizardState extends State<_RegularWizard> {
  int _step = 0;
  // Cambia cada vez que se cancela una confirmación de cambio, para forzar
  // el remonte del desplegable de "¿Quién entra?" (un DropdownButtonFormField
  // no vuelve a leer `initialValue` solo porque el widget se reconstruya) y
  // que vuelva a mostrarse sin selección.
  int _inFieldGen = 0;

  static const _stepTitles = ['¿Quién sale?', '¿Quién entra?'];

  bool get _canAdvance => _step == 0 && widget.playerOutId != null;

  void _next() => setState(() => _step = 1);
  void _back() => setState(() => _step = 0);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Cambio regular', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Paso ${_step + 1} de 2', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cambios usados: ${controller.substitutionsUsedOwn} / '
          '${controller.match.config.hasUnlimitedSubstitutions ? 'Sin límite' : controller.match.config.maxSubstitutionsPerSet}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          'Cada titular tiene un único suplente fijo: puede salir por él una vez y '
          'volver a entrar una vez más, siempre entre esos dos mismos jugadores.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        Text(_stepTitles[_step], style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _step == 0 ? _buildOutStep(controller) : _buildInStep(controller),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 0) TextButton(onPressed: _back, child: const Text('Atrás')),
            const Spacer(),
            if (_step == 0)
              ElevatedButton(
                onPressed: _canAdvance ? _next : null,
                child: const Text('Siguiente'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutStep(MatchController controller) {
    final eligible = controller.onCourtPlayers.where((p) => controller.canSubOutRegular(p.id)).toList();
    if (eligible.isEmpty) {
      return const Text(
        'Ningún jugador en cancha puede salir por un cambio regular en este momento.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    final value = eligible.any((p) => p.id == widget.playerOutId) ? widget.playerOutId : null;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Jugador que sale', border: OutlineInputBorder()),
      items: eligible
          .map((p) => DropdownMenuItem(
                value: p.id,
                child: Text('#${p.number} ${p.lastName} · ${p.position.shortLabel}'),
              ))
          .toList(),
      onChanged: widget.onPlayerOutSelected,
    );
  }

  Widget _buildInStep(MatchController controller) {
    final playerOut = controller.playerById(widget.playerOutId!);
    if (playerOut == null) return const SizedBox.shrink();
    final bench = controller.eligibleRegularBenchFor(playerOut.id);
    if (bench.isEmpty) {
      return const Text('No hay suplente disponible para este jugador.',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    final blocked = !controller.canRegisterSubstitution;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ya se usaron todos los cambios disponibles en este set.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('playerIn-$_inFieldGen'),
          initialValue: null,
          decoration: const InputDecoration(labelText: 'Jugador que entra', border: OutlineInputBorder()),
          items: bench.map((p) {
            // "Cambio sugerido": resalta a quienes juegan la misma posición
            // que el titular que sale, como ayuda visual (no es una
            // restricción, el resto del banco sigue habilitado).
            final suggested = p.position == playerOut.position;
            return DropdownMenuItem(
              value: p.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (suggested) ...[
                    Icon(Icons.star, size: 16, color: scheme.secondary),
                    const SizedBox(width: 6),
                  ],
                  Text('#${p.number} ${p.lastName} · ${p.position.shortLabel}${suggested ? ' (sugerido)' : ''}'),
                ],
              ),
            );
          }).toList(),
          onChanged: blocked
              ? null
              : (playerInId) {
                  if (playerInId == null) return;
                  final playerIn = controller.playerById(playerInId);
                  if (playerIn == null) return;
                  _confirmAndSubstitute(controller, playerOut, playerIn);
                },
        ),
      ],
    );
  }

  Future<void> _confirmAndSubstitute(MatchController controller, Player playerOut, Player playerIn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: Text(
          'Sale #${playerOut.number} ${playerOut.lastName} · ${playerOut.position.shortLabel}\n'
          'Entra #${playerIn.number} ${playerIn.lastName} · ${playerIn.position.shortLabel}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      controller.substitutePlayer(playerOutId: playerOut.id, playerInId: playerIn.id);
      Navigator.pop(context);
    } else {
      setState(() => _inFieldGen++);
    }
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
        'No hay líberos configurados para este partido (se eligen al armar la planilla de 16).',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(
                        'En cancha: #${player!.number} ${player.lastName} · ${player.position.shortLabel}')),
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
            if (!canOut)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Todavía no se puede: hace falta que se juegue al menos un punto más '
                  'desde que entró este líbero (regla FIVB).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
      ));
    }

    // Centrales en fila trasera (posición 1, 5 o 6) que no están a punto de
    // sacar: sugerencia de cambiarlos por el líbero que corresponda según
    // quién saque (defensor si sacamos nosotros, receptor si saca el rival).
    final centralSuggestions = <Widget>[];
    final suggestedFor = <String>{};
    for (final p in onCourt.where((p) => p.position == PlayerPosition.central)) {
      final pos = controller.courtPositionOf(p.id);
      if (pos == null || (pos != 1 && pos != 5 && pos != 6)) continue;
      if (pos == 1 && controller.servingTeam == TeamSide.own) {
        continue; // está a punto de sacar: debe quedarse.
      }
      suggestedFor.add(p.id);
      final recommendedId = controller.servingTeam == TeamSide.own
          ? controller.currentSet.defensiveLiberoId
          : controller.currentSet.receptionLiberoId;
      final canSuggest = recommendedId != null && controller.canBringLiberoIn(recommendedId, p.id);
      final recommended = recommendedId == null ? null : controller.playerById(recommendedId);
      final roleLabel = controller.servingTeam == TeamSide.own ? 'defensor' : 'receptor';
      centralSuggestions.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Central #${p.number} ${p.lastName} en el fondo (pos. $pos) — líbero $roleLabel'
                '${recommended == null ? ' no configurado' : ': #${recommended.number} ${recommended.lastName}'}',
              ),
            ),
            if (canSuggest)
              ElevatedButton(
                onPressed: () {
                  controller.bringLiberoIn(recommendedId, p.id);
                  setState(() {});
                },
                child: const Text('Cambiar'),
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
          'salir por el mismo jugador al que reemplazó. Solo puede haber un líbero '
          'en cancha a la vez.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (rows.isNotEmpty) ...rows,
        if (centralSuggestions.isNotEmpty) ...[
          const Text('Central en el fondo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...centralSuggestions,
          const SizedBox(height: 8),
        ],
        const Text('Hacer entrar a un líbero', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...onCourt.where((p) => p.position != PlayerPosition.libero && !suggestedFor.contains(p.id)).map((p) {
          final options = liberoIds.where((id) => controller.canBringLiberoIn(id, p.id)).toList();
          if (options.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Por #${p.number} ${p.lastName} · ${p.position.shortLabel}:'),
                ...options.map((liberoId) {
                  final libero = controller.playerById(liberoId);
                  return ActionChip(
                    label: Text('#${libero?.number} ${libero?.lastName} · LIB'),
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
