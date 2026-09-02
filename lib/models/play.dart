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

/// Un fichín (marcador de jugador) apoyado sobre la cancha de la pizarra:
/// representa un puesto (A/P/C/O/L) en una posición normalizada (0.0–1.0)
/// para independizarse del tamaño de pantalla, igual que [PlayStroke].
/// [tokenId] identifica cuál de los fichines fijos del set (ver
/// `_kTokenCatalog` en `WhiteboardScreen`) es, para poder devolverlo a la
/// bandeja de disponibles al borrarlo de la cancha.
class PlacedToken {
  final String tokenId;
  final String label;
  final int colorValue;
  final double x;
  final double y;

  const PlacedToken({
    required this.tokenId,
    required this.label,
    required this.colorValue,
    required this.x,
    required this.y,
  });

  PlacedToken copyWith({double? x, double? y}) => PlacedToken(
        tokenId: tokenId,
        label: label,
        colorValue: colorValue,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'label': label,
        'colorValue': colorValue,
        'x': x,
        'y': y,
      };

  factory PlacedToken.fromJson(Map<dynamic, dynamic> json) {
    return PlacedToken(
      tokenId: json['tokenId'] as String,
      label: json['label'] as String,
      colorValue: json['colorValue'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
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
  final List<PlacedToken> tokens;

  const Play({
    required this.id,
    required this.name,
    required this.date,
    required this.strokes,
    this.tokens = const [],
  });

  Play copyWith({String? name, List<PlayStroke>? strokes, List<PlacedToken>? tokens}) {
    return Play(
      id: id,
      name: name ?? this.name,
      date: date,
      strokes: strokes ?? this.strokes,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'tokens': tokens.map((t) => t.toJson()).toList(),
      };

  factory Play.fromJson(Map<dynamic, dynamic> json) {
    return Play(
      id: json['id'] as String,
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      strokes: (json['strokes'] as List)
          .map((s) => PlayStroke.fromJson(Map<dynamic, dynamic>.from(s as Map)))
          .toList(),
      // Jugadas guardadas antes de agregar los fichines no tienen esta clave.
      tokens: (json['tokens'] as List?)
              ?.map((t) => PlacedToken.fromJson(Map<dynamic, dynamic>.from(t as Map)))
              .toList() ??
          const [],
    );
  }
}
