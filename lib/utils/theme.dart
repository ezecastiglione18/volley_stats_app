import 'package:flutter/material.dart';

/// Paleta "neutra/moderna" de la app: grafito + celeste.
///
/// Los colores de marca y de estado (acierto/error/alerta) son los mismos
/// en los dos modos (con una variante levemente más clara para que rindan
/// bien sobre fondo oscuro); el resto de los tokens (fondo, superficie,
/// texto, bordes) tiene una versión para modo claro y otra para modo oscuro.
class AppColors {
  AppColors._();

  // Acento de marca
  static const accentLight = Color(0xFF3DC2EC);
  static const accentDark = Color(0xFF52D2F5);

  // Estados (se usan igual en ambos modos salvo aclaración)
  static const success = Color(0xFF2ECC71);
  static const successDark = Color(0xFF3EE08C);
  static const error = Color(0xFFEF4444);
  static const errorDark = Color(0xFFFF6B6B);
  static const warning = Color(0xFFF5A623);
  static const warningDark = Color(0xFFF5B84D);

  // Modo claro
  static const primaryLight = Color(0xFF1E2A38);
  static const bgLight = Color(0xFFF5F6F8);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFEEF1F4);
  static const textLight = Color(0xFF1B1F24);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const borderLight = Color(0xFFE5E7EB);

  // Modo oscuro
  static const appBarDark = Color(0xFF202B38);
  static const bgDark = Color(0xFF121821);
  static const surfaceDark = Color(0xFF1A222C);
  static const surfaceAltDark = Color(0xFF212B37);
  static const textDark = Color(0xFFE8EAED);
  static const textSecondaryDark = Color(0xFF97A1AC);
  static const borderDark = Color(0xFF2A3542);

  // --- Alias de compatibilidad con el AppColors anterior ---
  // (por si queda alguna referencia vieja dando vueltas; apuntan al modo claro)
  static const primary = primaryLight;
  static const primaryDark = primaryLight;
  static const positive = success;
  static const negative = error;
  static const neutral = textSecondaryLight;
  static const bg = bgLight;
}

/// Devuelve el color de éxito/positivo que corresponde al brillo actual.
Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.successDark : AppColors.success;

/// Devuelve el color de error/negativo que corresponde al brillo actual.
Color errorColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.errorDark : AppColors.error;

/// Devuelve el color de alerta/en curso que corresponde al brillo actual.
Color warningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.warningDark : AppColors.warning;

/// Fondo tenue para chips/inputs/tarjetas secundarias, según el brillo actual.
Color surfaceAltColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceAltDark : AppColors.surfaceAltLight;

ColorScheme _lightColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: AppColors.primaryLight,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primaryLight,
    onPrimary: Colors.white,
    secondary: AppColors.accentLight,
    onSecondary: const Color(0xFF06222B),
    surface: AppColors.surfaceLight,
    onSurface: AppColors.textLight,
    error: AppColors.error,
    onError: Colors.white,
    outline: AppColors.borderLight,
  );
}

ColorScheme _darkColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: AppColors.accentDark,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accentDark,
    onPrimary: const Color(0xFF06222B),
    secondary: AppColors.accentDark,
    onSecondary: const Color(0xFF06222B),
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textDark,
    error: AppColors.errorDark,
    onError: const Color(0xFF3A0A0A),
    outline: AppColors.borderDark,
  );
}

ThemeData buildLightTheme() {
  return _buildTheme(
    colorScheme: _lightColorScheme(),
    scaffoldBg: AppColors.bgLight,
    appBarBg: AppColors.primaryLight,
    surfaceAlt: AppColors.surfaceAltLight,
    textSecondary: AppColors.textSecondaryLight,
    border: AppColors.borderLight,
  );
}

ThemeData buildDarkTheme() {
  return _buildTheme(
    colorScheme: _darkColorScheme(),
    scaffoldBg: AppColors.bgDark,
    appBarBg: AppColors.appBarDark,
    surfaceAlt: AppColors.surfaceAltDark,
    textSecondary: AppColors.textSecondaryDark,
    border: AppColors.borderDark,
  );
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBg,
  required Color appBarBg,
  required Color surfaceAlt,
  required Color textSecondary,
  required Color border,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: colorScheme.brightness,
    scaffoldBackgroundColor: scaffoldBg,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceAlt,
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textSecondary,
      textColor: colorScheme.onSurface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
  );
}
