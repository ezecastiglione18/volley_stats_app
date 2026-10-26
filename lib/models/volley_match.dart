import 'match_config.dart';
import 'match_set.dart';
import 'player.dart';
import 'rally_event.dart';
import 'sanction_event.dart';

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

  /// Notas de scouting en texto libre (cómo saca el rival, qué reforzar,
  /// etc.). Null = sin notas, también en partidos guardados antes de este
  /// campo.
  String? notes;

  /// Fila del fixture (`FixtureEntry.id`) a partir de la cual se armó este
  /// partido, si se eligió "del fixture" al crearlo. Null en partidos viejos
  /// y en los armados a mano.
  String? fixtureEntryId;

  /// Hora (del dispositivo) de la última edición: la estampa
  /// `AppDataController.saveMatch`, y también mandar a la papelera y
  /// restaurar. Resuelve los conflictos del sync con la nube (gana la más
  /// nueva; null cuenta como la más vieja). Null en partidos viejos.
  DateTime? updatedAt;

  /// Cuándo se mandó a la papelera (ver `AppDataController.trashMatch`);
  /// null = no está en la papelera. A los 30 días se borra definitivamente.
  /// Null en partidos viejos.
  DateTime? deletedAt;

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
    this.notes,
    this.fixtureEntryId,
    this.updatedAt,
    this.deletedAt,
  }) : sets = sets ?? [];

  int get ownSetsWon => sets.where((s) => s.finished && s.winner == TeamSide.own).length;
  int get rivalSetsWon => sets.where((s) => s.finished && s.winner == TeamSide.rival).length;

  bool get isMatchOver =>
      ownSetsWon >= config.setsToWin || rivalSetsWon >= config.setsToWin;

  /// Líberos del partido: los de la planilla más los jugadores redesignados
  /// como líbero (Regla 19.4.2, ver `LiberoUnableEvent`), que lo son desde
  /// ese momento hasta el final del partido. Incluye a los que ya no pueden
  /// jugar (ver [unableLiberoIds]).
  Set<String> get liberoIds => {
        for (final p in ownRoster)
          if (p.position == PlayerPosition.libero) p.id,
        for (final s in sets)
          for (final e in s.liberoUnableEvents)
            if (e.newLiberoId != null) e.newLiberoId!,
      };

  bool isLibero(String playerId) => liberoIds.contains(playerId);

  /// Líberos declarados sin poder jugar (Regla 19.4.1): no vuelven a jugar
  /// en lo que queda del partido.
  Set<String> get unableLiberoIds => {
        for (final s in sets)
          for (final e in s.liberoUnableEvents) ...e.unableLiberoIds,
      };

  /// true si [playerId] no puede volver a jugar en lo que queda del
  /// partido, en ningún set: una Descalificación (Regla 21.3.3), haber
  /// salido por un cambio excepcional (Regla 15.7) o ser un líbero
  /// declarado sin poder jugar (Regla 19.4). La Expulsión, que solo vale
  /// para el set en que se dio, la resuelve `MatchController.isBarredFromPlay`.
  bool isBarredForMatch(String playerId) {
    if (unableLiberoIds.contains(playerId)) return true;
    for (final set in sets) {
      for (final s in set.substitutions) {
        if (s.exceptional && s.playerOutId == playerId) return true;
      }
      for (final s in set.sanctions) {
        if (s.team == TeamSide.own &&
            s.targetKind == SanctionTargetKind.player &&
            s.targetPlayerId == playerId &&
            s.outcome == SanctionOutcome.descalificacion) {
          return true;
        }
      }
    }
    return false;
  }

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
        'notes': notes,
        'fixtureEntryId': fixtureEntryId,
        'updatedAt': updatedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
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
      notes: json['notes'] as String?,
      fixtureEntryId: json['fixtureEntryId'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
    );
  }
}
