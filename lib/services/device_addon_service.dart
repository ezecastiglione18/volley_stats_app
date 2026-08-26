import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/subscription_controller.dart';
import 'purchase_service.dart';
import 'subscription_tiers.dart';

/// Compra el próximo complemento de dispositivo de la secuencia (ver
/// [nextDeviceAddOnProductId]) para la cuenta logueada.
Future<PurchaseOutcome> purchaseNextDeviceAddOn(BuildContext context) async {
  final controller = context.read<SubscriptionController>();
  final productId = nextDeviceAddOnProductId(controller.deviceLimit);
  if (productId == null) return PurchaseOutcome.error;
  return purchaseProductById(context, productId);
}
