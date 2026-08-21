import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/volley_match.dart';

/// Exporta/importa un partido individual como archivo JSON (reutilizando
/// VolleyMatch.toJson/fromJson), para poder pasarlo de un dispositivo a
/// otro. En mobile se ofrece la hoja de compartir nativa; en desktop, como
/// no hay un equivalente confiable, se deja elegir dónde guardar el archivo.
class MatchExportService {
  static Future<void> exportMatch(VolleyMatch match) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(match.toJson());
    final fileName = _fileName(match);

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Partido: ${match.ownTeamName} vs ${match.rivalTeamName}',
        ),
      );
      return;
    }

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Guardar partido',
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

  /// Abre un selector de archivos y devuelve el JSON decodificado del
  /// partido elegido, o null si el usuario canceló.
  static Future<Map<String, dynamic>?> pickMatchJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null || file.path == null) return null;
    final content = await File(file.path!).readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  static String _fileName(VolleyMatch match) {
    final d = DateFormat('yyyyMMdd').format(match.date);
    final rival = match.rivalTeamName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'partido_${d}_$rival.json';
  }
}
