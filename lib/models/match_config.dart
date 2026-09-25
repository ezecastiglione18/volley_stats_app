class MatchConfig {
  /// Valor sentinela de [maxSubstitutionsPerSet] que representa "sin límite"
  /// de cambios por set.
  static const int unlimited = -1;

  int maxSets; // total sets playable (best of maxSets). Default 5.
  int setPoints; // points to win a regular set. Default 25.
  int setWinMargin; // minimum point margin to win a regular set. Default 2.
  int tieBreakPoints; // points to win the deciding set. Default 15.
  int tieBreakWinMargin; // minimum margin for the deciding set. Default 2.
  int maxSubstitutionsPerSet; // cambios de jugador permitidos por set (1-10, o [unlimited]). Default 6.

  /// Si está activado, la pantalla en vivo ofrece rotar al equipo propio a
  /// mano (sin que haya un side-out), p. ej. para corregir una rotación mal
  /// cargada o marcada por el árbitro. Por defecto desactivado.
  bool allowManualRotation;

  MatchConfig({
    this.maxSets = 5,
    this.setPoints = 25,
    this.setWinMargin = 2,
    this.tieBreakPoints = 15,
    this.tieBreakWinMargin = 2,
    this.maxSubstitutionsPerSet = 6,
    this.allowManualRotation = false,
  });

  bool get hasUnlimitedSubstitutions => maxSubstitutionsPerSet < 0;

  int get setsToWin => (maxSets / 2).ceil();

  bool isTieBreakSet(int setNumber) => setNumber == maxSets;

  int pointsToWin(int setNumber) =>
      isTieBreakSet(setNumber) ? tieBreakPoints : setPoints;

  int winMargin(int setNumber) =>
      isTieBreakSet(setNumber) ? tieBreakWinMargin : setWinMargin;

  Map<String, dynamic> toJson() => {
        'maxSets': maxSets,
        'setPoints': setPoints,
        'setWinMargin': setWinMargin,
        'tieBreakPoints': tieBreakPoints,
        'tieBreakWinMargin': tieBreakWinMargin,
        'maxSubstitutionsPerSet': maxSubstitutionsPerSet,
        'allowManualRotation': allowManualRotation,
      };

  factory MatchConfig.fromJson(Map<dynamic, dynamic> json) => MatchConfig(
        maxSets: (json['maxSets'] as num?)?.toInt() ?? 5,
        setPoints: (json['setPoints'] as num?)?.toInt() ?? 25,
        setWinMargin: (json['setWinMargin'] as num?)?.toInt() ?? 2,
        tieBreakPoints: (json['tieBreakPoints'] as num?)?.toInt() ?? 15,
        tieBreakWinMargin: (json['tieBreakWinMargin'] as num?)?.toInt() ?? 2,
        maxSubstitutionsPerSet: (json['maxSubstitutionsPerSet'] as num?)?.toInt() ?? 6,
        allowManualRotation: json['allowManualRotation'] as bool? ?? false,
      );

  MatchConfig copy() => MatchConfig(
        maxSets: maxSets,
        setPoints: setPoints,
        setWinMargin: setWinMargin,
        tieBreakPoints: tieBreakPoints,
        tieBreakWinMargin: tieBreakWinMargin,
        maxSubstitutionsPerSet: maxSubstitutionsPerSet,
        allowManualRotation: allowManualRotation,
      );
}
