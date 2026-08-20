import 'package:flutter/material.dart';

import '../../../models/rally_event.dart';
import '../../../state/match_controller.dart';
import '../../../utils/theme.dart';

class Scoreboard extends StatelessWidget {
  final MatchController controller;
  const Scoreboard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final set = controller.currentSet;
    // El marcador siempre usa el color del AppBar (grafito), tanto en modo
    // claro como oscuro, para que el score quede siempre bien legible.
    final bg = Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: bg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamScore(context, match.ownTeamName, set.ownScore,
                  controller.servingTeam == TeamSide.own),
              const Text('SET', style: TextStyle(color: Colors.white70, fontSize: 12)),
              _teamScore(context, match.rivalTeamName, set.rivalScore,
                  controller.servingTeam == TeamSide.rival),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sets: ${match.ownSetsWon} - ${match.rivalSetsWon}   ·   Set N° ${set.setNumber}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _teamScore(BuildContext context, String name, int score, bool serving) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (serving)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.sports_volleyball, size: 14, color: warningColor(context)),
                ),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Text('$score',
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
