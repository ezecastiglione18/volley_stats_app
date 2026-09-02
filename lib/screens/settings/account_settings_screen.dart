import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/sign_out_confirmation.dart';

/// Configuración de la cuenta: cerrar sesión y eliminar cuenta. Antes eran
/// dos íconos sueltos en el encabezado de Inicio; se juntaron acá para no
/// competir con los accesos principales y para dejar lugar a más opciones
/// de cuenta en el futuro sin volver a amontonar el encabezado.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (email != null) ...[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: const Text('Cuenta'),
                  subtitle: Text(email),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                subtitle: const Text('Libera este dispositivo para poder usar la cuenta en otro'),
                onTap: () => confirmAndSignOut(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.person_remove_outlined, color: errorColor(context)),
                title: Text('Eliminar cuenta', style: TextStyle(color: errorColor(context))),
                subtitle: const Text('Borra la cuenta de forma permanente'),
                onTap: () => confirmAndDeleteAccount(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
