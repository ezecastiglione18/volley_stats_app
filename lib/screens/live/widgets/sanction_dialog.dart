import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/player.dart';
import '../../../models/rally_event.dart' show TeamSide;
import '../../../models/sanction_event.dart';
import '../../../state/match_controller.dart';

/// Bottom sheet para registrar una sanción/tarjeta del árbitro (Regla 21 de
/// la FIVB): equipo -> a quién sancionó -> categoría de conducta. El panel
/// calcula sola qué tarjeta corresponde (según el historial de esa persona
/// en el partido) y aplica el punto o la salida de cancha correspondiente.
/// Si la sanción obliga a abandonar la cancha a alguien que está jugando,
/// el mismo panel pide a continuación el reemplazo obligatorio (Regla 15.8).
Future<void> showSanctionDialog({
  required BuildContext context,
  required MatchController controller,
}) async {
  TeamSide? selTeam;
  SanctionTargetKind? selTargetKind;
  String? selTargetPlayerId;
  final rivalNumberCtrl = TextEditingController();
  SanctionCategory? selCategory;
  SanctionEvent? pendingReplacement;

  // El campo de número de camiseta rival es un TextEditingController plano
  // (no reactivo): este listener fuerza un rebuild del sheet cada vez que
  // cambia el texto, para que el panel de resultado (que depende de ese
  // número) se actualice mientras se escribe.
  StateSetter? refreshSheet;
  rivalNumberCtrl.addListener(() => refreshSheet?.call(() {}));

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          refreshSheet = setState;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: pendingReplacement == null
                  ? _MainFlow(
                      controller: controller,
                      selTeam: selTeam,
                      selTargetKind: selTargetKind,
                      selTargetPlayerId: selTargetPlayerId,
                      rivalNumberCtrl: rivalNumberCtrl,
                      selCategory: selCategory,
                      onPickTeam: (t) => setState(() {
                        selTeam = t;
                        selTargetKind = null;
                        selTargetPlayerId = null;
                        selCategory = null;
                      }),
                      onPickTarget: (kind, playerId) => setState(() {
                        selTargetKind = kind;
                        selTargetPlayerId = playerId;
                        selCategory = null;
                      }),
                      onPickCategory: (c) => setState(() => selCategory = c),
                      onRegister: () {
                        final rivalNumber = selTeam == TeamSide.rival &&
                                selTargetKind == SanctionTargetKind.player
                            ? int.tryParse(rivalNumberCtrl.text)
                            : null;
                        final sanction = controller.registerSanction(
                          team: selTeam!,
                          targetKind: selTargetKind!,
                          targetPlayerId: selTeam == TeamSide.own && selTargetKind == SanctionTargetKind.player
                              ? selTargetPlayerId
                              : null,
                          rivalNumber: rivalNumber,
                          category: selCategory!,
                        );
                        final needsReplacement = sanction.outcome.forcesOut &&
                            sanction.team == TeamSide.own &&
                            sanction.targetKind == SanctionTargetKind.player &&
                            sanction.targetPlayerId != null &&
                            controller.onCourtPlayers.any((p) => p.id == sanction.targetPlayerId);
                        if (needsReplacement) {
                          setState(() => pendingReplacement = sanction);
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Sanción registrada: ${sanction.outcome.title(sanction.category)}.'),
                        ));
                      },
                    )
                  : _ReplacementStep(
                      controller: controller,
                      sanction: pendingReplacement!,
                      onDone: (message) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(message)));
                      },
                    ),
            ),
          );
        },
      );
    },
  );
  rivalNumberCtrl.dispose();
}

/// Flujo principal del panel, armado como wizard (Atrás/Siguiente) en vez de
/// una sola pantalla larga: con el roster completo (hasta 16 fichas) en el
/// paso de "a quién sancionó", una sola Column sin scroll dejaba el tipo de
/// conducta y el botón de registrar fuera del alto visible del bottom sheet.
class _MainFlow extends StatefulWidget {
  final MatchController controller;
  final TeamSide? selTeam;
  final SanctionTargetKind? selTargetKind;
  final String? selTargetPlayerId;
  final TextEditingController rivalNumberCtrl;
  final SanctionCategory? selCategory;
  final ValueChanged<TeamSide> onPickTeam;
  final void Function(SanctionTargetKind kind, String? playerId) onPickTarget;
  final ValueChanged<SanctionCategory> onPickCategory;
  final VoidCallback onRegister;

  const _MainFlow({
    required this.controller,
    required this.selTeam,
    required this.selTargetKind,
    required this.selTargetPlayerId,
    required this.rivalNumberCtrl,
    required this.selCategory,
    required this.onPickTeam,
    required this.onPickTarget,
    required this.onPickCategory,
    required this.onRegister,
  });

  static String targetLabel(MatchController controller, SanctionEvent s) {
    if (s.targetKind == SanctionTargetKind.staff) {
      return s.team == TeamSide.own ? 'Banco / Cuerpo técnico' : 'Banco / Cuerpo técnico rival';
    }
    if (s.team == TeamSide.own) {
      final p = controller.playerById(s.targetPlayerId ?? '');
      return p == null ? 'Jugador' : '#${p.number} ${p.lastName}';
    }
    return 'Jugador rival #${s.rivalNumber ?? '?'}';
  }

  @override
  State<_MainFlow> createState() => _MainFlowState();
}

class _MainFlowState extends State<_MainFlow> {
  int _step = 0;

  static const _stepTitles = [
    '¿A qué equipo sancionó el árbitro?',
    '¿A quién sancionó?',
    '¿Qué tipo de conducta sancionó el árbitro?',
    'Confirmar sanción',
  ];

  String _targetLabel() {
    if (widget.selTargetKind == SanctionTargetKind.staff) {
      return widget.selTeam == TeamSide.own ? 'Banco / Cuerpo técnico' : 'Banco / Cuerpo técnico rival';
    }
    if (widget.selTeam == TeamSide.own) {
      final p = widget.controller.playerById(widget.selTargetPlayerId ?? '');
      return p == null ? '' : '#${p.number} ${p.lastName}';
    }
    final n = widget.rivalNumberCtrl.text.trim();
    return n.isEmpty ? 'jugador rival' : 'jugador rival #$n';
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return widget.selTeam != null;
      case 1:
        return widget.selTargetKind != null &&
            (widget.selTeam == TeamSide.own ||
                widget.selTargetKind == SanctionTargetKind.staff ||
                widget.rivalNumberCtrl.text.trim().isNotEmpty);
      case 2:
        return widget.selCategory != null;
      default:
        return false;
    }
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 3));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 3));

  @override
  Widget build(BuildContext context) {
    Widget stepBody;
    switch (_step) {
      case 0:
        stepBody = _buildTeamStep(context);
        break;
      case 1:
        stepBody = _buildTargetStep();
        break;
      case 2:
        stepBody = _buildCategoryStep();
        break;
      default:
        stepBody = _ResultPanel(
          controller: widget.controller,
          selTeam: widget.selTeam!,
          selTargetKind: widget.selTargetKind!,
          selTargetPlayerId: widget.selTargetPlayerId,
          rivalNumber: widget.selTeam == TeamSide.rival && widget.selTargetKind == SanctionTargetKind.player
              ? int.tryParse(widget.rivalNumberCtrl.text)
              : null,
          selCategory: widget.selCategory!,
          targetLabel: _targetLabel(),
          onRegister: widget.onRegister,
        );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Sanción / Tarjeta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('Paso ${_step + 1} de 4', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        if (_step == 0) ...[
          const SizedBox(height: 4),
          const Text(
            'Reglamento oficial FIVB (Regla 21), vigente también en FeVA y las federaciones metropolitanas.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 12),
        Text(_stepTitles[_step], style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        stepBody,
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 0) TextButton(onPressed: _back, child: const Text('Atrás')),
            const Spacer(),
            if (_step < 3)
              ElevatedButton(
                onPressed: _canAdvance ? _next : null,
                child: const Text('Siguiente'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamStep(BuildContext context) {
    final match = widget.controller.match;
    // Historial de ESTE set (no de todo el partido): para llevar la cuenta
    // de sanciones mientras se juega, ordenado del más reciente al primero.
    final history = widget.controller.currentSet.sanctions.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sanciones de este set (Set ${widget.controller.currentSet.setNumber})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        if (history.isEmpty)
          const Text('Todavía no se cargó ninguna en este set.',
              style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 130),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final s = history[i];
                final teamLabel = s.team == TeamSide.own ? match.ownTeamName : match.rivalTeamName;
                final cardColor = s.outcome.showsRed ? const Color(0xFFE1261C) : const Color(0xFFF5D400);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 26, decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_MainFlow.targetLabel(widget.controller, s)} · $teamLabel',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              '${s.outcome.title(s.category)} — Punto ${s.ownScoreAfter}-${s.rivalScoreAfter}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 14),
        SegmentedButton<TeamSide>(
          segments: [
            ButtonSegment(value: TeamSide.own, label: Text(match.ownTeamName)),
            ButtonSegment(value: TeamSide.rival, label: Text(match.rivalTeamName)),
          ],
          selected: widget.selTeam == null ? {} : {widget.selTeam!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) widget.onPickTeam(s.first);
          },
        ),
      ],
    );
  }

  Widget _buildTargetStep() {
    final match = widget.controller.match;
    if (widget.selTeam == TeamSide.own) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in match.ownRoster..sort((a, b) => a.number.compareTo(b.number)))
            ChoiceChip(
              label: Text('#${p.number} ${p.lastName} · ${p.position.shortLabel}'),
              selected: widget.selTargetKind == SanctionTargetKind.player && widget.selTargetPlayerId == p.id,
              onSelected: (_) => widget.onPickTarget(SanctionTargetKind.player, p.id),
            ),
          ChoiceChip(
            label: const Text('Banco / Cuerpo técnico'),
            selected: widget.selTargetKind == SanctionTargetKind.staff,
            onSelected: (_) => widget.onPickTarget(SanctionTargetKind.staff, null),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Jugador rival'),
              selected: widget.selTargetKind == SanctionTargetKind.player,
              onSelected: (_) => widget.onPickTarget(SanctionTargetKind.player, null),
            ),
            ChoiceChip(
              label: const Text('Banco / Cuerpo técnico rival'),
              selected: widget.selTargetKind == SanctionTargetKind.staff,
              onSelected: (_) => widget.onPickTarget(SanctionTargetKind.staff, null),
            ),
          ],
        ),
        if (widget.selTargetKind == SanctionTargetKind.player) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 140,
            child: TextField(
              controller: widget.rivalNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'N° de camiseta'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryStep() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in SanctionCategory.values)
          ChoiceChip(
            label: Text(cat.label),
            selected: widget.selCategory == cat,
            onSelected: (_) => widget.onPickCategory(cat),
          ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final MatchController controller;
  final TeamSide selTeam;
  final SanctionTargetKind selTargetKind;
  final String? selTargetPlayerId;
  final int? rivalNumber;
  final SanctionCategory selCategory;
  final String targetLabel;
  final VoidCallback onRegister;

  const _ResultPanel({
    required this.controller,
    required this.selTeam,
    required this.selTargetKind,
    required this.selTargetPlayerId,
    required this.rivalNumber,
    required this.selCategory,
    required this.targetLabel,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final preview = controller.previewSanction(
      team: selTeam,
      targetKind: selTargetKind,
      targetPlayerId: selTeam == TeamSide.own && selTargetKind == SanctionTargetKind.player
          ? selTargetPlayerId
          : null,
      rivalNumber: rivalNumber,
      category: selCategory,
    );
    final outcome = preview.outcome;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outcome.title(selCategory).toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: outcome == SanctionOutcome.advertencia ? Colors.grey.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${preview.occurrence}ª ${selCategory.label.toLowerCase()} de $targetLabel en el partido',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _CardChip(color: const Color(0xFFF5D400), visible: outcome.showsYellow),
            if (outcome.showsYellow && outcome.showsRed) const SizedBox(width: 4),
            _CardChip(color: const Color(0xFFE1261C), visible: outcome.showsRed),
          ]),
          const SizedBox(height: 8),
          Text(outcome.consequenceText, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRegister, child: const Text('Registrar sanción')),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final Color color;
  final bool visible;

  const _CardChip({required this.color, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: 22,
      height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }
}

class _ReplacementStep extends StatelessWidget {
  final MatchController controller;
  final SanctionEvent sanction;
  final ValueChanged<String> onDone;

  const _ReplacementStep({required this.controller, required this.sanction, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final playerOut = controller.playerById(sanction.targetPlayerId!);
    final options = controller.eligibleReplacementsForSanction(sanction.targetPlayerId!);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${sanction.outcome.title(sanction.category)}: reemplazo obligatorio',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          '#${playerOut?.number} ${playerOut?.lastName} debe abandonar la cancha. '
          'Elegí quién entra en su lugar (Regla 15.8 de la FIVB).',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        if (options.isEmpty)
          const Text(
            'No hay ningún suplente disponible en el banco (fuera de los líberos declarados): '
            'el equipo queda incompleto en esta posición.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in options)
                ActionChip(
                  avatar: playerOut != null && p.position == playerOut.position
                      ? Icon(Icons.star, size: 16, color: scheme.secondary)
                      : null,
                  label: Text('#${p.number} ${p.lastName} · ${p.position.shortLabel}'),
                  backgroundColor: playerOut != null && p.position == playerOut.position
                      ? scheme.secondary.withValues(alpha: 0.18)
                      : null,
                  side: playerOut != null && p.position == playerOut.position
                      ? BorderSide(color: scheme.secondary, width: 1.5)
                      : null,
                  onPressed: () {
                    controller.substituteForSanction(sanction.id, sanction.targetPlayerId!, p.id);
                    onDone(
                        '${sanction.outcome.title(sanction.category)} registrada: entra #${p.number} ${p.lastName}.');
                  },
                ),
            ],
          ),
      ],
    );
  }
}
