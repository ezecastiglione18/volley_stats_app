import 'package:flutter/material.dart';

import '../services/paywall_launcher.dart';

/// Pantalla de reemplazo para cuando se navega a una función premium sin
/// serlo (estadísticas, pizarra).
class PremiumRequiredScreen extends StatelessWidget {
  final String feature;

  /// Texto de abajo del título. Por defecto explica que [feature] es
  /// premium; se puede pisar para un caso más específico (ej. cupo free ya
  /// usado en otro partido).
  final String? message;

  const PremiumRequiredScreen({super.key, required this.feature, this.message});

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
                Text(
                  message ??
                      'Suscribite para desbloquearla junto con el resto de las funciones premium.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
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
