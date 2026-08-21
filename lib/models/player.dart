import '../utils/age_utils.dart';

enum PlayerPosition {
  armador, // Colocador / Setter
  opuesto, // Opposite
  central, // Middle blocker
  puntaReceptor, // Outside / Wing spiker
  libero, // Libero
}

extension PlayerPositionLabel on PlayerPosition {
  String get label {
    switch (this) {
      case PlayerPosition.armador:
        return 'Armador';
      case PlayerPosition.opuesto:
        return 'Opuesto';
      case PlayerPosition.central:
        return 'Central';
      case PlayerPosition.puntaReceptor:
        return 'Punta/Receptor';
      case PlayerPosition.libero:
        return 'Líbero';
    }
  }

  String get shortLabel {
    switch (this) {
      case PlayerPosition.armador:
        return 'ARM';
      case PlayerPosition.opuesto:
        return 'OP';
      case PlayerPosition.central:
        return 'CEN';
      case PlayerPosition.puntaReceptor:
        return 'P/R';
      case PlayerPosition.libero:
        return 'LIB';
    }
  }
}

enum DominantHand { derecha, izquierda }

extension DominantHandLabel on DominantHand {
  String get label => this == DominantHand.derecha ? 'Derecha' : 'Izquierda';
}

class Player {
  final String id;
  String firstName;
  String lastName;
  int number;
  PlayerPosition position;
  double? heightCm;
  double? weightKg;
  DominantHand? dominantHand;
  double? blockReachCm;
  double? attackReachCm;

  /// Fecha de nacimiento (opcional). Si está cargada, tiene prioridad sobre
  /// [age] para calcular la edad (ver [effectiveAge]).
  DateTime? birthDate;

  /// Edad cargada a mano, solo se usa si no hay [birthDate].
  int? age;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.number,
    required this.position,
    this.heightCm,
    this.weightKg,
    this.dominantHand,
    this.blockReachCm,
    this.attackReachCm,
    this.birthDate,
    this.age,
  });

  String get fullName => '$lastName, $firstName';
  String get displayShort => '#$number $lastName';

  /// Edad efectiva: calculada desde [birthDate] si está cargada, si no la
  /// edad manual [age]. Puede ser null si no hay ninguno de los dos datos
  /// (partidos/jugadores guardados antes de este campo).
  int? get effectiveAge =>
      birthDate != null ? calculateAge(birthDate!) : age;

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'number': number,
        'position': position.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'dominantHand': dominantHand?.name,
        'blockReachCm': blockReachCm,
        'attackReachCm': attackReachCm,
        'birthDate': birthDate?.toIso8601String(),
        'age': age,
      };

  factory Player.fromJson(Map<dynamic, dynamic> json) => Player(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        position: PlayerPosition.values.firstWhere(
          (e) => e.name == json['position'],
          orElse: () => PlayerPosition.puntaReceptor,
        ),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        dominantHand: json['dominantHand'] == null
            ? null
            : DominantHand.values.firstWhere(
                (e) => e.name == json['dominantHand'],
                orElse: () => DominantHand.derecha,
              ),
        blockReachCm: (json['blockReachCm'] as num?)?.toDouble(),
        attackReachCm: (json['attackReachCm'] as num?)?.toDouble(),
        birthDate: json['birthDate'] == null
            ? null
            : DateTime.tryParse(json['birthDate'] as String),
        age: (json['age'] as num?)?.toInt(),
      );

  Player copyWith({
    String? firstName,
    String? lastName,
    int? number,
    PlayerPosition? position,
    double? heightCm,
    double? weightKg,
    DominantHand? dominantHand,
    double? blockReachCm,
    double? attackReachCm,
    DateTime? birthDate,
    int? age,
    bool clearHeight = false,
    bool clearWeight = false,
    bool clearHand = false,
    bool clearBlockReach = false,
    bool clearAttackReach = false,
    bool clearBirthDate = false,
  }) {
    return Player(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      number: number ?? this.number,
      position: position ?? this.position,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      dominantHand: clearHand ? null : (dominantHand ?? this.dominantHand),
      blockReachCm: clearBlockReach ? null : (blockReachCm ?? this.blockReachCm),
      attackReachCm: clearAttackReach ? null : (attackReachCm ?? this.attackReachCm),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      age: age ?? this.age,
    );
  }
}
