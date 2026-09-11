import 'package:flutter/material.dart';

import '../../legal/privacy_policy_text.dart';
import '../../legal/terms_conditions_text.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/legal_document_dialog.dart';
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
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Política de Privacidad'),
                    onTap: () => showLegalDocumentDialog(
                      context: context,
                      title: 'Política de Privacidad',
                      subtitle:
                          'Vigente desde $kPrivacyPolicyEffectiveDate · Versión $kPrivacyPolicyVersion',
                      sections: privacyPolicySections,
                      showAcceptButton: false,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Términos y Condiciones'),
                    onTap: () => showLegalDocumentDialog(
                      context: context,
                      title: 'Términos y Condiciones',
                      subtitle: 'Vigente desde $kTermsEffectiveDate · Versión $kTermsVersion',
                      sections: termsConditionsSections,
                      showAcceptButton: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
