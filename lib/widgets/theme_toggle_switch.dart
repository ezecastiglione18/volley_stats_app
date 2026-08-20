import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';

/// Switch tipo "slide" para prender/apagar el modo oscuro a mano. Pensado
/// para ir en los `actions` del AppBar de cualquier pantalla:
///
/// ```dart
/// AppBar(
///   title: const Text('Mi pantalla'),
///   actions: const [ThemeToggleSwitch()],
/// )
/// ```
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isDark = themeController.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            size: 18,
            color: Colors.white,
          ),
          Switch(
            value: isDark,
            onChanged: (v) => context.read<ThemeController>().setDark(v),
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF3DC2EC),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
