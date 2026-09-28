/// Identificador del entitlement de RevenueCat que representa la
/// suscripción premium activa (Dashboard → Entitlements → "RallyStats Pro").
const String kPremiumEntitlementId = 'rallystats_pro';

/// `applicationId` de Android (debe coincidir con el de
/// `android/app/build.gradle.kts`) — se usa para armar el enlace directo a
/// "Gestionar suscripciones" de Play Store.
const String kAndroidApplicationId = 'com.rallystats.app';

/// Product id (Play Store) del plan base: 1 dispositivo, incluye todas las
/// funciones premium salvo dispositivos adicionales.
const String kBasePremiumProductId = 'premium_mensual:prem';

/// Product ids de los complementos de "dispositivo adicional", **en el
/// orden en que se habilitan**: cada uno es una suscripción independiente y
/// recurrente que se suma al plan base (no reemplaza tiers, no es compra
/// por cantidad: Google Play Billing no permite cantidad > 1 en
/// suscripciones, sólo en consumibles). Se venden de a uno: primero hay que
/// tener el plan base + este complemento activo para que se habilite
/// ofrecer el siguiente.
const List<String> kDeviceAddOnProductIds = [
  'da_mensual:da-men', // Dispositivo Adicional
  'da_mensual_2:da-men-2', // Dispositivo Adicional 2
  'da_mensual_3:da-men-3', // Dispositivo Adicional 3
];

/// Entitlements de RevenueCat equivalentes a cada complemento de
/// [kDeviceAddOnProductIds] (mismo orden). Los otorgan los códigos
/// promocionales (volley_stats_app_backend, `PROMO_ENTITLEMENT_IDS` en
/// revenuecat.ts), que no pasan por Play Billing y por lo tanto nunca
/// aparecen en `activeSubscriptions`. En el dashboard de RevenueCat cada
/// producto de complemento tiene asociado **sólo su propio** entitlement
/// (además de `rallystats_pro`): si se asociaran de forma acumulativa (ej.
/// el complemento 2 activando también `device_addon_1`), quien cancele uno
/// anterior fuera de orden tendría más dispositivos de los que paga.
const List<String> kDeviceAddOnEntitlementIds = [
  'device_addon_1',
  'device_addon_2',
  'device_addon_3',
];

/// Cantidad de dispositivos habilitados: 1 (plan base) + un dispositivo más
/// por cada complemento activo, ya sea comprado (su product id de
/// [kDeviceAddOnProductIds] en [activeSubscriptions]) o regalado por un
/// código (su entitlement de [kDeviceAddOnEntitlementIds] en
/// [activeEntitlementIds]). Cada posición cuenta una sola vez aunque esté
/// activa por las dos vías, así que nunca pasa de 4. Si no reconoce ningún
/// complemento (incluidas listas vacías por error al consultar RevenueCat),
/// devuelve 1 — nunca confía en un número más alto sin verificarlo.
int deviceLimitFrom({
  required List<String> activeSubscriptions,
  required Iterable<String> activeEntitlementIds,
}) {
  var addOns = 0;
  for (var i = 0; i < kDeviceAddOnProductIds.length; i++) {
    if (activeSubscriptions.contains(kDeviceAddOnProductIds[i]) ||
        activeEntitlementIds.contains(kDeviceAddOnEntitlementIds[i])) {
      addOns++;
    }
  }
  return 1 + addOns;
}

/// Próximo complemento a ofrecer para comprar, dado el [deviceLimit] actual
/// (se compran en orden: el complemento habilitado por comprar es siempre
/// el que sigue al último ya activo). `null` si ya se compraron los 3
/// (se alcanzó el máximo de 4 dispositivos) o si todavía no hay plan base
/// activo (`deviceLimit` sería 1 recién al tener el plan base).
String? nextDeviceAddOnProductId(int deviceLimit) {
  final index = deviceLimit - 1;
  if (index < 0 || index >= kDeviceAddOnProductIds.length) return null;
  return kDeviceAddOnProductIds[index];
}
