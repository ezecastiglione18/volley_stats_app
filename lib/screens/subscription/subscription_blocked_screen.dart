import 'package:flutter/material.dart';

import '../../services/paywall_launcher.dart';
import '../../widgets/restore_purchases_button.dart';
import '../../widgets/sign_out_confirmation.dart';

/// Reemplaza toda la app cuando la cuenta no tiene premium activo y ya
/// venció el período de prueba de 7 días — sin AppBar/back, porque no hay
/// nada a lo que volver (a diferencia de `PremiumRequiredScreen`, que
/// bloquea sólo una función puntual).
class SubscriptionBlockedScreen extends StatelessWidget {
  const SubscriptionBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 16),
                const Text(
                  'Tu período de prueba terminó',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Suscribite a RallyStats Premium para seguir usando la app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => showRallyStatsPaywall(context),
                  child: const Text('Ver planes'),
                ),
                const RestorePurchasesButton(),
                TextButton(
                  onPressed: () => confirmAndSignOut(context),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
