import 'rally_event.dart';

class MatchSet {
  final int setNumber;

  /// Orden cíclico de rotación del equipo propio para este set.
  /// index 0 = jugador que arranca en posición 1 (saque), index 1 = posición 2, etc.
  List<String> startingOrderOwn;

  /// Quién saca primero en este set.
  TeamSide startingServer;

  /// Posición (1-6) en la que arranca el armador rival. Es solo informativo,
  /// ya que no se lleva el detalle de rotación del equipo rival.
  int? rivalSetterStartPosition;

  int ownScore = 0;
  int rivalScore = 0;
  TeamSide? winner;
  bool finished = false;

  final List<RallyEvent> events = [];

  MatchSet({
    required this.setNumber,
    required this.startingOrderOwn,
    required this.startingServer,
  });

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'startingOrderOwn': startingOrderOwn,
        'startingServer': startingServer.name,
        'rivalSetterStartPosition': rivalSetterStartPosition,
        'ownScore': ownScore,
        'rivalScore': rivalScore,
        'winner': winner?.name,
        'finished': finished,
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory MatchSet.fromJson(Map<dynamic, dynamic> json) {
    final s = MatchSet(
      setNumber: (json['setNumber'] as num).toInt(),
      startingOrderOwn: ((json['startingOrderOwn'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      startingServer: TeamSide.values
          .firstWhere((e) => e.name == json['startingServer']),
    );
    s.rivalSetterStartPosition = (json['rivalSetterStartPosition'] as num?)?.toInt();
    s.ownScore = (json['ownScore'] as num?)?.toInt() ?? 0;
    s.rivalScore = (json['rivalScore'] as num?)?.toInt() ?? 0;
    s.winner = json['winner'] == null
        ? null
        : TeamSide.values.firstWhere((e) => e.name == json['winner']);
    s.finished = json['finished'] as bool? ?? false;
    s.events.addAll(((json['events'] as List?) ?? [])
        .map((e) => RallyEvent.fromJson(Map<dynamic, dynamic>.from(e as Map))));
    return s;
  }
}
