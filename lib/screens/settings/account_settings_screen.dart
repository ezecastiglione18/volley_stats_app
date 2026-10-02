import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../legal/privacy_policy_text.dart';
import '../../legal/terms_conditions_text.dart';
import '../../services/auth_service.dart';
import '../../state/subscription_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/legal_document_dialog.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/sign_out_confirmation.dart';
import '../subscription/redeem_code_screen.dart';
import 'visual_stats_settings_screen.dart';

/// Configuración de la app y de la cuenta: qué estadística visual se ve en
/// pantalla y en el PDF (premium), códigos promocionales, cerrar sesión y eliminar
/// cuenta. Cerrar sesión y eliminar cuenta antes eran dos íconos sueltos en
/// el encabezado de Inicio; se juntaron acá para no competir con los
/// accesos principales.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  /// Acceso a elegir la estadística visual (función premium): sin premium
  /// muestra un candado y abre el paywall.
  static Widget _visualStatsTile(
    BuildContext context, {
    required bool isPremium,
    required VisualStatsTarget target,
    required IconData icon,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(target.title),
      subtitle: Text(isPremium ? subtitle : 'Premium · $subtitle'),
      trailing: isPremium
          ? const Icon(Icons.chevron_right)
          : Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: () => runIfPremium(
        context,
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VisualStatsSettingsScreen(target: target)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email;
    final isPremium = context.watch<SubscriptionController>().isPremium;
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
              child: Column(
                children: [
                  _visualStatsTile(
                    context,
                    isPremium: isPremium,
                    target: VisualStatsTarget.screen,
                    icon: Icons.insights_outlined,
                    subtitle: 'Qué mapas y gráficos se ven en Estadísticas',
                  ),
                  const Divider(height: 1),
                  _visualStatsTile(
                    context,
                    isPremium: isPremium,
                    target: VisualStatsTarget.pdf,
                    icon: Icons.picture_as_pdf_outlined,
                    subtitle: 'Qué mapas y gráficos se incluyen al compartir un partido',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.redeem_outlined),
                title: const Text('Tengo un código'),
                subtitle: const Text('Canjeá un código promocional para activar premium'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RedeemCodeScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
