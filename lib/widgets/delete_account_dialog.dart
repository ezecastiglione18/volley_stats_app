import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/subscription_management_launcher.dart';
import '../state/subscription_controller.dart';
import '../utils/platform_support.dart';
import 'full_backup_actions.dart';

/// Punto de entrada del botón "Eliminar cuenta" (pantalla de Configuración,
/// ver `AccountSettingsScreen`). Primero confirma
/// (con aviso de suscripción activa si corresponde — ver comentario más
/// abajo) y, si el usuario sigue adelante, pide la contraseña para
/// reautenticar y llama a `AuthService.deleteAccount`. El cierre de sesión
/// que sigue lo maneja solo `_AuthGate` en `main.dart` (reacciona al stream
/// de `authStateChanges`; antes, `AuthService.beforeLocalSignOut` vuelve a la
/// primera ruta y cierra los datos), así que acá no hace falta navegar a
/// ningún lado después de borrar. Antes de confirmar ofrece "Exportar todo": se
/// borran la copia de la nube y los cajones de la cuenta en este dispositivo.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final isPremium = context.read<SubscriptionController>().isPremium;
  // Google Play no exige cancelar una suscripción activa para poder borrar
  // la cuenta, pero sí exige avisarlo con claridad (el cliente tampoco
  // tiene forma de cancelarla del lado nuestro, solo de mandar al usuario a
  // gestionarla en Play Store — ver `openSubscriptionManagement`). Por eso
  // no se bloquea el borrado, solo se avisa.
  final showSubscriptionWarning = isPremium && isRevenueCatSupported;

  final continueDeleting = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción es permanente: se borran tu email, contraseña y los dispositivos '
              'registrados a esta cuenta. No se puede deshacer.',
            ),
            const SizedBox(height: 12),
            const Text(
              'También se borran los partidos y equipos guardados en la nube, y los equipos, '
              'partidos, jugadas y fixture de esta cuenta en este dispositivo. Si los querés pasar '
              'a otra cuenta, exportalos antes y después usá "Importar copia completa" con la otra '
              'cuenta.',
              style: TextStyle(fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => exportAllData(dialogContext),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Exportar todo'),
              ),
            ),
            const Text(
              'Si usás esta cuenta en otros dispositivos, ahí se va a cerrar la sesión y sus datos '
              'dejan de estar accesibles. Si los querés conservar, usá Exportar todo en cada uno '
              'antes de borrar.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (showSubscriptionWarning) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tenés una suscripción premium activa. Eliminar la cuenta NO la cancela: '
                      'Google Play va a seguir cobrándola hasta que la canceles vos mismo.',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => openSubscriptionManagement(dialogContext),
                        child: const Text('Gestionar o cancelar suscripción'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );

  if (continueDeleting != true || !context.mounted) return;
  await _showPasswordAndDelete(context);
}

Future<void> _showPasswordAndDelete(BuildContext context) async {
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  bool obscure = true;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Confirmá tu contraseña'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Para eliminar la cuenta, ingresá tu contraseña actual.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresá tu contraseña' : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: TextStyle(color: Theme.of(dialogContext).colorScheme.error, fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: busy
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await AuthService.instance.deleteAccount(password: passwordController.text);
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    } on FirebaseAuthException catch (e) {
                      // Si el error llegó después de cerrar la sesión local,
                      // este diálogo ya se cerró (se vuelve a la primera ruta).
                      if (!dialogContext.mounted) return;
                      setState(() {
                        busy = false;
                        error = _friendlyDeleteError(e);
                      });
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setState(() {
                        busy = false;
                        error = 'No se pudo eliminar la cuenta. Revisá tu conexión a internet.';
                      });
                    }
                  },
            child: busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Eliminar cuenta'),
          ),
        ],
      ),
    ),
  );
}

String _friendlyDeleteError(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
      return 'Contraseña incorrecta.';
    case 'too-many-requests':
      return 'Demasiados intentos. Probá de nuevo más tarde.';
    default:
      return 'No se pudo eliminar la cuenta (${e.code}).';
  }
}
