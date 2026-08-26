import 'package:flutter/material.dart';

import '../screens/subscription/premium_paywall_screen.dart';
import '../utils/platform_support.dart';

/// Punto único desde el que se dispara el paywall en toda la app — usado
/// tanto por los gates de funcionalidad puntuales como por la pantalla de
/// bloqueo total. Muestra el paywall propio (`PremiumPaywallScreen`, ver ese
/// archivo) en vez del paywall visual de RevenueCat, para poder probar el
/// flujo de compra completo sin depender de la configuración del Paywall
/// Builder en el dashboard.
Future<void> showRallyStatsPaywall(BuildContext context) async {
  if (!isRevenueCatSupported) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Las compras no están disponibles todavía en esta versión de escritorio.'),
        ),
      );
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PremiumPaywallScreen(), fullscreenDialog: true),
  );
}
