// Pruebas de widgets básicas para RallyStats.
//
// Se pueden correr desde la terminal con:
//   flutter test
// o desde VS Code con el botón "Run | Debug" que aparece arriba de cada
// `testWidgets(...)`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rally_stats/screens/home_screen.dart';
import 'package:rally_stats/services/storage_service.dart';
import 'package:rally_stats/state/app_data_controller.dart';
import 'package:rally_stats/state/subscription_controller.dart';
import 'package:rally_stats/state/theme_controller.dart';
import 'package:rally_stats/utils/theme.dart';

void main() {
  // path_provider (usado por Hive para guardar los datos) necesita un
  // plugin nativo que no existe en el entorno de test, así que se lo
  // "engaña" para que use una carpeta temporal en disco. La apertura real
  // de los archivos de Hive se hace acá, en setUpAll: dentro del cuerpo de
  // un testWidgets, el manejo de tiempo simulado de Flutter hace que la
  // espera de E/S real nunca termine (el test queda colgado).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('rally_stats_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    await StorageService.instance.init();
  });

  // Monta HomeScreen directamente (con los mismos providers que arma
  // RallyStatsApp en main.dart), en vez de la app completa: la app real
  // pasa primero por el gate de login (_AuthGate), que necesita una sesión
  // de Firebase Auth real y no se puede simular acá sin un backend de
  // verdad. Estos tests son sobre la UI de HomeScreen en sí, no sobre el
  // login, así que directamente se saltea el gate.
  //
  // Construye con controladores recién creados (sin llamar a
  // loadAll()/load()), que es exactamente el estado con el que abre un
  // usuario nuevo: sin equipos ni partidos guardados, tema claro.
  Widget buildApp(AppDataController appData, ThemeController themeController) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appData),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: SubscriptionController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: theme.mode,
          home: const HomeScreen(),
        ),
      ),
    );
  }

  testWidgets('La pantalla de inicio muestra el título y los accesos principales',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildApp(AppDataController(), ThemeController()));
    await tester.pumpAndSettle();

    expect(find.text('RallyStats'), findsWidgets);
    expect(find.text('Nuevo Partido'), findsOneWidget);
    expect(find.text('Archivo de Partidos'), findsOneWidget);
    expect(find.text('Equipos'), findsWidgets);
  });

  testWidgets('Tocar "Equipos" navega al listado de equipos vacío',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildApp(AppDataController(), ThemeController()));
    await tester.pumpAndSettle();

    // El botón "Equipos" quedó más abajo en la lista de Inicio (hay un
    // encabezado de marca arriba de todo), así que hace falta desplazarlo a
    // la vista antes de poder tocarlo.
    await tester.ensureVisible(find.text('Equipos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipos'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no creaste ningún equipo.\nTocá el botón + para agregar el primero.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'El switch de tema alterna entre modo claro y oscuro, y lo persiste',
      (WidgetTester tester) async {
    final themeController = ThemeController();
    await themeController.load(); // Hive ya está abierto (ver setUpAll), esto solo lee el valor.
    await tester.pumpWidget(buildApp(AppDataController(), themeController));
    await tester.pumpAndSettle();

    expect(themeController.isDark, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(themeController.isDark, isTrue);

    // El cambio se guardó de verdad: un controlador nuevo que carga el
    // valor guardado debe arrancar en modo oscuro.
    final reloaded = ThemeController();
    await reloaded.load();
    expect(reloaded.isDark, isTrue);
  });
}
