import 'player.dart';

class Team {
  final String id;
  String name;
  List<Player> players;

  /// Cuerpo técnico (todos opcionales).
  String? headCoach;
  String? assistantCoach;
  String? auxiliary;
  String? doctor;
  String? physicalTrainer;

  static const int maxPlayers = 35;

  Team({
    required this.id,
    required this.name,
    List<Player>? players,
    this.headCoach,
    this.assistantCoach,
    this.auxiliary,
    this.doctor,
    this.physicalTrainer,
  }) : players = players ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'players': players.map((p) => p.toJson()).toList(),
        'headCoach': headCoach,
        'assistantCoach': assistantCoach,
        'auxiliary': auxiliary,
        'doctor': doctor,
        'physicalTrainer': physicalTrainer,
      };

  factory Team.fromJson(Map<dynamic, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        players: ((json['players'] as List?) ?? [])
            .map((p) => Player.fromJson(Map<dynamic, dynamic>.from(p as Map)))
            .toList(),
        headCoach: json['headCoach'] as String?,
        assistantCoach: json['assistantCoach'] as String?,
        auxiliary: json['auxiliary'] as String?,
        doctor: json['doctor'] as String?,
        physicalTrainer: json['physicalTrainer'] as String?,
      );
}
