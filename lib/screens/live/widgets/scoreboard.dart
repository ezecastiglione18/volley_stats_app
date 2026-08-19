import 'package:flutter/material.dart';

import '../../../models/rally_event.dart';
import '../../../state/match_controller.dart';

class Scoreboard extends StatelessWidget {
  final MatchController controller;
  const Scoreboard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    final set = controller.currentSet;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF123A78),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamScore(match.ownTeamName, set.ownScore,
                  controller.servingTeam == TeamSide.own),
              const Text('SET', style: TextStyle(color: Colors.white70, fontSize: 12)),
              _teamScore(match.rivalTeamName, set.rivalScore,
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

  Widget _teamScore(String name, int score, bool serving) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (serving)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.sports_volleyball, size: 14, color: Colors.orangeAccent),
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
