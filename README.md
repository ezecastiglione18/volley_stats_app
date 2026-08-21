# RallyStats

App de estadísticas de vóley — carga en vivo, planillas de equipo y reportes en PDF.

RallyStats permite anotar en tiempo real las estadísticas de un partido de vóley (saque, recepción,
ataque, contraataque, bloqueo y errores, jugada por jugada y jugador por jugador), aplicando las reglas
oficiales de la FIVB para cambios de jugador y de líbero, y genera automáticamente una planilla de
estadísticas exportable como reporte en PDF.

## Funcionalidades

- Carga en vivo del partido, punto por punto, con calificación de cada toque y zona de destino opcional.
- Planteles de equipo de hasta 35 jugadores, con una planilla de hasta 14 habilitados por partido.
- Cambios de jugador según el reglamento oficial de la FIVB (cambio regular y cambio de líbero), con los
  roles de líbero configurables set a set y opción de deshacer el último cambio o la última jugada
  cargada por error.
- Formato de partido configurable (cantidad de sets, puntos por set, cambios permitidos por set).
- Estadísticas del partido completo o por set, con reporte en PDF listo para compartir (incluye
  desglose por jugador y zonas de destino de saque y ataque).
- Archivo histórico de partidos, con retoma automática de un partido en curso donde quedó.
- Modo claro y modo oscuro.
- 100% offline: todos los datos (equipos, jugadores y partidos) se guardan solo en el dispositivo, sin
  backend ni cuenta de usuario.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) estable (probado con Flutter 3.47 / Dart
  ^3.3).
- Para instalar y correr la app compilada: Android 7.0 (API 24) o superior.

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

Para generar el APK de instalación:

```bash
flutter build apk
```

## Estructura del proyecto

```
lib/
  models/     # Team, Player, VolleyMatch, MatchSet, RallyEvent, SubstitutionEvent, MatchConfig
  state/      # MatchController (reglas del juego y estado en vivo), AppDataController, ThemeController
  screens/    # pantallas: home, equipos, armado de partido, carga en vivo, resumen y archivo
  services/   # persistencia local (Hive) y generación de reportes en PDF
```

## Manual de usuario

El manual completo de uso de la app está en [`manual_usuario_rallystats.pdf`](manual_usuario_rallystats.pdf).
Se genera con el script [`tool/generate_manual.dart`](tool/generate_manual.dart) (`dart run
tool/generate_manual.dart`), así que se puede volver a producir o actualizar sin depender de una
herramienta externa.

## Contacto

Consultas, reportes de problemas o sugerencias: ezecastiglione18@gmail.com
