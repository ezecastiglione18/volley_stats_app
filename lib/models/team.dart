import 'player.dart';

class Team {
  final String id;
  String name;
  List<Player> players;

  static const int maxPlayers = 35;

  Team({
    required this.id,
    required this.name,
    List<Player>? players,
  }) : players = players ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<dynamic, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        players: ((json['players'] as List?) ?? [])
            .map((p) => Player.fromJson(Map<dynamic, dynamic>.from(p as Map)))
            .toList(),
      );
}
