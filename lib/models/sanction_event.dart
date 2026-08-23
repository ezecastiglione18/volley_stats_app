import 'rally_event.dart' show TeamSide;

/// Categoría de conducta incorrecta, según la Regla 21 de la FIVB (vigente
/// también en FeVA y en las federaciones metropolitanas).
enum SanctionCategory { grosera, ofensiva, agresion, demora }

extension SanctionCategoryLabel on SanctionCategory {
  String get label {
    switch (this) {
      case SanctionCategory.grosera:
        return 'Conducta grosera';
      case SanctionCategory.ofensiva:
        return 'Conducta ofensiva';
      case SanctionCategory.agresion:
        return 'Agresión';
      case SanctionCategory.demora:
        return 'Demora/Advertencia';
    }
  }
}

/// A quién apunta la sanción: un jugador puntual del roster (propio) o del
/// rival por número de camiseta, o el banco/cuerpo técnico de un equipo.
enum SanctionTargetKind { player, staff }

/// Resultado de aplicar la escala de sanciones (Regla 21.3) según la
/// categoría y cuántas veces ya se sancionó a esa persona por esa categoría
/// en el partido.
enum SanctionOutcome { advertencia, castigo, expulsion, descalificacion }

extension SanctionOutcomeRules on SanctionOutcome {
  /// true solo para Castigo (grosera 1ª vez, o demora 2ª vez en adelante):
  /// otorga un punto y el saque al equipo contrario.
  bool get awardsPoint => this == SanctionOutcome.castigo;

  /// true para Expulsión y Descalificación: la persona debe abandonar la
  /// cancha (y, si estaba jugando, hay que reemplazarla).
  bool get forcesOut =>
      this == SanctionOutcome.expulsion || this == SanctionOutcome.descalificacion;

  /// 'set' o 'match': por cuánto tiempo queda afuera si [forcesOut].
  String get outScope {
    switch (this) {
      case SanctionOutcome.expulsion:
        return 'set';
      case SanctionOutcome.descalificacion:
        return 'match';
      case SanctionOutcome.advertencia:
      case SanctionOutcome.castigo:
        return '';
    }
  }

  bool get showsYellow =>
      this == SanctionOutcome.advertencia ||
      this == SanctionOutcome.expulsion ||
      this == SanctionOutcome.descalificacion;

  bool get showsRed => this != SanctionOutcome.advertencia;

  /// Título a mostrar (algunas variantes dependen de la categoría: la
  /// "demora" tiene su propio nombre de sanción aunque el resultado técnico
  /// (Amonestación / Castigo) sea el mismo que el de las otras categorías).
  String title(SanctionCategory category) {
    switch (this) {
      case SanctionOutcome.advertencia:
        return 'Amonestación';
      case SanctionOutcome.castigo:
        return category == SanctionCategory.demora ? 'Castigo por demora' : 'Castigo';
      case SanctionOutcome.expulsion:
        return category == SanctionCategory.agresion ? 'Descalificación directa' : 'Expulsión';
      case SanctionOutcome.descalificacion:
        return category == SanctionCategory.agresion ? 'Descalificación directa' : 'Descalificación';
    }
  }

  /// Tarjeta(s) que muestra el árbitro, tal como las describe el reglamento.
  String get cardsLabel {
    switch (this) {
      case SanctionOutcome.advertencia:
        return 'Amarilla';
      case SanctionOutcome.castigo:
        return 'Roja';
      case SanctionOutcome.expulsion:
        return 'Roja + Amarilla juntas';
      case SanctionOutcome.descalificacion:
        return 'Roja + Amarilla separadas';
    }
  }

  String get consequenceText {
    switch (this) {
      case SanctionOutcome.advertencia:
        return 'Solo prevención, sin efecto en el marcador.';
      case SanctionOutcome.castigo:
        return '1 punto y saque para el equipo rival.';
      case SanctionOutcome.expulsion:
        return 'Debe abandonar la cancha por el resto del set.';
      case SanctionOutcome.descalificacion:
        return 'Debe abandonar por el resto del partido.';
    }
  }
}

/// Escala de sanciones de la Regla 21.3 de la FIVB: dado que ya es la
/// [occurrence]-ésima vez que se sanciona a esta persona por esta
/// [category] en el partido, qué sanción corresponde.
SanctionOutcome computeSanctionOutcome(SanctionCategory category, int occurrence) {
  switch (category) {
    case SanctionCategory.grosera:
      if (occurrence <= 1) return SanctionOutcome.castigo;
      if (occurrence == 2) return SanctionOutcome.expulsion;
      return SanctionOutcome.descalificacion;
    case SanctionCategory.ofensiva:
      if (occurrence <= 1) return SanctionOutcome.expulsion;
      return SanctionOutcome.descalificacion;
    case SanctionCategory.agresion:
      return SanctionOutcome.descalificacion; // "descalificación directa"
    case SanctionCategory.demora:
      if (occurrence <= 1) return SanctionOutcome.advertencia;
      return SanctionOutcome.castigo; // "castigo por demora"
  }
}

/// Registro de una sanción/tarjeta mostrada por el árbitro durante el
/// partido (Regla 21 de la FIVB). Log append-only, igual que [RallyEvent] y
/// [SubstitutionEvent]: no se edita, solo se agrega o se saca el último.
class SanctionEvent {
  final String id;
  final int setNumber;
  final int rallyNumber;

  /// Equipo SANCIONADO (a quien el árbitro le mostró la tarjeta), no el que
  /// se beneficia.
  final TeamSide team;

  final SanctionTargetKind targetKind;

  /// Jugador del roster propio sancionado (solo si [team] es own y
  /// [targetKind] es player). Null si es del banco/cuerpo técnico, o si es
  /// un jugador rival (no se lleva roster rival, ver [rivalNumber]).
  final String? targetPlayerId;

  /// Número de camiseta del jugador rival sancionado (solo si [team] es
  /// rival y [targetKind] es player).
  final int? rivalNumber;

  final SanctionCategory category;

  /// N-ésima vez que se sanciona a esta persona por esta categoría en el
  /// partido (1, 2, 3...), calculada al momento de cargar la sanción.
  final int occurrence;

  final SanctionOutcome outcome;

  /// Si [outcome.awardsPoint]: id del RallyEvent (fase [RallyPhase.sanction])
  /// que registra el punto otorgado, para poder deshacerlos juntos.
  final String? linkedRallyEventId;

  /// Si [outcome.forcesOut] y la persona sancionada estaba en cancha: id de
  /// la SubstitutionEvent que la reemplazó, para poder deshacerlos juntos.
  final String? linkedSubstitutionEventId;

  /// Marcador del set justo después de aplicar esta sanción (sin cambios si
  /// no otorgaba punto), para poder mostrar "en qué punto fue" en el
  /// historial visual.
  final int ownScoreAfter;
  final int rivalScoreAfter;

  final DateTime timestamp;

  SanctionEvent({
    required this.id,
    required this.setNumber,
    required this.rallyNumber,
    required this.team,
    required this.targetKind,
    this.targetPlayerId,
    this.rivalNumber,
    required this.category,
    required this.occurrence,
    required this.outcome,
    this.linkedRallyEventId,
    this.linkedSubstitutionEventId,
    required this.ownScoreAfter,
    required this.rivalScoreAfter,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'setNumber': setNumber,
        'rallyNumber': rallyNumber,
        'team': team.name,
        'targetKind': targetKind.name,
        'targetPlayerId': targetPlayerId,
        'rivalNumber': rivalNumber,
        'category': category.name,
        'occurrence': occurrence,
        'outcome': outcome.name,
        'linkedRallyEventId': linkedRallyEventId,
        'linkedSubstitutionEventId': linkedSubstitutionEventId,
        'ownScoreAfter': ownScoreAfter,
        'rivalScoreAfter': rivalScoreAfter,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SanctionEvent.fromJson(Map<dynamic, dynamic> json) => SanctionEvent(
        id: json['id'] as String,
        setNumber: (json['setNumber'] as num).toInt(),
        rallyNumber: (json['rallyNumber'] as num?)?.toInt() ?? 1,
        team: TeamSide.values.firstWhere((e) => e.name == json['team'],
            orElse: () => TeamSide.own),
        targetKind: SanctionTargetKind.values.firstWhere((e) => e.name == json['targetKind'],
            orElse: () => SanctionTargetKind.staff),
        targetPlayerId: json['targetPlayerId'] as String?,
        rivalNumber: (json['rivalNumber'] as num?)?.toInt(),
        category: SanctionCategory.values.firstWhere((e) => e.name == json['category'],
            orElse: () => SanctionCategory.grosera),
        occurrence: (json['occurrence'] as num?)?.toInt() ?? 1,
        outcome: SanctionOutcome.values.firstWhere((e) => e.name == json['outcome'],
            orElse: () => SanctionOutcome.advertencia),
        linkedRallyEventId: json['linkedRallyEventId'] as String?,
        linkedSubstitutionEventId: json['linkedSubstitutionEventId'] as String?,
        ownScoreAfter: (json['ownScoreAfter'] as num?)?.toInt() ?? 0,
        rivalScoreAfter: (json['rivalScoreAfter'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}
