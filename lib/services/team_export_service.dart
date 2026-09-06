import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/team.dart';
import '../models/volley_match.dart';

/// Marca de un archivo generado por [TeamExportService.exportTeam], para
/// poder distinguirlo de un JSON de partido (`MatchExportService`) o de
/// cualquier otro archivo al momento de importar.
const _kTeamExportKind = 'rally_stats_team_export';

/// Se lanza cuando el archivo elegido para importar no tiene la forma de un
/// equipo exportado por RallyStats (JSON inválido, de otro tipo de archivo,
/// o le faltan los datos mínimos de un equipo).
class TeamImportException implements Exception {
  final String message;
  TeamImportException(this.message);

  @override
  String toString() => message;
}

/// Exporta/importa un equipo (nombre, jugadores, cuerpo técnico) junto con
/// todos los partidos jugados por él (`VolleyMatch.ownTeamSourceId ==
/// team.id`), para pasarlo de un dispositivo a otro sin perder la
/// estadística acumulada contra cada rival. Esa estadística (ver
/// `ScoutingEngine`) se recalcula siempre releyendo el archivo de partidos,
/// no hay ningún número acumulado guardado aparte — alcanza con llevarse los
/// partidos para que, del otro lado, quede la misma estadística, y para que
/// un partido nuevo contra ese mismo rival se sume solo a la acumulada.
class TeamExportService {
  static Future<void> exportTeam(Team team, List<VolleyMatch> allMatches) async {
    final teamMatches = allMatches.where((m) => m.ownTeamSourceId == team.id).toList();
    final bundle = {
      'kind': _kTeamExportKind,
      'version': 1,
      'team': team.toJson(),
      'matches': teamMatches.map((m) => m.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
    final fileName = _fileName(team);

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Equipo: ${team.name}',
        ),
      );
      return;
    }

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Guardar equipo',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(jsonStr)),
    );
    // En Windows/Linux, saveFile ya escribe el archivo con los bytes
    // provistos. En macOS solo devuelve la ruta elegida, hay que escribirlo.
    if (savedUri != null && savedUri.scheme == 'file') {
      final savedFile = File(savedUri.toFilePath());
      if (!await savedFile.exists()) {
        await savedFile.writeAsString(jsonStr);
      }
    }
  }

  /// Abre un selector de archivos y devuelve el bundle decodificado
  /// (`{'team': ..., 'matches': [...]}`), o null si el usuario canceló.
  /// Lanza [TeamImportException] con un mensaje para mostrarle al usuario si
  /// el archivo no se puede leer, no es JSON válido, o no tiene la forma de
  /// un equipo exportado por RallyStats.
  static Future<Map<String, dynamic>?> pickTeamJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null || file.path == null) return null;

    final String content;
    try {
      content = await File(file.path!).readAsString();
    } catch (_) {
      throw TeamImportException('No se pudo leer el archivo elegido.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw TeamImportException('El archivo elegido no es un JSON válido.');
    }

    if (decoded is! Map<String, dynamic> || decoded['kind'] != _kTeamExportKind) {
      throw TeamImportException('El archivo elegido no es un equipo exportado por RallyStats.');
    }

    final teamJson = decoded['team'];
    if (teamJson is! Map || ((teamJson['name'] as String?) ?? '').trim().isEmpty) {
      throw TeamImportException('El archivo no tiene los datos mínimos de un equipo (falta el nombre).');
    }

    return decoded;
  }

  static String _fileName(Team team) {
    final safeName = team.name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'equipo_$safeName.json';
  }
}
