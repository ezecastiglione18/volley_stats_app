/// Un trazo dibujado en la pizarra táctica: una línea (o flecha) de un
/// color, guardada como una lista de puntos normalizados (0.0–1.0 sobre el
/// ancho/alto de la cancha) para que se vea igual sin importar el tamaño de
/// pantalla en el que se dibujó o se vuelve a abrir.
class PlayStroke {
  final int colorValue;
  final bool arrow;
  final List<double> pointsX;
  final List<double> pointsY;

  const PlayStroke({
    required this.colorValue,
    required this.arrow,
    required this.pointsX,
    required this.pointsY,
  });

  Map<String, dynamic> toJson() => {
        'colorValue': colorValue,
        'arrow': arrow,
        'pointsX': pointsX,
        'pointsY': pointsY,
      };

  factory PlayStroke.fromJson(Map<dynamic, dynamic> json) {
    return PlayStroke(
      colorValue: json['colorValue'] as int,
      arrow: json['arrow'] as bool? ?? false,
      pointsX: (json['pointsX'] as List).map((e) => (e as num).toDouble()).toList(),
      pointsY: (json['pointsY'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }
}

/// Una jugada guardada en la pizarra táctica: un dibujo sobre la cancha
/// (formaciones, movimientos, sistemas de ataque/defensa) con nombre y
/// fecha, persistido igual que los partidos (ver [StorageService]).
class Play {
  final String id;
  final String name;
  final DateTime date;
  final List<PlayStroke> strokes;

  const Play({
    required this.id,
    required this.name,
    required this.date,
    required this.strokes,
  });

  Play copyWith({String? name, List<PlayStroke>? strokes}) {
    return Play(
      id: id,
      name: name ?? this.name,
      date: date,
      strokes: strokes ?? this.strokes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory Play.fromJson(Map<dynamic, dynamic> json) {
    return Play(
      id: json['id'] as String,
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      strokes: (json['strokes'] as List)
          .map((s) => PlayStroke.fromJson(Map<dynamic, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}
