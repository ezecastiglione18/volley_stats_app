import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../matches/match_summary_screen.dart';
import '../new_match/lineup_screen.dart';
import 'widgets/action_grid.dart';
import 'widgets/court_view.dart';
import 'widgets/scoreboard.dart';
import 'widgets/substitution_dialog.dart';

class LiveMatchScreen extends StatelessWidget {
  final MatchController controller;
  const LiveMatchScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchController>.value(
      value: controller,
      child: const _LiveMatchBody(),
    );
  }
}

class _LiveMatchBody extends StatefulWidget {
  const _LiveMatchBody();

  @override
  State<_LiveMatchBody> createState() => _LiveMatchBodyState();
}

class _LiveMatchBodyState extends State<_LiveMatchBody> {
  bool _handledEnd = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MatchController>();
    final match = controller.match;

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEndOfSet(context, controller));

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.ownTeamName} vs ${match.rivalTeamName}'),
        actions: [
          const ThemeToggleSwitch(),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Deshacer última acción',
            onPressed: controller.currentSet.events.isEmpty ? null : controller.undoLast,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Ver estadísticas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: match)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Cambio de jugador',
            onPressed: () => showSubstitutionDialog(context: context, controller: controller),
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Simular resto del set',
            onPressed: () => _confirmSimulate(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Abandonar partido',
            onPressed: () => _confirmAbandon(context, match.id),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Scoreboard(controller: controller),
              CourtView(controller: controller),
              const Divider(height: 1),
              ActionGrid(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSimulate(BuildContext context, MatchController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simular resto del set'),
        content: const Text(
            'Se van a cargar puntos aleatorios (jugador, calificación y resultado) hasta terminar el set actual. Podés deshacer cada acción después con el botón de deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simular'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.simulateRestOfSet();
    }
  }

  Future<void> _confirmAbandon(BuildContext context, String matchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonar partido'),
        content: const Text(
            'Se va a borrar todo lo cargado de este partido y no se puede deshacer. ¿Confirmás?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorColor(ctx), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _handledEnd = true;
    await context.read<AppDataController>().deleteMatch(matchId);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _checkEndOfSet(BuildContext context, MatchController controller) async {
    if (_handledEnd) return;
    final match = controller.match;

    if (match.status == MatchStatus.finished) {
      _handledEnd = true;
      await context.read<AppDataController>().saveMatch(match);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: match, justFinished: true)),
      );
      return;
    }

    if (controller.needsNextSetSetup) {
      _handledEnd = true;
      final finishedSet = match.sets.last;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Fin del set ${finishedSet.setNumber}'),
          content: Text(
              '${match.ownTeamName} ${finishedSet.ownScore} - ${finishedSet.rivalScore} ${match.rivalTeamName}\n\nSets: ${match.ownSetsWon} - ${match.rivalSetsWon}'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Configurar set siguiente'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LineupScreen(
            ownTeamName: match.ownTeamName,
            ownTeamSourceId: match.ownTeamSourceId,
            rivalTeamName: match.rivalTeamName,
            rivalTeamSourceId: match.rivalTeamSourceId,
            tournament: match.tournament,
            round: match.round,
            court: match.court,
            category: match.category,
            date: match.date,
            config: match.config,
            roster: match.ownRoster,
            existingController: controller,
          ),
        ),
      );
      _handledEnd = false;
    }
  }
}
