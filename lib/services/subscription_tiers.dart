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

/// Cantidad de dispositivos habilitados: 1 (plan base) + un dispositivo más
/// por cada complemento de [kDeviceAddOnProductIds] presente en
/// `activeSubscriptions`. Nunca pasa de 4 porque sólo hay 3 complementos
/// definidos. Si [activeSubscriptions] no reconoce ningún complemento
/// (incluida una lista vacía por error al consultar RevenueCat), devuelve 1
/// — nunca confía en un número más alto sin verificarlo.
int deviceLimitFromActiveSubscriptions(List<String> activeSubscriptions) =>
    1 + activeSubscriptions.where(kDeviceAddOnProductIds.contains).length;

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
