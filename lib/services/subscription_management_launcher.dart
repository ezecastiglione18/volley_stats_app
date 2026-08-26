import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/platform_support.dart';
import 'subscription_tiers.dart';

/// Abre la pantalla de "Gestionar suscripciones" de Play Store (requisito de
/// Google Play: sección 12 de la propuesta de suscripción — tiene que haber
/// una forma de cancelar accesible desde la app, y Play Billing no expone
/// una API de cliente para cancelar directamente, sólo para comprar).
Future<void> openSubscriptionManagement(BuildContext context) async {
  if (!isRevenueCatSupported) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Gestioná o cancelá la suscripción desde la versión de Android, en Play Store.'),
        ),
      );
    return;
  }

  final uri = Uri.https('play.google.com', '/store/account/subscriptions', {
    'sku': kBasePremiumProductId.split(':').first,
    'package': kAndroidApplicationId,
  });

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Play Store.')),
      );
  }
}
