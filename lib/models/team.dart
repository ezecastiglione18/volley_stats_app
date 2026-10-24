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

  /// Hora (del dispositivo) de la última edición, la estampa
  /// `AppDataController.saveTeam`. En el sync con la nube gana el equipo
  /// entero con la más nueva (null cuenta como la más vieja). Null en
  /// equipos viejos y en el equipo de ejemplo recién cargado.
  DateTime? updatedAt;

  /// Cuándo se borró el equipo (ver `AppDataController.deleteTeam`): deja de
  /// aparecer en la lista y se purga a los 30 días. No afecta a los partidos
  /// (guardan su propia copia del plantel). Null en equipos viejos.
  DateTime? deletedAt;

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
    this.updatedAt,
    this.deletedAt,
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
        'updatedAt': updatedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
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
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      );
}
