# RallyStats

App de estadísticas de vóley — carga en vivo, planillas de equipo y reportes en PDF.

RallyStats permite anotar en tiempo real las estadísticas de un partido de vóley (saque, recepción,
ataque, contraataque, bloqueo y errores, jugada por jugada y jugador por jugador), aplicando las reglas
oficiales de la FIVB para cambios de jugador y de líbero, y genera automáticamente una planilla de
estadísticas exportable como reporte en PDF.

## Funcionalidades

- Carga en vivo del partido, punto por punto, con calificación de cada toque y zona de destino opcional
  (saque, ataque y contraataque).
- Confirmación explícita de fin de set: al llegar al puntaje de cierre, el set queda pendiente (se puede
  seguir deshaciendo si el árbitro revierte el último punto) hasta confirmarlo con un botón dedicado del
  encabezado, incluido el set decisivo que cierra el partido.
- Planteles de equipo de hasta 35 jugadores, con posición (incluye Universal, además de Armador, Opuesto,
  Central, Punta/Receptor y Líbero), edad (a mano o calculada desde la fecha de nacimiento), datos
  físicos, alcances de bloqueo/ataque y foto, todos opcionales, y una planilla de hasta 16 habilitados por
  partido. Los equipos también admiten datos opcionales del cuerpo técnico (entrenador, asistente,
  auxiliar, médico y preparador físico).
- Cambios de jugador según el reglamento oficial de la FIVB (cambio regular y cambio de líbero), con los
  roles de líbero configurables set a set, entrada automática (opcional) del líbero defensor por un
  central que rota al fondo mientras el equipo propio saca, cambios por set ilimitados si se prefiere, y
  opción de deshacer el último cambio o la última jugada cargada por error.
- Carga de sanciones y tarjetas del árbitro (amonestación, tarjeta amarilla, roja, expulsión y
  descalificación) según el reglamento oficial de la FIVB, con el punto o la salida de cancha
  correspondiente aplicados automáticamente y la sustitución obligatoria cuando corresponde.
- Formato de partido configurable (cantidad de sets, puntos por set, cambios permitidos por set).
- Estadísticas del partido completo o por set (propias y del rival), con porcentajes de efectividad de
  saque, ataque, contraataque y recepción, y reporte en PDF listo para compartir (incluye desglose por
  jugador, sanciones y zonas de destino de saque, ataque y contraataque).
- Exportar un partido guardado (no solo el PDF) para pasarlo a otro dispositivo e importarlo ahí,
  conservando todos sus datos.
- Archivo histórico de partidos, con retoma automática de un partido en curso donde quedó.
- Pizarra táctica: cancha dibujable a mano (formaciones, rotaciones, sistemas de ataque/defensa), con
  colores, modo flecha y archivo propio de jugadas guardadas, accesible desde la pantalla principal, la
  formación previa al set y la carga en vivo.
- Modo claro y modo oscuro.
- En Android, la app se usa solo en orientación vertical.
- Los datos de juego (equipos, jugadores, partidos y jugadas de pizarra) se guardan solo en el
  dispositivo (Hive), sin backend. El inicio de sesión es la excepción: usa Firebase Authentication +
  Firestore para que una misma cuenta no se pueda usar en dos dispositivos a la vez (ver
  [`SETUP_FIREBASE.md`](SETUP_FIREBASE.md)), así que necesita conexión a internet para validarse.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) estable (probado con Flutter 3.47 / Dart
  ^3.3).
- Para instalar y correr la app compilada: Android 7.0 (API 24) o superior, o Windows 10 de 64 bits o
  superior (incluye Windows 11) para la versión de escritorio.

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

Para generar el APK de Android:

```bash
flutter build apk --release
```

Para generar el ejecutable de Windows (queda en `build\windows\x64\runner\Release\`, junto con los
`.dll` que necesita — hay que compartir esa carpeta entera, no solo el `.exe`):

```bash
flutter build windows --release
```

## Estructura del proyecto

```
lib/
  models/     # Team, Player, VolleyMatch, MatchSet, RallyEvent, SubstitutionEvent, MatchConfig, Play
  state/      # MatchController (reglas del juego y estado en vivo), AppDataController, ThemeController
  screens/    # pantallas: home, auth, equipos, armado de partido, carga en vivo, resumen, archivo, pizarra
  services/   # persistencia local (Hive), estadísticas, reportes en PDF, exportar/importar partidos, auth (Firebase)
```

## Login / control de dispositivo único (Firebase)

El inicio de sesión y el bloqueo de "una cuenta, un dispositivo a la vez" necesitan un proyecto de
Firebase propio (Authentication + Firestore). Los pasos para configurarlo están en
[`SETUP_FIREBASE.md`](SETUP_FIREBASE.md).

## Manual de usuario

El manual completo de uso de la app está en [`manual_usuario_rallystats.pdf`](manual_usuario_rallystats.pdf).
Se genera con el script [`tool/generate_manual.dart`](tool/generate_manual.dart) (`dart run
tool/generate_manual.dart`), así que se puede volver a producir o actualizar sin depender de una
herramienta externa.

## Contacto

Consultas, reportes de problemas o sugerencias: ecastiglione@frba.utn.edu.ar - federperez@frba.utn.edu.ar