import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/match_sync_service.dart';
import 'services/storage_service.dart';
import 'state/app_data_controller.dart';
import 'state/subscription_controller.dart';
import 'state/theme_controller.dart';
import 'utils/platform_support.dart';
import 'utils/theme.dart';
import 'widgets/cloud_sync_dialogs.dart';

/// API key pública de RevenueCat (proyecto Android de RallyStats). No es un
/// secreto en el sentido tradicional — está pensada para viajar embebida en
/// el cliente, es lo mismo que hace `firebase_options.dart` con la de
/// Firebase.
const _revenueCatApiKey = 'goog_sjVcBJpFjdArStnNfqwNQrhzcZX';

/// Navigator de la app, para poder volver a la primera pantalla desde fuera
/// del árbol de widgets al cerrar la sesión (ver `AuthService.beforeLocalSignOut`).
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La app está pensada para uso vertical (la pantalla en vivo asume ese
  // layout); en desktop esto no tiene efecto (no-op fuera de Android/iOS).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // El login/control de dispositivo único (ver `AuthService`) necesita un
  // proyecto de Firebase configurado (ver `SETUP_FIREBASE.md`). Si todavía
  // no se reemplazó `firebase_options.dart` con los valores reales, esto
  // falla: se lo deja registrado en vez de romper el arranque, y
  // `RallyStatsApp` muestra una pantalla explicando qué falta.
  bool firebaseReady = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    firebaseReady = false;
  }

  // Independiente de Firebase: RevenueCat no necesita `firebaseReady`. En
  // Windows no hay implementación nativa del SDK, así que ni se intenta.
  if (isRevenueCatSupported) {
    try {
      await Purchases.configure(PurchasesConfiguration(_revenueCatApiKey));
    } catch (_) {
      // Si falla, SubscriptionController.init() igual puede resolver algo
      // razonable desde la caché local.
    }
  }

  // Solo `settings_box` (deviceId, tema, preferencias) y la copia previa de
  // los datos: los de la cuenta se abren después del login (`_AccountDataGate`).
  await StorageService.instance.init();
  String? sessionUid;
  if (firebaseReady) {
    sessionUid = FirebaseAuth.instance.currentUser?.uid;
    // Si al actualizar a la versión con datos por cuenta ya había una sesión
    // abierta, esa cuenta es la dueña de los datos de siempre (aunque después
    // no pase la revalidación del dispositivo). Ver `StorageService`.
    if (sessionUid != null) await StorageService.instance.ensureLegacyOwner(sessionUid);
  }

  final appData = AppDataController();
  // Sync de partidos y equipos con la nube (si la cuenta lo activó): se
  // engancha solo a appData (ver AppDataController.sync), que lo dispara.
  final cloudSync = MatchSyncService(appData: appData);
  AuthService.instance.deleteCloudData = (uid) async {
    try {
      await cloudSync.deleteAllRemote(uid);
    } catch (e) {
      // Donde hay sync, sin poder borrar la nube no se borra la cuenta (los
      // datos quedarían huérfanos). En Windows (sin sync) solo se intenta.
      if (cloudSync.supported) rethrow;
      debugPrint('No se pudo borrar la copia de la nube desde esta plataforma: $e');
    }
  };
  final themeController = ThemeController();
  final subscriptionController = SubscriptionController();
  await themeController.load();
  await subscriptionController.init(uid: sessionUid);

  // Cualquier cierre de sesión (manual, cuenta borrada acá o desde otro
  // dispositivo, autoexpulsión): primero se vuelve a la primera ruta, para
  // que no quede abierta ninguna pantalla con datos (la carga en vivo guarda
  // cada acción), y recién después se vacía la memoria y se cierran los
  // cajones. Nada se borra del disco.
  AuthService.instance.beforeLocalSignOut = () async {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    subscriptionController.reset();
    await appData.closeAccount();
  };
  runApp(RallyStatsApp(
    appData: appData,
    themeController: themeController,
    subscriptionController: subscriptionController,
    firebaseReady: firebaseReady,
  ));
}

class RallyStatsApp extends StatelessWidget {
  final AppDataController appData;
  final ThemeController themeController;
  final SubscriptionController subscriptionController;
  final bool firebaseReady;
  const RallyStatsApp({
    super.key,
    required this.appData,
    required this.themeController,
    required this.subscriptionController,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appData),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: subscriptionController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'RallyStats',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: theme.mode,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: firebaseReady ? const _AuthGate() : const _FirebaseNotConfiguredScreen(),
          );
        },
      ),
    );
  }
}

/// Muestra [LoginScreen] hasta que haya una sesión activa (y validada
/// contra el dispositivo, ver `AuthService.revalidateThisDevice`), y
/// [_SubscriptionGate] una vez adentro. También revalida el estado de la
/// suscripción cada vez que la app vuelve a primer plano (alcanza con eso,
/// no hace falta push).
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SubscriptionController>().refresh();
      // No sólo en el arranque en frío: si este dispositivo quedó "de más"
      // por una baja de plan mientras la app estaba en segundo plano (no
      // cerrada del todo), esto lo detecta acá también (ver
      // `AuthService.revalidateThisDevice`). Si termina cerrando la sesión
      // local, `authStateChanges` lo refleja solo, sin necesidad de
      // reaccionar a este Future acá.
      AuthService.instance.revalidateThisDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return FutureBuilder<bool>(
          future: AuthService.instance.revalidateThisDevice(),
          builder: (context, revalidated) {
            if (revalidated.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (revalidated.data == false) {
              // Otro dispositivo tomó la cuenta: se cerró la sesión local
              // recién en `revalidateThisDevice`, así que este StreamBuilder
              // se va a reconstruir solo con `snapshot.data == null`.
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final uid = snapshot.data!.uid;
            return _AccountDataGate(key: ValueKey(uid), uid: uid);
          },
        );
      },
    );
  }
}

/// Abre los datos de la cuenta (equipos, partidos, jugadas, fixture: ver
/// `StorageService.openUserBoxes`) recién con la sesión ya validada, carga
/// la caché de la suscripción de esa cuenta y sincroniza en segundo plano el
/// cupo free de estadística. Hasta que los datos están abiertos no se
/// muestra ninguna pantalla con datos.
class _AccountDataGate extends StatefulWidget {
  final String uid;
  const _AccountDataGate({super.key, required this.uid});

  @override
  State<_AccountDataGate> createState() => _AccountDataGateState();
}

class _AccountDataGateState extends State<_AccountDataGate> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final appData = context.read<AppDataController>();
    final subscription = context.read<SubscriptionController>();
    try {
      await appData.openAccount(widget.uid);
      // La sesión pudo cerrarse mientras se abrían los datos (login
      // rechazado, cuenta borrada desde otro dispositivo): no quedan abiertos
      // para una cuenta que ya no está.
      if (AuthService.instance.currentUser?.uid != widget.uid) {
        await appData.closeAccount();
        return;
      }
      subscription.loadCachedFor(widget.uid);
      appData.syncFreeStatsQuota();
    } catch (e, st) {
      debugPrint('No se pudieron abrir los datos de la cuenta: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataController>();
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron abrir los datos guardados en este dispositivo.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _open();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Mientras se abren, y después de que el cierre de sesión los cerró (el
    // stream de login todavía no avisó), nada de datos en pantalla.
    if (appData.accountUid != widget.uid) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const _SubscriptionGate();
  }
}

/// Revalida la suscripción al entrar (cubre arranque + login recién hecho)
/// contra RevenueCat antes de mostrar [HomeScreen], para que las
/// restricciones puntuales de la versión gratuita (pizarra, zona de destino,
/// estadística limitada a un partido, tope de partidos guardados) usen un
/// [isPremium] fresco y no sólo el último valor cacheado.
class _SubscriptionGate extends StatefulWidget {
  const _SubscriptionGate();

  @override
  State<_SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<_SubscriptionGate> with WidgetsBindingObserver {
  /// Recién acá los cajones de la cuenta ya están abiertos (lo garantiza
  /// `_AccountDataGate`), así que es el lugar del pull y de la subida inicial
  /// pendiente; también al volver a primer plano. Sin await: el sync nunca
  /// demora la pantalla.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<SubscriptionController>().refresh();
    final sync = context.read<AppDataController>().sync;
    if (sync != null && sync.supported) {
      sync.onAccountReady();
      WidgetsBinding.instance.addPostFrameCallback((_) => _askCloudSyncOnce(sync));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppDataController>().sync?.pull();
    }
  }

  /// Aviso único: si la cuenta nunca contestó si quiere la nube (campo
  /// `cloudSync` ausente en `account_devices/{uid}`). Sin red y sin caché no
  /// pregunta: lo hace la próxima vez. Si la nube está activada con un
  /// consentimiento anterior a la política 2.1, muestra en cambio el aviso de
  /// que ahora también viajan jugadas y fixture.
  Future<void> _askCloudSyncOnce(MatchSyncService sync) async {
    final flag = await sync.refreshFlag();
    if (!mounted) return;
    final needsPolicyUpdate = flag == CloudSyncFlag.on && await sync.refreshConsent();
    if ((flag != CloudSyncFlag.unset && !needsPolicyUpdate) || !mounted) return;
    // Que la pantalla de Inicio ya esté (no el indicador de carga).
    while (mounted && context.read<SubscriptionController>().isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    if (flag == CloudSyncFlag.unset) {
      await showCloudSyncPrompt(context, sync);
    } else {
      await showCloudPolicyUpdateNotice(context, sync);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionController>();
    if (subscription.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const HomeScreen();
  }
}

class _FirebaseNotConfiguredScreen extends StatelessWidget {
  const _FirebaseNotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_suggest_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Falta configurar Firebase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Seguí los pasos de SETUP_FIREBASE.md para completar '
                  'lib/firebase_options.dart con los datos del proyecto de '
                  'Firebase antes de poder iniciar sesión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
