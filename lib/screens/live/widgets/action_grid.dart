import 'package:flutter/material.dart';

import '../../../state/match_controller.dart';
import '../../../utils/grade_labels.dart';
import '../../../utils/theme.dart';
import 'player_select_dialog.dart';
import 'touch_dialog.dart';

class ActionButtonSpec {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  ActionButtonSpec({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
}

class ActionGrid extends StatelessWidget {
  final MatchController controller;
  const ActionGrid({super.key, required this.controller});

  void _serve(BuildContext context) {
    final serverId = controller.playerAtPosition(1);
    final player = controller.playerById(serverId);
    showTouchDialog(
      context: context,
      title: player == null ? 'Saque' : 'Saque — #${player.number} ${player.lastName}',
      players: player == null ? [] : [player],
      fixedPlayerId: serverId,
      grades: serveAttackGrades,
      trackZone: controller.currentSet.trackHitZones,
      onConfirm: (playerId, grade, zone) => controller.logServe(playerId, grade, targetZone: zone),
    );
  }

  void _reception(BuildContext context) {
    showTouchDialog(
      context: context,
      title: 'Recepción',
      players: controller.onCourtPlayers,
      grades: receptionGrades,
      onConfirm: (playerId, grade, zone) => controller.logReception(playerId, grade),
    );
  }

  void _attack(BuildContext context) {
    showTouchDialog(
      context: context,
      title: 'Ataque',
      players: controller.onCourtPlayers,
      grades: attackCounterGrades,
      trackZone: controller.currentSet.trackHitZones,
      onConfirm: (playerId, grade, zone) => controller.logAttack(playerId, grade, targetZone: zone),
    );
  }

  void _counter(BuildContext context) {
    showTouchDialog(
      context: context,
      title: 'Contraataque',
      players: controller.onCourtPlayers,
      grades: attackCounterGrades,
      trackZone: controller.currentSet.trackHitZones,
      onConfirm: (playerId, grade, zone) => controller.logCounter(playerId, grade, targetZone: zone),
    );
  }

  void _block(BuildContext context) {
    showMultiPlayerDialog(
      context: context,
      title: 'Punto de bloqueo',
      players: controller.onCourtPlayers,
      onConfirm: (ids) => controller.logBlockPoint(ids),
    );
  }

  void _genericError(BuildContext context) {
    showSinglePlayerDialog(
      context: context,
      title: 'Error general (rotación, 4 toques, etc.)',
      players: controller.onCourtPlayers,
      onConfirm: (id) => controller.logGenericError(playerId: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.secondary;
    final err = errorColor(context);
    final surfaceAlt = surfaceAltColor(context);

    final buttons = <ActionButtonSpec>[
      ActionButtonSpec(
        label: 'Saque',
        icon: Icons.sports_volleyball,
        color: accent,
        enabled: controller.actionServeEnabled,
        onTap: () => _serve(context),
      ),
      ActionButtonSpec(
        label: 'Recepción',
        icon: Icons.front_hand,
        color: accent,
        enabled: controller.actionReceptionEnabled,
        onTap: () => _reception(context),
      ),
      ActionButtonSpec(
        label: 'Ataque',
        icon: Icons.sports_kabaddi,
        color: accent,
        enabled: controller.actionAttackEnabled,
        onTap: () => _attack(context),
      ),
      ActionButtonSpec(
        label: 'Contra',
        icon: Icons.replay,
        color: accent,
        enabled: controller.actionCounterEnabled,
        onTap: () => _counter(context),
      ),
      ActionButtonSpec(
        label: 'Bloqueo\n(Punto)',
        icon: Icons.block,
        color: accent,
        enabled: controller.actionBlockEnabled,
        onTap: () => _block(context),
      ),
      ActionButtonSpec(
        label: 'Error\nGeneral',
        icon: Icons.report_gmailerrorred,
        color: err,
        enabled: controller.actionGenericErrorEnabled,
        onTap: () => _genericError(context),
      ),
      ActionButtonSpec(
        label: 'Punto\nRival',
        icon: Icons.arrow_circle_down,
        color: err,
        enabled: controller.actionOpponentButtonsEnabled,
        onTap: controller.logOpponentPoint,
      ),
      ActionButtonSpec(
        label: 'Error\nRival',
        icon: Icons.arrow_circle_up,
        color: err,
        enabled: controller.actionOpponentButtonsEnabled,
        onTap: controller.logOpponentError,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      padding: const EdgeInsets.all(12),
      children: buttons.map((b) {
        // El texto sobre el celeste de acento se ve mejor oscuro que blanco.
        final onColor = b.color == accent ? const Color(0xFF06222B) : Colors.white;
        return ElevatedButton.icon(
          onPressed: b.enabled ? b.onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: b.enabled ? b.color : surfaceAlt,
            foregroundColor: b.enabled ? onColor : scheme.onSurfaceVariant,
            disabledBackgroundColor: surfaceAlt,
            disabledForegroundColor: scheme.onSurfaceVariant,
            elevation: b.enabled ? 2 : 0,
          ),
          icon: Icon(b.icon, size: 20),
          label: Text(b.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }
}
