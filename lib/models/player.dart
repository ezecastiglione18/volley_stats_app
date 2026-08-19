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

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.number,
    required this.position,
    this.heightCm,
    this.weightKg,
    this.dominantHand,
  });

  String get fullName => '$lastName, $firstName';
  String get displayShort => '#$number $lastName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'number': number,
        'position': position.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'dominantHand': dominantHand?.name,
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
      );

  Player copyWith({
    String? firstName,
    String? lastName,
    int? number,
    PlayerPosition? position,
    double? heightCm,
    double? weightKg,
    DominantHand? dominantHand,
    bool clearHeight = false,
    bool clearWeight = false,
    bool clearHand = false,
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
    );
  }
}
