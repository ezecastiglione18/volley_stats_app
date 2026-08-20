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
  List<Player> ownRoster; // snapshot de los 14 jugadores habilitados

  String rivalTeamName;
  String? rivalTeamSourceId;

  MatchConfig config;
  List<MatchSet> sets;
  MatchStatus status;

  /// Líbero designado para la defensa cuando el equipo propio saca (opcional).
  String? defensiveLiberoId;

  /// Líbero designado para la recepción cuando saca el rival (opcional).
  /// También es el líbero que entra automáticamente por el central que sacó
  /// si se pierde ese punto. Puede ser el mismo jugador que [defensiveLiberoId].
  String? receptionLiberoId;

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
    this.defensiveLiberoId,
    this.receptionLiberoId,
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
        'defensiveLiberoId': defensiveLiberoId,
        'receptionLiberoId': receptionLiberoId,
      };

  factory VolleyMatch.fromJson(Map<dynamic, dynamic> json) => VolleyMatch(
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
        sets: ((json['sets'] as List?) ?? [])
            .map((s) => MatchSet.fromJson(Map<dynamic, dynamic>.from(s as Map)))
            .toList(),
        status: MatchStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MatchStatus.setup,
        ),
        defensiveLiberoId: json['defensiveLiberoId'] as String?,
        receptionLiberoId: json['receptionLiberoId'] as String?,
      );
}
