import 'package:flutter/material.dart';

import '../services/paywall_launcher.dart';

/// Pantalla de reemplazo para cuando se navega a una función premium sin
/// serlo (estadísticas, pizarra) — con AppBar/back, a diferencia de
/// `SubscriptionBlockedScreen` (que reemplaza toda la app).
class PremiumRequiredScreen extends StatelessWidget {
  final String feature;

  const PremiumRequiredScreen({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(feature)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 16),
                Text(
                  '$feature es una función premium',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Suscribite para desbloquearla junto con el resto de las funciones premium.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => showRallyStatsPaywall(context),
                  child: const Text('Ver planes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
