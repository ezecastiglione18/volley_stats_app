import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../models/team.dart';
import '../../services/impact_engine.dart';
import '../../state/app_data_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';

/// Punto de entrada al análisis de impacto: primero hay que elegir a cuál de
/// los equipos propios cargados le queremos ver el impacto en cancha (se
/// arma con todos los partidos guardados de ese equipo), igual que el
/// scouting de rivales.
class PlayerImpactTeamPickerScreen extends StatelessWidget {
  const PlayerImpactTeamPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<AppDataController>().teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impacto en cancha'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: teams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no creaste ningún equipo. Creá uno desde la sección "Equipos" '
                    'para poder ver su análisis de impacto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: teams.length,
                itemBuilder: (context, i) {
                  final team = teams[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups)),
                      title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PlayerImpactScreen(team: team)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Impacto en cancha de cada jugador de [team]: puntos ganados/perdidos por
/// el equipo mientras estaba adentro, a lo largo de todos los partidos
/// guardados de ese equipo (titular o entrando por cambio). Pensado para
/// responder, con datos y no solo sensación, si un suplente rinde cuando
/// entra o si conviene repensar la rotación.
class PlayerImpactScreen extends StatelessWidget {
  final Team team;
  const PlayerImpactScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final matches = context
        .watch<AppDataController>()
        .matches
        .where((m) => m.ownTeamSourceId == team.id)
        .toList();
    final report = ImpactEngine.compute(matches);

    // Nombre de cada jugador: primero el plantel actual del equipo: si un
    // jugador ya no está (dado de baja), se busca en el roster guardado de
    // alguno de los partidos donde participó, para no mostrar solo el id.
    final playersById = <String, Player>{for (final p in team.players) p.id: p};
    for (final m in matches) {
      for (final p in m.ownRoster) {
        playersById.putIfAbsent(p.id, () => p);
      }
    }

    final rows = report.byPlayer.values.where((s) => s.rallies > 0).toList()
      ..sort((a, b) => (b.netPerRally ?? 0).compareTo(a.netPerRally ?? 0));

    return Scaffold(
      appBar: AppBar(title: Text('Impacto — ${team.name}')),
      body: SafeArea(
        top: false,
        child: matches.isEmpty || rows.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay partidos jugados con este equipo para poder calcular el impacto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.balance, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Diferencial del equipo',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  'Referencia para comparar: cuánto gana o pierde el equipo '
                                  'por punto jugado, en promedio, con cualquier formación.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _fmtSigned(report.teamNetPerRally),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Por jugador', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final stat in rows)
                    _PlayerImpactCard(
                      stat: stat,
                      player: playersById[stat.playerId],
                      teamNetPerRally: report.teamNetPerRally,
                    ),
                ],
              ),
      ),
    );
  }

  static String _fmtSigned(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';
}

class _PlayerImpactCard extends StatelessWidget {
  final PlayerImpactStats stat;
  final Player? player;
  final double teamNetPerRally;
  const _PlayerImpactCard({required this.stat, required this.player, required this.teamNetPerRally});

  @override
  Widget build(BuildContext context) {
    final netPerRally = stat.netPerRally ?? 0;
    final aboveAverage = netPerRally >= teamNetPerRally;
    final indicatorColor = aboveAverage ? successColor(context) : errorColor(context);
    final isSub = stat.timesEnteredAsSub > 0;
    final name = player == null
        ? 'Jugador (#${stat.playerId.length > 6 ? stat.playerId.substring(0, 6) : stat.playerId})'
        : '#${player!.number} ${player!.fullName}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: indicatorColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isSub)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: warningColor(context).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Suplente ×${stat.timesEnteredAsSub}',
                              style: TextStyle(fontSize: 11, color: warningColor(context))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stat.rallies} puntos en cancha · ${stat.pointsWonOnCourt}-${stat.pointsLostOnCourt}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  PlayerImpactScreen._fmtSigned(netPerRally),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: indicatorColor),
                ),
                Text('por punto', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
