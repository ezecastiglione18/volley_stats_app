/// Un partido por jugar (o ya jugado) del fixture de un equipo: la fecha, el
/// rival y los datos del torneo que después se cargan solos al armar el
/// partido real ("Elegir del fixture" en Nuevo Partido).
///
/// Se guarda en Hive como mapa plano, igual que los demás modelos
/// (`toJson`/`fromJson` a mano). Si la cuenta activó la nube, viaja con el
/// sync igual que los equipos (ver `MatchSyncService`).
class FixtureEntry {
  final String id;
  DateTime date;
  String tournament;
  String round; // instancia (fecha 3, cuartos, final...)
  String court; // cancha / sede
  String category;
  String rivalTeamName;

  /// Equipo rival precargado en "Equipos" (opcional).
  String? rivalTeamSourceId;
  String? notes;

  /// Id del `VolleyMatch` que se armó a partir de esta fila. Null = todavía
  /// sin jugar. Se pone cuando se crea el partido y se vuelve a null si ese
  /// partido se borra del archivo.
  String? linkedMatchId;

  /// Hora (del dispositivo) de la última edición: la estampa
  /// `AppDataController.saveFixtureEntry` (y vincular o desvincular un
  /// partido) y resuelve los conflictos del sync. Null en filas viejas.
  DateTime? updatedAt;

  /// Cuándo se borró la fila: queda oculta hasta la purga de los 30 días
  /// para que el borrado viaje a los otros dispositivos. Null = no borrada.
  DateTime? deletedAt;

  FixtureEntry({
    required this.id,
    required this.date,
    this.tournament = '',
    this.round = '',
    this.court = '',
    this.category = '',
    required this.rivalTeamName,
    this.rivalTeamSourceId,
    this.notes,
    this.linkedMatchId,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'tournament': tournament,
        'round': round,
        'court': court,
        'category': category,
        'rivalTeamName': rivalTeamName,
        'rivalTeamSourceId': rivalTeamSourceId,
        'notes': notes,
        'linkedMatchId': linkedMatchId,
        'updatedAt': updatedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory FixtureEntry.fromJson(Map<dynamic, dynamic> json) => FixtureEntry(
        id: json['id'] as String,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        tournament: json['tournament'] as String? ?? '',
        round: json['round'] as String? ?? '',
        court: json['court'] as String? ?? '',
        category: json['category'] as String? ?? '',
        rivalTeamName: json['rivalTeamName'] as String? ?? '',
        rivalTeamSourceId: json['rivalTeamSourceId'] as String?,
        notes: json['notes'] as String?,
        linkedMatchId: json['linkedMatchId'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      );
}
