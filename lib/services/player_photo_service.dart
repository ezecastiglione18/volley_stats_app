import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/id_gen.dart';

/// Elige una foto de jugador y la copia al almacenamiento local de la app,
/// para que la ruta guardada en `Player.photoPath` siga siendo válida
/// aunque el archivo original (temporal, en una carpeta compartida, etc.) ya
/// no exista. Usa `file_picker` (no `image_picker`, que no tiene soporte de
/// Windows desktop) igual que ya hace `MatchExportService` para elegir
/// archivos en desktop.
class PlayerPhotoService {
  static Future<String?> pickAndStorePhoto() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || file.path == null) return null;

    final dir = await getApplicationSupportDirectory();
    final photosDir = Directory('${dir.path}/player_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final sourcePath = file.path!;
    final dotIndex = sourcePath.lastIndexOf('.');
    final ext = dotIndex == -1 ? '' : sourcePath.substring(dotIndex);
    final destPath = '${photosDir.path}/${generateId('photo_')}$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
