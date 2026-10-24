import 'dart:io';

import 'package:flutter/foundation.dart';

/// `purchases_flutter`/`purchases_ui_flutter` no tienen implementación para
/// Windows ni para Web (envuelven Play Billing/StoreKit de forma nativa) —
/// cualquier llamada a `Purchases.*` ahí rompe. Guardar cada punto de uso con
/// esto en vez de chequear `Platform.isWindows` suelto en cada lugar.
///
/// `kIsWeb` se chequea primero y en cortocircuito: en Web, `dart:io` no
/// tiene una implementación real y leer `Platform.isWindows` ahí tira
/// `Unsupported operation` en vez de devolver `false` — no se puede evaluar
/// esa expresión en absoluto en ese target, aunque este proyecto no se
/// distribuye para Web (sólo APK y ejecutable de Windows).
bool get isRevenueCatSupported => !kIsWeb && !Platform.isWindows;

/// Sync de partidos y equipos con la nube (`MatchSyncService`): solo en
/// Android/iOS. FlutterFire no soporta Windows en producción (el sync en
/// Windows es la etapa W5 de `documents/RallyStats-Windows-Comercial.pdf`):
/// ahí el interruptor no aparece y no se sincroniza nada.
bool get isCloudSyncSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
