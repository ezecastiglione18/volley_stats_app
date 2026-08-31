import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_tiers.dart';
import '../utils/platform_support.dart';

/// Estado de la suscripción premium de la cuenta logueada: si está activa y
/// cuántos dispositivos habilita.
///
/// [isPremium] es el único eje: sin ella, la app sigue siendo usable siempre
/// con las restricciones puntuales de la versión gratuita (pizarra,
/// estadísticas, zona de destino, tope de partidos/sets) — no hay un bloqueo
/// total de la app en ningún caso.
class SubscriptionController extends ChangeNotifier {
  bool isLoading = true;
  bool isPremium = false;
  int deviceLimit = 1;

  /// Sólo lee la última caché guardada en Hive (rápido, sin red), para no
  /// frenar el arranque de la app con una llamada de red a RevenueCat. Se
  /// llama una vez al arrancar, antes de runApp, igual que
  /// ThemeController.load()/AppDataController.loadAll().
  Future<void> init() async {
    final cache = StorageService.instance.loadSubscriptionCache();
    if (cache != null) {
      isPremium = cache['isPremium'] as bool? ?? false;
      deviceLimit = cache['deviceLimit'] as int? ?? 1;
    }
  }

  /// La consulta real contra RevenueCat. Se llama al iniciar sesión, al
  /// volver a primer plano, y después de cerrar el paywall — nunca hace
  /// falta más que eso (revalidar al volver a entrar a la app alcanza).
  Future<void> refresh() async {
    if (!isRevenueCatSupported) {
      // Windows: fuera del esquema de suscripción por ahora, sin
      // restricciones (ver informes de la propuesta de suscripción).
      isPremium = true;
      deviceLimit = 1;
      isLoading = false;
      notifyListeners();
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await Purchases.logIn(uid);
      } catch (_) {
        // Defensivo: no bloquear el refresh si logIn falla (ej. ya logueado).
      }
    }

    try {
      final info = await Purchases.getCustomerInfo();
      await _applyCustomerInfoAndCache(info);
    } catch (_) {
      // Offline / RevenueCat inalcanzable: se mantiene lo que había en
      // caché (cargado en init()). Es la única ventana de tolerancia a
      // datos viejos — si RevenueCat sí responde y dice "inactiva", eso se
      // aplica de inmediato, sin período de gracia propio.
    }

    isLoading = false;
    notifyListeners();
  }

  /// Aplica un [CustomerInfo] ya obtenido (por ejemplo, el que devuelve
  /// `Purchases.purchase(...)` al comprar un complemento de dispositivo) sin
  /// tener que hacer otra consulta de red a `getCustomerInfo()`.
  void applyCustomerInfo(CustomerInfo info) {
    _applyCustomerInfoAndCache(info);
    notifyListeners();
  }

  Future<void> _applyCustomerInfoAndCache(CustomerInfo info) async {
    isPremium = info.entitlements.active[kPremiumEntitlementId] != null;
    deviceLimit = deviceLimitFromActiveSubscriptions(info.activeSubscriptions);
    await StorageService.instance.saveSubscriptionCache({
      'isPremium': isPremium,
      'deviceLimit': deviceLimit,
    });
  }

}
