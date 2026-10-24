import '../models/fixture_entry.dart';
import '../models/play.dart';
import '../models/team.dart';
import '../models/volley_match.dart';

/// Valor de `format` de una copia completa.
const kFullBackupFormat = 'rallystats_backup';

/// Versión del formato que escribe y entiende esta versión de la app.
const kFullBackupVersion = 1;

/// El archivo elegido no es una copia completa que esta versión pueda leer.
class FullBackupFormatException implements Exception {
  final String message;
  FullBackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Copia completa de los datos de una cuenta: equipos, partidos, jugadas y
/// fixture. Es el formato de la copia previa automática
/// (`StorageService`), de "Exportar todo" y de "Importar copia completa" /
/// "Restaurar copia automática" (`FullBackupService`,
/// `AppDataController.importBackup`):
///
/// ```json
/// {"format": "rallystats_backup", "version": 1, "createdAt": "<ISO-8601>",
///  "appVersion": "1.2.0+16", "teams": [...], "matches": [...],
///  "plays": [...], "fixture": [...]}
/// ```
///
/// Cada elemento es el `toJson()` de su modelo. Las fotos de los jugadores no
/// viajan (solo la ruta local, que en otro dispositivo no existe).
class FullBackup {
  final List<Team> teams;
  final List<VolleyMatch> matches;
  final List<Play> plays;
  final List<FixtureEntry> fixture;
  final DateTime? createdAt;
  final String? appVersion;

  FullBackup({
    required this.teams,
    required this.matches,
    required this.plays,
    required this.fixture,
    this.createdAt,
    this.appVersion,
  });

  static Map<String, dynamic> buildJson({
    required List<Team> teams,
    required List<VolleyMatch> matches,
    required List<Play> plays,
    required List<FixtureEntry> fixture,
    required DateTime createdAt,
    required String appVersion,
  }) =>
      {
        'format': kFullBackupFormat,
        'version': kFullBackupVersion,
        'createdAt': createdAt.toIso8601String(),
        'appVersion': appVersion,
        'teams': [for (final t in teams) t.toJson()],
        'matches': [for (final m in matches) m.toJson()],
        'plays': [for (final p in plays) p.toJson()],
        'fixture': [for (final f in fixture) f.toJson()],
      };

  /// Lee una copia completa. Rechaza otro `format` y una `version` mayor a
  /// la que entiende esta versión de la app (una copia hecha con una versión
  /// más nueva podría traer campos que acá se perderían).
  factory FullBackup.parse(Object? json) {
    if (json is! Map) {
      throw FullBackupFormatException('El archivo no es una copia completa de RallyStats.');
    }
    if (json['format'] != kFullBackupFormat) {
      throw FullBackupFormatException(
          'El archivo no es una copia completa de RallyStats (si es un partido suelto, '
          'importalo desde el archivo de partidos).');
    }
    final version = json['version'];
    if (version is! int || version < 1) {
      throw FullBackupFormatException('La copia no tiene una versión válida.');
    }
    if (version > kFullBackupVersion) {
      throw FullBackupFormatException(
          'La copia se hizo con una versión más nueva de RallyStats. Actualizá la app para '
          'poder importarla.');
    }
    List<Map<dynamic, dynamic>> list(String key) {
      final raw = json[key];
      if (raw == null) return const [];
      if (raw is! List) throw FullBackupFormatException('La copia está dañada ("$key").');
      return [for (final e in raw) Map<dynamic, dynamic>.from(e as Map)];
    }

    try {
      return FullBackup(
        teams: list('teams').map(Team.fromJson).toList(),
        matches: list('matches').map(VolleyMatch.fromJson).toList(),
        plays: list('plays').map(Play.fromJson).toList(),
        fixture: list('fixture').map(FixtureEntry.fromJson).toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        appVersion: json['appVersion'] as String?,
      );
    } on FullBackupFormatException {
      rethrow;
    } catch (e) {
      throw FullBackupFormatException('La copia está dañada y no se pudo leer ($e).');
    }
  }
}

/// Resultado de importar una copia completa.
class ImportSummary {
  int teams = 0;
  int matches = 0;
  int plays = 0;
  int fixture = 0;

  /// Partidos que no entraron por el tope de 3 de la versión free.
  int matchesSkippedByCap = 0;

  /// Elementos (de cualquier tipo) que ya existían con el mismo id: no se
  /// tocan.
  int alreadyExisted = 0;

  int get imported => teams + matches + plays + fixture;

  /// "Se importaron X; Y quedaron afuera por el tope; Z ya existían".
  String describe() {
    final parts = <String>[];
    final detail = [
      if (teams > 0) '$teams ${teams == 1 ? 'equipo' : 'equipos'}',
      if (matches > 0) '$matches ${matches == 1 ? 'partido' : 'partidos'}',
      if (plays > 0) '$plays ${plays == 1 ? 'jugada' : 'jugadas'}',
      if (fixture > 0) '$fixture ${fixture == 1 ? 'fila del fixture' : 'filas del fixture'}',
    ];
    parts.add(imported == 0
        ? 'No se importó nada nuevo'
        : 'Se ${imported == 1 ? 'importó' : 'importaron'} $imported (${detail.join(', ')})');
    if (matchesSkippedByCap > 0) {
      parts.add('$matchesSkippedByCap ${matchesSkippedByCap == 1 ? 'partido quedó' : 'partidos quedaron'} '
          'afuera por el tope de 3 partidos de la versión free');
    }
    if (alreadyExisted > 0) {
      parts.add('$alreadyExisted ya ${alreadyExisted == 1 ? 'existía' : 'existían'}');
    }
    return '${parts.join('; ')}.';
  }
}
