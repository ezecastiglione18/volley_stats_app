import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Muestra un diálogo de confirmación y, si el usuario acepta, cierra
/// sesión (`AuthService.signOut`). Se usa en todos los puntos de la app
/// donde hay un botón de "Cerrar sesión" (home y pantalla de suscripción
/// bloqueada), para no cerrar sesión por un toque accidental.
Future<void> confirmAndSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que querés cerrar sesión?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await AuthService.instance.signOut();
  }
}
