import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/app_data_controller.dart';
import 'state/theme_controller.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appData = AppDataController();
  final themeController = ThemeController();
  await appData.loadAll();
  await themeController.load();
  runApp(RallyStatsApp(appData: appData, themeController: themeController));
}

class RallyStatsApp extends StatelessWidget {
  final AppDataController appData;
  final ThemeController themeController;
  const RallyStatsApp({super.key, required this.appData, required this.themeController});

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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
