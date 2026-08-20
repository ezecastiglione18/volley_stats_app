import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../state/match_controller.dart';
import '../../../utils/theme.dart';

class CourtView extends StatelessWidget {
  final MatchController controller;
  const CourtView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget cell(int pos) {
      final playerId = controller.playerAtPosition(pos);
      final player = controller.playerById(playerId);
      final isServer = pos == 1;
      final isLibero = player?.position == PlayerPosition.libero;
      final warning = warningColor(context);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(3),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isServer ? warning.withOpacity(0.16) : scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isServer ? warning : scheme.outline,
              width: isServer ? 2 : 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player == null ? '?' : '#${player.number} ${player.lastName}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.onSurface),
                ),
                if (player != null)
                  Text(
                    player.position.shortLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isLibero ? scheme.secondary : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(children: [cell(4), cell(3), cell(2)]),
          Row(children: [cell(5), cell(6), cell(1)]),
        ],
      ),
    );
  }
}
