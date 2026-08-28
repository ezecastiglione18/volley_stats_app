import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/rally_event.dart' show RivalAction;
import '../../../state/match_controller.dart';
import '../../../utils/grade_labels.dart';
import '../../../utils/theme.dart';
import 'player_select_dialog.dart';
import 'rival_action_dialog.dart';
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

  /// En pantallas anchas (ventana de escritorio), en vez de una grilla con
  /// alto fijo (que puede necesitar scroll) se arma con celdas `Expanded`
  /// para que los 8 botones siempre llenen el alto disponible sin scroll,
  /// achicándose si hace falta.
  final bool compact;

  const ActionGrid({super.key, required this.controller, this.compact = false});

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
      players: controller.onCourtAttackersAndBlockers,
      grades: attackCounterGrades,
      trackZone: controller.currentSet.trackHitZones,
      onConfirm: (playerId, grade, zone) => controller.logAttack(playerId, grade, targetZone: zone),
    );
  }

  void _counter(BuildContext context) {
    showTouchDialog(
      context: context,
      title: 'Contraataque',
      players: controller.onCourtAttackersAndBlockers,
      grades: attackCounterGrades,
      trackZone: controller.currentSet.trackHitZones,
      onConfirm: (playerId, grade, zone) => controller.logCounter(playerId, grade, targetZone: zone),
    );
  }

  void _block(BuildContext context) {
    showMultiPlayerDialog(
      context: context,
      title: 'Punto de bloqueo',
      players: controller.onCourtAttackersAndBlockers,
      onConfirm: (ids) => controller.logBlockPoint(ids),
    );
  }

  void _genericError(BuildContext context) {
    showSinglePlayerDialog(
      context: context,
      title: 'Error genérico (rotación, 4 toques, etc.)',
      players: controller.onCourtPlayers,
      onConfirm: (id) => controller.logGenericError(playerId: id),
    );
  }

  void _opponentPoint(BuildContext context) {
    showRivalActionDialog(
      context: context,
      title: 'Punto rival — ¿con qué tocó?',
      options: const [
        RivalActionOption(RivalAction.attack, 'Ataque'),
        RivalActionOption(RivalAction.counter, 'Contraataque'),
      ],
      onSelected: (type) => controller.logOpponentPoint(rivalActionType: type),
    );
  }

  void _opponentError(BuildContext context) {
    showRivalActionDialog(
      context: context,
      title: 'Error rival — ¿con qué tocó?',
      options: const [
        RivalActionOption(RivalAction.serve, 'Saque'),
        RivalActionOption(RivalAction.attack, 'Ataque'),
        RivalActionOption(RivalAction.counter, 'Contraataque'),
        RivalActionOption(RivalAction.generic, 'Genérico'),
      ],
      onSelected: (type) => controller.logOpponentError(rivalActionType: type),
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
        label: 'Contra',
        icon: Icons.replay,
        color: accent,
        enabled: controller.actionCounterEnabled,
        onTap: () => _counter(context),
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
        label: 'Bloqueo\n(Punto)',
        icon: Icons.block,
        color: accent,
        enabled: controller.actionBlockEnabled,
        onTap: () => _block(context),
      ),
      ActionButtonSpec(
        label: 'Error\nGenérico',
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
        onTap: () => _opponentPoint(context),
      ),
      ActionButtonSpec(
        label: 'Error\nRival',
        icon: Icons.arrow_circle_up,
        color: err,
        enabled: controller.actionOpponentErrorEnabled,
        onTap: () => _opponentError(context),
      ),
    ];

    Widget button(ActionButtonSpec b, {double iconSize = 20, double fontSize = 13}) {
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
        icon: Icon(b.icon, size: iconSize),
        label: Text(b.label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
      );
    }

    if (!compact) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
        padding: const EdgeInsets.all(12),
        children: buttons.map((b) => button(b)).toList(),
      );
    }

    // Modo compacto: filas de 2 botones con `Expanded` (mismo patrón que
    // `CourtView`) para que las 4 filas llenen siempre el alto disponible
    // sin necesitar scroll. El ícono y el texto escalan con el alto que le
    // toca a cada fila para verse proporcionales al tamaño de la ventana.
    const outerPadding = 7.0;
    const rowGap = 10.0; // padding vertical (5+5) entre filas consecutivas.
    final rowCount = (buttons.length / 2).ceil();

    return LayoutBuilder(builder: (context, constraints) {
      final availableHeight = constraints.maxHeight - outerPadding * 2;
      final rowHeight = rowCount > 0
          ? (availableHeight - rowGap * (rowCount - 1)) / rowCount
          : availableHeight;
      final clampedIconSize = math.min(32.0, math.max(16.0, rowHeight * 0.26));
      final clampedFontSize = math.min(17.0, math.max(11.0, rowHeight * 0.15));

      final rows = <Widget>[];
      for (var i = 0; i < buttons.length; i += 2) {
        rows.add(Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in buttons.skip(i).take(2))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: button(b, iconSize: clampedIconSize, fontSize: clampedFontSize),
                  ),
                ),
            ],
          ),
        ));
      }
      return Padding(
        padding: const EdgeInsets.all(outerPadding),
        child: Column(children: rows),
      );
    });
  }
}
