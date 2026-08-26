import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../state/subscription_controller.dart';
import 'subscription_tiers.dart';

/// Resultado de intentar comprar un producto puntual por id.
enum PurchaseOutcome {
  /// Se compró y ya se refleja en [SubscriptionController].
  purchased,

  /// El usuario canceló el diálogo de pago — no es un error, no hace falta
  /// mostrar ningún mensaje.
  cancelled,

  /// El producto no está configurado en RevenueCat/Play Console todavía.
  productNotFound,

  /// Cualquier otro error (red, Play Billing, etc.).
  error,
}

/// Resultado de intentar restaurar compras previas de la cuenta.
enum RestoreOutcome {
  /// Se encontró una suscripción activa y ya se refleja en
  /// [SubscriptionController].
  restored,

  /// La restauración se hizo bien, pero esta cuenta no tiene ninguna
  /// suscripción activa (no es un error).
  notFound,

  /// Error de red/Play Billing al restaurar.
  error,
}

/// Compra un producto de RevenueCat directamente por su product id (no por
/// Offering/Package), para no depender de cómo esté organizado en el
/// dashboard — sólo hace falta que el producto exista en el catálogo.
/// Actualiza [SubscriptionController] al toque si la compra sale bien.
Future<PurchaseOutcome> purchaseProductById(BuildContext context, String productId) async {
  try {
    final products = await Purchases.getProducts([productId]);
    if (products.isEmpty) return PurchaseOutcome.productNotFound;

    final result = await Purchases.purchase(PurchaseParams.storeProduct(products.first));
    if (context.mounted) {
      context.read<SubscriptionController>().applyCustomerInfo(result.customerInfo);
    }
    return PurchaseOutcome.purchased;
  } on PlatformException catch (e) {
    if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) {
      return PurchaseOutcome.cancelled;
    }
    return PurchaseOutcome.error;
  } catch (_) {
    return PurchaseOutcome.error;
  }
}

/// Restaura las compras ya hechas por esta cuenta en Play Store (requisito
/// de Google Play: sección 12 de la propuesta de suscripción) — necesario
/// para cuando alguien reinstala la app o inicia sesión en otro dispositivo
/// y RevenueCat todavía no vinculó esa instalación con su compra existente.
/// Actualiza [SubscriptionController] al toque si encuentra algo.
Future<RestoreOutcome> restorePurchases(BuildContext context) async {
  try {
    final info = await Purchases.restorePurchases();
    if (context.mounted) {
      context.read<SubscriptionController>().applyCustomerInfo(info);
    }
    return info.entitlements.active[kPremiumEntitlementId] != null
        ? RestoreOutcome.restored
        : RestoreOutcome.notFound;
  } catch (_) {
    return RestoreOutcome.error;
  }
}
