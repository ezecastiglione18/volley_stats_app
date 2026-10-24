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
/// con las restricciones puntuales de la versión gratuita (pizarra, zona de
/// destino, estadística limitada a un partido, tope de partidos guardados)
/// — no hay un bloqueo total de la app en ningún caso.
class SubscriptionController extends ChangeNotifier {
  bool isLoading = true;
  bool isPremium = false;
  int deviceLimit = 1;

  /// Cuenta a la que corresponde el estado en memoria (la de la caché que
  /// se leyó, o la del último [refresh]).
  String? _uid;

  /// Sólo lee la última caché guardada en Hive (rápido, sin red), para no
  /// frenar el arranque de la app con una llamada de red a RevenueCat. Se
  /// llama una vez al arrancar, antes de runApp, igual que
  /// ThemeController.load(), con el [uid] de la sesión ya abierta si hay
  /// una (la caché es por cuenta).
  Future<void> init({String? uid}) async {
    if (uid != null) loadCachedFor(uid);
  }

  /// Toma la caché de [uid] (al loguearse, ver `_AccountDataGate` en
  /// `main.dart`). Es por cuenta: si se cambia de cuenta sin red, la nueva
  /// no arranca con el premium cacheado de la anterior.
  void loadCachedFor(String uid) {
    _readCache(uid);
    notifyListeners();
  }

  void _readCache(String uid) {
    _uid = uid;
    final cache = StorageService.instance.loadSubscriptionCache(uid);
    isPremium = cache?['isPremium'] as bool? ?? false;
    deviceLimit = cache?['deviceLimit'] as int? ?? 1;
  }

  /// Al cerrar sesión: vuelve al estado de recién creado, para que nada de
  /// la cuenta anterior se use hasta que la próxima lea su propia caché.
  void reset() {
    _uid = null;
    isLoading = true;
    isPremium = false;
    deviceLimit = 1;
    notifyListeners();
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
      // `refresh()` se llama desde `initState()` (ver `_SubscriptionGateState`
      // en main.dart): sin este `await` antes de notifyListeners(), esta rama
      // (sin operación async real de por medio) notifica de forma síncrona
      // mientras Flutter todavía está construyendo un widget ancestro más
      // arriba en el mismo frame, lo que dispara "setState()/markNeedsBuild()
      // called during build" y tira abajo toda la app. Encolarlo como
      // microtask alcanza para salir del frame de build actual.
      await Future<void>.delayed(Duration.zero);
      notifyListeners();
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    // Sin notificar: `refresh` puede llamarse desde un initState.
    if (uid != _uid) _readCache(uid);
    try {
      await Purchases.logIn(uid);
    } catch (_) {
      // Defensivo: no bloquear el refresh si logIn falla (ej. ya logueado).
    }

    try {
      final info = await Purchases.getCustomerInfo();
      // Si mientras tanto se cerró la sesión o entró otra cuenta, esta
      // respuesta ya no es de la cuenta actual: no se aplica ni se cachea.
      if (_uid != uid) return;
      await _applyCustomerInfoAndCache(info, uid);
    } catch (_) {
      // Offline / RevenueCat inalcanzable: se mantiene lo que había en
      // caché (cargado en loadCachedFor()). Es la única ventana de
      // tolerancia a datos viejos — si RevenueCat sí responde y dice
      // "inactiva", eso se aplica de inmediato, sin período de gracia propio.
    }
    if (_uid != uid) return;

    isLoading = false;
    notifyListeners();
  }

  /// Aplica un [CustomerInfo] ya obtenido (por ejemplo, el que devuelve
  /// `Purchases.purchase(...)` al comprar un complemento de dispositivo) sin
  /// tener que hacer otra consulta de red a `getCustomerInfo()`.
  void applyCustomerInfo(CustomerInfo info) {
    final uid = _uid ?? AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    _applyCustomerInfoAndCache(info, uid);
    notifyListeners();
  }

  Future<void> _applyCustomerInfoAndCache(CustomerInfo info, String uid) async {
    isPremium = info.entitlements.active[kPremiumEntitlementId] != null;
    deviceLimit = deviceLimitFrom(
      activeSubscriptions: info.activeSubscriptions,
      activeEntitlementIds: info.entitlements.active.keys,
    );
    await StorageService.instance.saveSubscriptionCache(uid, {
      'isPremium': isPremium,
      'deviceLimit': deviceLimit,
    });
  }
}
