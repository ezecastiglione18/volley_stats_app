import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/app_data_controller.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appData = AppDataController();
  await appData.loadAll();
  runApp(VolleyStatsApp(appData: appData));
}

class VolleyStatsApp extends StatelessWidget {
  final AppDataController appData;
  const VolleyStatsApp({super.key, required this.appData});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appData,
      child: MaterialApp(
        title: 'Vóley Stats',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
