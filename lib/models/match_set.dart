import 'rally_event.dart';
import 'sanction_event.dart';
import 'substitution_event.dart';

class MatchSet {
  final int setNumber;

  /// Orden cíclico de rotación del equipo propio para este set.
  /// index 0 = jugador que arranca en posición 1 (saque), index 1 = posición 2, etc.
  /// Se mantiene fijo durante todo el set (no se toca con las sustituciones):
  /// sirve como referencia de la formación inicial.
  List<String> startingOrderOwn;

  /// Igual que [startingOrderOwn] pero mutable: representa quién ocupa cada
  /// "slot" de rotación en este momento del set. Un cambio de jugador
  /// reemplaza el id en el índice correspondiente, y ese reemplazo sigue
  /// rotando con el equipo igual que lo hacía el titular.
  List<String> currentOrderOwn;

  /// Quién saca primero en este set.
  TeamSide startingServer;

  /// Posición (1-6) en la que arranca el armador rival. Es solo informativo,
  /// ya que no se lleva el detalle de rotación del equipo rival.
  int? rivalSetterStartPosition;

  int ownScore = 0;
  int rivalScore = 0;
  TeamSide? winner;
  bool finished = false;

  /// Cambios de jugador propios ya realizados en este set que cuentan contra
  /// el límite configurado (los cambios donde interviene un líbero son
  /// libres y no incrementan este contador).
  int substitutionsUsedOwn = 0;

  /// Si está activado, el saque, el ataque y la contra de este set piden
  /// (opcionalmente) la zona de cancha (1-6) a la que fue dirigido el toque.
  /// Se define una vez, al armar la formación de este set.
  bool trackHitZones;

  /// Líbero designado para la defensa cuando el equipo propio saca en este
  /// set (opcional). Se elige al armar la formación de cada set porque puede
  /// cambiar de un set a otro.
  String? defensiveLiberoId;

  /// Líbero designado para la recepción cuando saca el rival en este set
  /// (opcional). También es el líbero que entra automáticamente por el
  /// central que sacó si se pierde ese punto. Puede ser el mismo jugador que
  /// [defensiveLiberoId].
  String? receptionLiberoId;

  /// Si está activado, el líbero defensor entra automáticamente por un
  /// central que rota a la fila de fondo mientras el equipo propio saca (y
  /// ese central no es quien va a sacar), sin necesitar el cambio manual.
  /// Se elige una vez, al armar la formación de este set. Por defecto
  /// activado.
  bool autoLiberoBackRowSwap;

  final List<RallyEvent> events = [];
  final List<SubstitutionEvent> substitutions = [];
  final List<SanctionEvent> sanctions = [];

  MatchSet({
    required this.setNumber,
    required this.startingOrderOwn,
    required this.startingServer,
    this.trackHitZones = true,
    this.defensiveLiberoId,
    this.receptionLiberoId,
    this.autoLiberoBackRowSwap = true,
  }) : currentOrderOwn = List<String>.from(startingOrderOwn);

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'startingOrderOwn': startingOrderOwn,
        'currentOrderOwn': currentOrderOwn,
        'startingServer': startingServer.name,
        'rivalSetterStartPosition': rivalSetterStartPosition,
        'ownScore': ownScore,
        'rivalScore': rivalScore,
        'winner': winner?.name,
        'finished': finished,
        'substitutionsUsedOwn': substitutionsUsedOwn,
        'trackHitZones': trackHitZones,
        'defensiveLiberoId': defensiveLiberoId,
        'receptionLiberoId': receptionLiberoId,
        'autoLiberoBackRowSwap': autoLiberoBackRowSwap,
        'events': events.map((e) => e.toJson()).toList(),
        'substitutions': substitutions.map((s) => s.toJson()).toList(),
        'sanctions': sanctions.map((s) => s.toJson()).toList(),
      };

  factory MatchSet.fromJson(Map<dynamic, dynamic> json) {
    final s = MatchSet(
      setNumber: (json['setNumber'] as num).toInt(),
      startingOrderOwn: ((json['startingOrderOwn'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      startingServer: TeamSide.values
          .firstWhere((e) => e.name == json['startingServer']),
      trackHitZones: json['trackHitZones'] as bool? ?? true,
      defensiveLiberoId: json['defensiveLiberoId'] as String?,
      receptionLiberoId: json['receptionLiberoId'] as String?,
      autoLiberoBackRowSwap: json['autoLiberoBackRowSwap'] as bool? ?? true,
    );
    final savedCurrentOrder = (json['currentOrderOwn'] as List?)?.map((e) => e.toString()).toList();
    if (savedCurrentOrder != null && savedCurrentOrder.length == s.startingOrderOwn.length) {
      s.currentOrderOwn = savedCurrentOrder;
    }
    s.rivalSetterStartPosition = (json['rivalSetterStartPosition'] as num?)?.toInt();
    s.ownScore = (json['ownScore'] as num?)?.toInt() ?? 0;
    s.rivalScore = (json['rivalScore'] as num?)?.toInt() ?? 0;
    s.winner = json['winner'] == null
        ? null
        : TeamSide.values.firstWhere((e) => e.name == json['winner']);
    s.finished = json['finished'] as bool? ?? false;
    s.substitutionsUsedOwn = (json['substitutionsUsedOwn'] as num?)?.toInt() ?? 0;
    s.events.addAll(((json['events'] as List?) ?? [])
        .map((e) => RallyEvent.fromJson(Map<dynamic, dynamic>.from(e as Map))));
    s.substitutions.addAll(((json['substitutions'] as List?) ?? [])
        .map((e) => SubstitutionEvent.fromJson(Map<dynamic, dynamic>.from(e as Map))));
    s.sanctions.addAll(((json['sanctions'] as List?) ?? [])
        .map((e) => SanctionEvent.fromJson(Map<dynamic, dynamic>.from(e as Map))));
    return s;
  }
}
