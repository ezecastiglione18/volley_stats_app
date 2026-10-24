import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'full_backup.dart';
import 'storage_service.dart';

/// Archivos de la copia completa (formato de [FullBackup]): "Exportar todo"
/// (se comparte igual que `MatchExportService`: hoja de compartir en
/// Android/iOS, elegir dónde guardar en desktop), "Importar copia completa"
/// (elegir un archivo) y "Restaurar copia automática" (las copias previas de
/// `rallystats_backups/`, a las que en Android el usuario no tiene otra
/// forma de llegar). Lo que se agrega a la cuenta lo decide
/// `AppDataController.importBackup`.
class FullBackupService {
  /// Comparte (o guarda, en desktop) [json] (`AppDataController.buildBackupJson`).
  static Future<void> exportAll(Map<String, dynamic> json) async {
    final jsonStr = jsonEncode(json);
    final fileName = 'rallystats_copia_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Copia completa de RallyStats'),
      );
      return;
    }

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Guardar copia completa',
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

  /// Abre un selector de archivos y devuelve la copia elegida, o `null` si el
  /// usuario canceló. Lanza [FullBackupFormatException] si no es una copia
  /// que esta versión pueda leer.
  static Future<FullBackup?> pickBackup() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null || file.path == null) return null;
    return readBackupFile(File(file.path!));
  }

  static Future<FullBackup> readBackupFile(File file) async {
    final Object? json;
    try {
      json = jsonDecode(await file.readAsString());
    } on FormatException {
      throw FullBackupFormatException('El archivo no es una copia completa de RallyStats.');
    }
    return FullBackup.parse(json);
  }

  /// Copias automáticas de este dispositivo, la más nueva primero.
  static Future<List<File>> listAutoBackups() async {
    final dir = await StorageService.instance.backupsDirectory();
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
