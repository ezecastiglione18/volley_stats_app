import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'state/app_data_controller.dart';
import 'state/theme_controller.dart';
import 'utils/theme.dart';

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

  final appData = AppDataController();
  final themeController = ThemeController();
  await appData.loadAll();
  await themeController.load();
  runApp(RallyStatsApp(
    appData: appData,
    themeController: themeController,
    firebaseReady: firebaseReady,
  ));
}

class RallyStatsApp extends StatelessWidget {
  final AppDataController appData;
  final ThemeController themeController;
  final bool firebaseReady;
  const RallyStatsApp({
    super.key,
    required this.appData,
    required this.themeController,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appData),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'RallyStats',
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
/// [HomeScreen] una vez adentro.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

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
            return const HomeScreen();
          },
        );
      },
    );
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
