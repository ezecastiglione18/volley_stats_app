import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../state/subscription_controller.dart';
import 'auth_service.dart';

/// Resultado de intentar canjear un código promocional (backend en
/// volley_stats_app_backend, función `redeemPromoCode`).
enum RedeemOutcome {
  /// Se otorgó el premium y ya se refleja en [SubscriptionController].
  success,

  /// El código no existe.
  invalidCode,

  /// El código existe pero ya venció.
  expired,

  /// El código existe pero ya se agotó su cupo.
  quotaExceeded,

  /// Esta cuenta ya canjeó este código antes (no se puede dos veces).
  alreadyUsedByAccount,

  /// Red, sesión, o cualquier otro error inesperado.
  networkError,
}

/// La Cloud Function vive en `southamerica-east1`, no en la región por
/// defecto (`us-central1`) — hay que apuntar ahí explícitamente o el
/// llamado no la encuentra.
const String _kFunctionsRegion = 'southamerica-east1';

/// Canjea [code] para la cuenta logueada. Si sale bien, refresca
/// [SubscriptionController] ahí mismo para que `isPremium` prenda sin
/// esperar el próximo login/foreground.
Future<RedeemOutcome> redeemPromoCode(BuildContext context, String code) async {
  final uid = AuthService.instance.currentUser?.uid;
  if (uid == null) return RedeemOutcome.networkError; // no debería pasar: hace falta login

  try {
    final callable = FirebaseFunctions.instanceFor(region: _kFunctionsRegion)
        .httpsCallable('redeemPromoCode');
    final result = await callable.call<Map<String, dynamic>>({
      'code': code.trim().toUpperCase(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);

    if (data['ok'] == true) {
      // El otorgamiento lo hizo la Cloud Function, server-to-server — a
      // diferencia de una compra hecha con el propio SDK, este no se entera
      // solo y devuelve CustomerInfo en caché si no se invalida a mano
      // primero (comportamiento documentado de RevenueCat).
      await Purchases.invalidateCustomerInfoCache();
      if (context.mounted) {
        await context.read<SubscriptionController>().refresh();
      }
      return RedeemOutcome.success;
    }
    return _mapErrorCode(data['error'] as String?);
  } on FirebaseFunctionsException {
    // code: 'unauthenticated', 'unavailable', 'invalid-argument', etc.
    return RedeemOutcome.networkError;
  } catch (_) {
    return RedeemOutcome.networkError;
  }
}

RedeemOutcome _mapErrorCode(String? error) {
  switch (error) {
    case 'invalid_code':
      return RedeemOutcome.invalidCode;
    case 'expired':
      return RedeemOutcome.expired;
    case 'quota_exceeded':
      return RedeemOutcome.quotaExceeded;
    case 'already_used_by_account':
      return RedeemOutcome.alreadyUsedByAccount;
    default:
      return RedeemOutcome.networkError;
  }
}
