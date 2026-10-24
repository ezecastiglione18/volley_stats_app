import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../legal/privacy_policy_text.dart';
import '../../legal/terms_conditions_text.dart';
import '../../services/auth_service.dart';
import '../../services/match_sync_service.dart';
import '../../state/app_data_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/cloud_sync_dialogs.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/full_backup_actions.dart';
import '../../widgets/legal_document_dialog.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/sign_out_confirmation.dart';
import '../subscription/redeem_code_screen.dart';
import 'user_manual_screen.dart';
import 'visual_stats_settings_screen.dart';

/// Configuración de la app y de la cuenta: qué estadística visual se ve en
/// pantalla y en el PDF (premium), códigos promocionales, copia completa de los
/// datos (Exportar todo, Importar copia completa, Restaurar copia automática), la
/// nube ("Hacer una copia ahora" incluido), el manual de usuario (premium),
/// cerrar sesión y eliminar cuenta. Cerrar sesión y eliminar cuenta antes eran dos íconos sueltos en
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
    final sync = context.read<AppDataController>().sync;
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
            if (sync != null && sync.supported) ...[
              const SizedBox(height: 16),
              _CloudSyncCard(sync: sync),
            ],
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    dense: true,
                    title: Text('Tus datos en este dispositivo', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Equipos, partidos, jugadas y fixture de esta cuenta'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Exportar todo'),
                    subtitle: const Text('Un archivo con todos tus datos, para guardarlo aparte o pasarlo a otra cuenta'),
                    onTap: () => exportAllData(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Importar copia completa'),
                    subtitle: const Text('Agrega lo que no tengas de un archivo de Exportar todo, sin pisar nada'),
                    onTap: () => importFullBackup(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Restaurar copia automática'),
                    subtitle: const Text('La copia que guardó la app de este dispositivo al actualizarse'),
                    onTap: () => restoreAutoBackup(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Manual de usuario'),
                subtitle: Text(isPremium
                    ? 'Siempre la versión más reciente'
                    : 'Premium · Siempre la versión más reciente'),
                trailing: isPremium
                    ? const Icon(Icons.chevron_right)
                    : Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                onTap: () => runIfPremium(
                  context,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserManualScreen()),
                  ),
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

/// "Partidos y equipos en la nube" (`MatchSyncService`): el interruptor por
/// cuenta, la fecha del último sync, el progreso de la subida inicial y los
/// partidos que no se pudieron subir. No aparece en Windows.
class _CloudSyncCard extends StatelessWidget {
  final MatchSyncService sync;
  const _CloudSyncCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final on = sync.enabled;
        final last = sync.lastSyncAt;
        final oversize = sync.oversizeMatchIds.length;
        final lines = <String>[
          if (!on) 'Apagada: tus partidos y equipos quedan solo en este dispositivo',
          if (on && sync.uploading && sync.uploadTotal > 0)
            'Subiendo ${sync.uploadDone} de ${sync.uploadTotal}'
          else if (on && !sync.initialUploadDone)
            'Subida inicial pendiente: sigue cuando haya conexión',
          if (on)
            last == null
                ? 'Todavía no se sincronizó'
                : 'Último sync: ${DateFormat('dd/MM/yyyy HH:mm').format(last)}',
          if (on && oversize > 0)
            '$oversize ${oversize == 1 ? 'partido no se pudo subir' : 'partidos no se pudieron subir'} '
                '(demasiado grande)',
        ];
        return Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.cloud_outlined),
                title: const Text('Partidos y equipos en la nube'),
                subtitle: Text(lines.join('\n')),
                isThreeLine: lines.length > 1,
                value: on,
                onChanged: (v) => toggleCloudSync(context, sync, v),
              ),
              if (on) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Hacer una copia ahora'),
                  subtitle: const Text('Ya se hace sola; esto vuelve a subir todo en este momento'),
                  enabled: !sync.uploading,
                  trailing: sync.uploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: () => _backupNow(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _backupNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await sync.backupNow();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Copia hecha: tus partidos terminados y equipos están en la nube.'
          : 'No se pudo terminar la copia (revisá tu conexión). Lo que faltó se sube solo cuando vuelva.'),
    ));
  }
}
