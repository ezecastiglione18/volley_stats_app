import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../state/subscription_controller.dart';
import '../../state/theme_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/premium_gate.dart';
import '../matches/match_summary_screen.dart';
import '../new_match/lineup_screen.dart';
import '../whiteboard/whiteboard_screen.dart';
import 'widgets/action_grid.dart';
import 'widgets/court_view.dart';
import 'widgets/sanction_dialog.dart';
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
  int? _infoShownForSet;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MatchController>();
    final match = controller.match;

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEndOfSet(context, controller));

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.ownTeamName} vs ${match.rivalTeamName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Deshacer última acción',
            onPressed: controller.canUndoLastAction ? controller.undoLastAction : null,
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
            icon: const Icon(Icons.draw_outlined),
            tooltip: 'Pizarra',
            onPressed: () => runIfPremium(
              context,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WhiteboardScreen()),
              ),
            ),
          ),
          IconButton(
            icon: Badge(
              label: Text('${controller.currentSet.sanctions.length}'),
              isLabelVisible: controller.currentSet.sanctions.isNotEmpty,
              child: const Icon(Icons.style_outlined),
            ),
            tooltip: 'Sanción / Tarjeta',
            onPressed: () => showSanctionDialog(context: context, controller: controller),
          ),
          if (controller.canConfirmSetFinished)
            IconButton(
              icon: const Icon(Icons.flag_circle_outlined),
              tooltip: 'Confirmar fin de set',
              onPressed: () => _confirmSetFinished(context, controller),
            ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) {
              if (v == 'simulate') {
                _confirmSimulate(context, controller);
              } else if (v == 'abandon') {
                _confirmAbandon(context, match.id);
              } else if (v == 'theme') {
                final themeController = context.read<ThemeController>();
                themeController.setDark(!themeController.isDark);
              }
            },
            itemBuilder: (menuContext) {
              final isDark = menuContext.read<ThemeController>().isDark;
              return [
                const PopupMenuItem(value: 'simulate', child: Text('Simular resto del set')),
                const PopupMenuItem(value: 'abandon', child: Text('Abandonar partido')),
                PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
                      const SizedBox(width: 12),
                      Text(isDark ? 'Modo claro' : 'Modo oscuro'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // En ventanas angostas (celular) se mantiene el scroll vertical
            // de siempre. En ventanas anchas (computadora) se arma un layout
            // de alto fijo con los botones en modo compacto, para que las 8
            // acciones entren siempre en pantalla sin necesitar scroll.
            if (constraints.maxWidth < 600) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Scoreboard(controller: controller),
                    CourtView(controller: controller),
                    const Divider(height: 1),
                    ActionGrid(controller: controller),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Scoreboard(controller: controller),
                CourtView(controller: controller),
                const Divider(height: 1),
                Expanded(child: ActionGrid(controller: controller, compact: true)),
              ],
            );
          },
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

  Future<void> _confirmSetFinished(BuildContext context, MatchController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fin de set'),
        content: const Text(
            'Una vez confirmado no se va a poder deshacer ningún punto de este set, ni aunque el árbitro lo revierta. ¿Confirmás que terminó?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.confirmSetFinished();
    }
  }

  Future<void> _checkEndOfSet(BuildContext context, MatchController controller) async {
    if (_handledEnd) return;
    final match = controller.match;
    final set = controller.currentSet;

    if (match.status == MatchStatus.finished) {
      // Solo se llega acá después de confirmar el set decisivo (ver
      // MatchController.confirmSetFinished), así que no hace falta chequear
      // `set.locked` de nuevo.
      _handledEnd = true;
      await context.read<AppDataController>().saveMatch(
            match,
            isPremium: context.read<SubscriptionController>().isPremium,
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: match, justFinished: true)),
      );
      return;
    }

    if (controller.needsNextSetSetup) {
      // Igual: solo se activa después de confirmar el set (needsNextSetSetup
      // se setea en confirmSetFinished), la confirmación ya pasó por el
      // botón del encabezado.
      _handledEnd = true;
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
      return;
    }

    if (set.finished && !set.locked && _infoShownForSet != set.setNumber) {
      _infoShownForSet = set.setNumber;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Fin del set ${set.setNumber}'),
          content: Text(
              '${match.ownTeamName} ${set.ownScore} - ${set.rivalScore} ${match.rivalTeamName}\n\n'
              'Confirmá con el botón "Confirmar fin de set" del encabezado cuando estés seguro: hasta '
              'ese momento podés seguir usando "Deshacer" si el árbitro revierte el último punto.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchSummaryScreen(match: match, initialSet: set.setNumber),
                  ),
                );
              },
              child: const Text('Ver estadísticas del set'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }
}
