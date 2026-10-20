import '../models/rally_event.dart';
import '../models/volley_match.dart';

/// Estadística de "impacto en cancha" de un jugador: cuántos puntos ganó y
/// perdió el equipo mientras ese jugador estaba en cancha (sea titular o
/// haya entrado por un cambio), a lo largo de uno o varios partidos. Es el
/// mismo concepto que el "+/-" (plus/minus) de básquet/hockey, adaptado a
/// vóley: sirve para responder "¿este suplente, cuando entra, el equipo
/// rinde mejor o peor?" con datos concretos en vez de sensación.
class PlayerImpactStats {
  final String playerId;
  int rallies = 0;
  int pointsWonOnCourt = 0;
  int pointsLostOnCourt = 0;

  /// Cuántas veces entró por un cambio de jugador (no cuenta la entrada
  /// inicial en la formación titular). Un jugador con 0 acá jugó siempre
  /// como titular en los partidos considerados; más de 0 lo marca como
  /// suplente habitual.
  int timesEnteredAsSub = 0;

  PlayerImpactStats(this.playerId);

  int get net => pointsWonOnCourt - pointsLostOnCourt;

  /// Diferencial de puntos por punto jugado en cancha. Comparándolo contra
  /// [ImpactReport.teamNetPerRally] se ve si el jugador rinde por encima o
  /// por debajo del promedio del equipo cuando está adentro.
  double? get netPerRally => rallies == 0 ? null : net / rallies;
}

class ImpactReport {
  final Map<String, PlayerImpactStats> byPlayer;

  /// Diferencial de puntos por punto jugado del EQUIPO en los partidos
  /// considerados (con cualquier formación) — la vara con la que se compara
  /// el rendimiento individual de cada jugador.
  final double teamNetPerRally;

  ImpactReport({required this.byPlayer, required this.teamNetPerRally});

  /// Jugadores con al menos una entrada por cambio, para no mezclar
  /// titulares fijos con suplentes en la comparación de impacto.
  List<PlayerImpactStats> get substitutes =>
      byPlayer.values.where((s) => s.timesEnteredAsSub > 0 && s.rallies > 0).toList()
        ..sort((a, b) => (b.netPerRally ?? 0).compareTo(a.netPerRally ?? 0));
}

class ImpactEngine {
  /// Recorre todos los sets de [matches] reconstruyendo, punto por punto,
  /// quiénes estaban en cancha (arrancando de `startingOrderOwn` y aplicando
  /// `substitutions` en orden por `rallyNumber`, igual que hace
  /// `MatchController.resume` para el estado en vivo) y les suma el
  /// resultado de cada punto jugado.
  static ImpactReport compute(List<VolleyMatch> matches) {
    final byPlayer = <String, PlayerImpactStats>{};
    var teamPointsWon = 0;
    var teamPointsLost = 0;
    var teamRallies = 0;

    PlayerImpactStats statFor(String playerId) =>
        byPlayer.putIfAbsent(playerId, () => PlayerImpactStats(playerId));

    for (final match in matches) {
      for (final set in match.sets) {
        final lineup = List<String>.from(set.startingOrderOwn);
        var nextSubIndex = 0;
        final subs = List.of(set.substitutions)
          ..sort((a, b) => a.rallyNumber.compareTo(b.rallyNumber));

        for (final entry in subs) {
          statFor(entry.playerInId).timesEnteredAsSub++;
        }

        for (final ev in set.events) {
          if (!ev.endsRally || ev.pointWinner == null) continue;

          // Aplicar los cambios que ya ocurrieron para este punto (un cambio
          // se registra con el número del punto que va a jugar el que entra).
          while (nextSubIndex < subs.length && subs[nextSubIndex].rallyNumber <= ev.rallyNumber) {
            final sub = subs[nextSubIndex];
            if (sub.slotIndex >= 0 && sub.slotIndex < lineup.length) {
              lineup[sub.slotIndex] = sub.playerInId;
            }
            nextSubIndex++;
          }

          final ownWon = ev.pointWinner == TeamSide.own;
          teamRallies++;
          if (ownWon) {
            teamPointsWon++;
          } else {
            teamPointsLost++;
          }

          for (final playerId in lineup) {
            if (playerId.isEmpty) continue;
            final stat = statFor(playerId);
            stat.rallies++;
            if (ownWon) {
              stat.pointsWonOnCourt++;
            } else {
              stat.pointsLostOnCourt++;
            }
          }
        }
      }
    }

    final teamNetPerRally =
        teamRallies == 0 ? 0.0 : (teamPointsWon - teamPointsLost) / teamRallies;

    return ImpactReport(byPlayer: byPlayer, teamNetPerRally: teamNetPerRally);
  }
}
