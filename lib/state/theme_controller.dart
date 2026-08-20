import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Controla si la app se muestra en modo claro u oscuro.
///
/// El usuario lo elige a mano con el switch que aparece en el AppBar de
/// cada pantalla (no sigue el modo del sistema); la elección se guarda en
/// Hive y se recupera la próxima vez que se abre la app.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Carga el modo guardado. Se llama una vez al arrancar la app, antes de
  /// runApp, igual que AppDataController.loadAll().
  Future<void> load() async {
    await StorageService.instance.init();
    _mode = StorageService.instance.loadThemeMode();
    notifyListeners();
  }

  Future<void> toggle() => setDark(!isDark);

  Future<void> setDark(bool dark) async {
    final newMode = dark ? ThemeMode.dark : ThemeMode.light;
    if (newMode == _mode) return;
    _mode = newMode;
    notifyListeners();
    await StorageService.instance.saveThemeMode(_mode);
  }
}
