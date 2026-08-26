import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/paywall_launcher.dart';
import '../state/subscription_controller.dart';

/// Ejecuta [onTap] si la cuenta es premium; si no, abre el paywall en vez
/// de ejecutarlo. Para envolver botones puntuales de funciones premium
/// (pizarra, checkbox de selección de zona).
Future<void> runIfPremium(BuildContext context, VoidCallback onTap) async {
  if (context.read<SubscriptionController>().isPremium) {
    onTap();
    return;
  }
  await showRallyStatsPaywall(context);
}
