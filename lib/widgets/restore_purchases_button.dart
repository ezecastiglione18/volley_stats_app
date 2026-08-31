import 'package:flutter/material.dart';

import '../services/purchase_service.dart';
import '../utils/platform_support.dart';

/// Botón de texto "Restaurar compras" — RevenueCat en Play Store, no hace
/// nada en Windows (ver `isRevenueCatSupported`). Pensado para `SubscriptionScreen`,
/// donde alguien puede llegar sin que la app reconozca todavía su suscripción activa.
class RestorePurchasesButton extends StatefulWidget {
  const RestorePurchasesButton({super.key});

  @override
  State<RestorePurchasesButton> createState() => _RestorePurchasesButtonState();
}

class _RestorePurchasesButtonState extends State<RestorePurchasesButton> {
  bool _restoring = false;

  Future<void> _restore() async {
    if (!isRevenueCatSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las compras no están disponibles todavía en esta versión de escritorio.'),
        ),
      );
      return;
    }

    setState(() => _restoring = true);
    final outcome = await restorePurchases(context);
    if (!mounted) return;
    setState(() => _restoring = false);

    final message = switch (outcome) {
      RestoreOutcome.restored => 'Se restauró tu suscripción premium.',
      RestoreOutcome.notFound => 'No se encontró ninguna compra activa para esta cuenta.',
      RestoreOutcome.error => 'No se pudo restaurar. Probá de nuevo.',
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _restoring ? null : _restore,
      child: _restoring
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Restaurar compras'),
    );
  }
}
