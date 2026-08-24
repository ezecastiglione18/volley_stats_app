import 'match_config.dart';
import 'match_set.dart';
import 'player.dart';
import 'rally_event.dart';

enum MatchStatus { setup, inProgress, finished }

class VolleyMatch {
  final String id;
  DateTime date;
  String tournament; // Torneo / Liga
  String round; // Instancia (fecha, playoff, final, etc.)
  String court; // Cancha / sede
  String category; // Categoría

  String ownTeamName; // nombre del club/equipo propio ingresado por el usuario
  String? ownTeamSourceId; // referencia al Team precargado (puede ser null)
  List<Player> ownRoster; // snapshot de los jugadores habilitados (hasta 16)

  String rivalTeamName;
  String? rivalTeamSourceId;

  MatchConfig config;
  List<MatchSet> sets;
  MatchStatus status;

  VolleyMatch({
    required this.id,
    required this.date,
    this.tournament = '',
    this.round = '',
    this.court = '',
    this.category = '',
    required this.ownTeamName,
    this.ownTeamSourceId,
    required this.ownRoster,
    required this.rivalTeamName,
    this.rivalTeamSourceId,
    required this.config,
    List<MatchSet>? sets,
    this.status = MatchStatus.setup,
  }) : sets = sets ?? [];

  int get ownSetsWon => sets.where((s) => s.finished && s.winner == TeamSide.own).length;
  int get rivalSetsWon => sets.where((s) => s.finished && s.winner == TeamSide.rival).length;

  bool get isMatchOver =>
      ownSetsWon >= config.setsToWin || rivalSetsWon >= config.setsToWin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'tournament': tournament,
        'round': round,
        'court': court,
        'category': category,
        'ownTeamName': ownTeamName,
        'ownTeamSourceId': ownTeamSourceId,
        'ownRoster': ownRoster.map((p) => p.toJson()).toList(),
        'rivalTeamName': rivalTeamName,
        'rivalTeamSourceId': rivalTeamSourceId,
        'config': config.toJson(),
        'sets': sets.map((s) => s.toJson()).toList(),
        'status': status.name,
      };

  factory VolleyMatch.fromJson(Map<dynamic, dynamic> json) {
    final sets = ((json['sets'] as List?) ?? [])
        .map((s) => MatchSet.fromJson(Map<dynamic, dynamic>.from(s as Map)))
        .toList();

    // Migración: hasta esta versión los roles de líbero se guardaban una
    // sola vez a nivel partido; ahora viven por set (ver MatchSet). Los
    // partidos guardados antes de este cambio los completan acá para no
    // perder la configuración ya cargada.
    final legacyDefensiveLiberoId = json['defensiveLiberoId'] as String?;
    final legacyReceptionLiberoId = json['receptionLiberoId'] as String?;
    if (legacyDefensiveLiberoId != null || legacyReceptionLiberoId != null) {
      for (final set in sets) {
        set.defensiveLiberoId ??= legacyDefensiveLiberoId;
        set.receptionLiberoId ??= legacyReceptionLiberoId;
      }
    }

    return VolleyMatch(
      id: json['id'] as String,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      tournament: json['tournament'] as String? ?? '',
      round: json['round'] as String? ?? '',
      court: json['court'] as String? ?? '',
      category: json['category'] as String? ?? '',
      ownTeamName: json['ownTeamName'] as String? ?? '',
      ownTeamSourceId: json['ownTeamSourceId'] as String?,
      ownRoster: ((json['ownRoster'] as List?) ?? [])
          .map((p) => Player.fromJson(Map<dynamic, dynamic>.from(p as Map)))
          .toList(),
      rivalTeamName: json['rivalTeamName'] as String? ?? '',
      rivalTeamSourceId: json['rivalTeamSourceId'] as String?,
      config: MatchConfig.fromJson(
          Map<dynamic, dynamic>.from(json['config'] as Map? ?? {})),
      sets: sets,
      status: MatchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MatchStatus.setup,
      ),
    );
  }
}
