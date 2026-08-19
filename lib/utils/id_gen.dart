import 'dart:math';

final _rand = Random();

/// Genera un identificador razonablemente único sin depender de paquetes
/// externos (timestamp + número aleatorio).
String generateId([String prefix = '']) {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final r = _rand.nextInt(4294967296);
  return '$prefix${ts}_$r';
}
