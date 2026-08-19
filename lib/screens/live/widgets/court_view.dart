import 'package:flutter/material.dart';

import '../../../state/match_controller.dart';

class CourtView extends StatelessWidget {
  final MatchController controller;
  const CourtView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    Widget cell(int pos) {
      final playerId = controller.playerAtPosition(pos);
      final player = controller.playerById(playerId);
      final isServer = pos == 1;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(3),
          height: 54,
          decoration: BoxDecoration(
            color: isServer ? const Color(0xFFFFF3E0) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isServer ? Colors.orange : Colors.grey.shade300,
              width: isServer ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              player == null ? '?' : '#${player.number}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
