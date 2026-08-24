# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este proyecto

RallyStats (paquete Dart `rally_stats`) es una app Flutter para anotar en vivo estadísticas de vóley
(saque, recepción, ataque, contraataque, bloqueo, errores) jugada por jugada, aplicando las reglas
oficiales de la FIVB para cambios de jugador y de líbero. Genera reportes en PDF y es 100% offline: todo
se persiste localmente (Hive), sin backend ni cuenta de usuario. Se distribuye como APK (Android) y como
ejecutable de escritorio para Windows.

## Comandos

```bash
flutter pub get              # instalar dependencias
flutter run                  # correr en un dispositivo/emulador conectado
flutter analyze              # linter/analizador estático (usa analysis_options.yaml + flutter_lints)
flutter test                 # correr todos los tests (test/widget_test.dart)
flutter test --plain-name "nombre del test"   # correr un solo testWidgets por su descripción
flutter build apk --release      # generar el APK de Android (build/app/outputs/flutter-apk/)
flutter build windows --release  # generar el ejecutable de Windows (build/windows/x64/runner/Release/)
dart run tool/generate_manual.dart   # regenerar manual_usuario_rallystats.pdf
& "C:\Users\Usuario\AppData\Local\Programs\Inno Setup 6\ISCC.exe" installer\rallystats.iss   # instalador wizard de Windows (requiere el build de Release ya hecho)
```

No hay generación de código (`build_runner`): los modelos usan `toJson`/`fromJson` escritos a mano
a propósito, para no depender de `hive_generator` (ver Arquitectura).

## Arquitectura

**Persistencia (`lib/services/storage_service.dart`)**: `Team` y `VolleyMatch` se guardan en Hive como
`Map<String, dynamic>` planos (vía `toJson()`), no como objetos Hive tipados con `TypeAdapter`. Esto
evita el paso de `build_runner`, a costa de tener que mantener `toJson`/`fromJson` a mano en cada modelo
cuando cambian sus campos. `VolleyMatch.fromJson` incluye migraciones manuales para leer partidos
guardados con versiones anteriores del modelo (ver el comentario sobre `defensiveLiberoId`/
`receptionLiberoId` legacy) — al agregar un campo nuevo a un modelo persistido, seguir ese mismo patrón
en vez de asumir que los partidos ya guardados lo van a tener.

**Modelo de datos, de arriba hacia abajo**: `VolleyMatch` (un partido) contiene `List<MatchSet>` (un set
cada uno), y cada `MatchSet` contiene `List<RallyEvent>` (cada toque/punto cargado) y
`List<SubstitutionEvent>` (cada cambio de jugador). Es un log de eventos append-only: la fuente de
verdad de un set es esa lista de eventos, no un puntaje o una rotación guardados como campo aparte
(`ownScore`/`rivalScore`/`currentOrderOwn` en `MatchSet` son una caché derivada, no la fuente de verdad).

**`MatchController` (`lib/state/match_controller.dart`, ~950 líneas) es el corazón de la app**: una
máquina de estados (`RallyStage`: `serveOwn` → `receiveOwn` → `attackK1Own` → `defending`, más los
puntos rivales) que decide qué botones de acción están habilitados y aplica las reglas de rotación,
cambio de jugador (regular y de líbero, con sus límites y automatismos) y fin de set. Para retomar un
partido en curso (`MatchController.resume`), NO se guarda el estado en vivo directamente: se reconstruye
reproduciendo desde cero el log de `events`/`substitutions` del último set. `undoLast`/`undoLastAction`/
`undoLastSubstitution` funcionan sacando el último evento del log y volviendo a derivar el estado, no
revirtiendo campos sueltos a mano. Cualquier cambio a las reglas del juego (rotación, líbero, cambios)
va en este archivo.

**Estadísticas (`lib/services/stats_engine.dart`)**: recorre el log de `RallyEvent` de uno o todos los
sets y arma un `MatchStats` (una `PlayerStatLine` por jugador + fila de equipo + estadística agregada del
rival). Es puramente derivado del log de eventos, igual que el estado en vivo — no hay contadores que se
actualicen de forma incremental en otro lugar.

**Estado global / UI**: `AppDataController` (equipos + archivo de partidos) y `ThemeController` (modo
claro/oscuro) son `ChangeNotifier` inyectados con `provider` en `main.dart`; `MatchController` se crea
por partido (no es un provider global) y se pasa explícitamente entre las pantallas de `new_match/` y
`live/`. `lib/screens/` está organizado por flujo: `teams/` (alta de equipos/jugadores), `new_match/`
(asistente de armado: rival → planilla de 16 → formación inicial), `live/` (pantalla de carga en vivo y
sus diálogos/widgets) y `matches/` (archivo + resumen/estadísticas).

**Reportes y exportación**: `pdf_report_service.dart` arma el PDF de reporte de un partido (solo
lectura, para compartir/imprimir) a partir de `MatchStats`. `match_export_service.dart` es algo
distinto: exporta el `VolleyMatch.toJson()` completo como archivo `.json` (para pasar el partido —
incluso en curso — a otro dispositivo e importarlo con `pickMatchJson()`); en Android/iOS comparte con
`share_plus`, en desktop usa `file_picker` para elegir dónde guardar.

**Manual de usuario**: `manual_usuario_rallystats.pdf` no tiene fuente editable de otro tipo; se genera
por completo con `tool/generate_manual.dart` (usa `package:pdf`). Los números de página del índice están
escritos a mano ahí mismo (`_pIntroduccion`, `_pFaq`, etc.) porque `package:pdf` no expone en qué página
cayó cada sección durante el mismo armado — después de generar, hay que revisar el PDF resultante
(con la herramienta de lectura de PDF, pidiendo todas las páginas) y corregir esas constantes si algún
contenido corrió de página.

## Proceso de release (después de cargar ajustes nuevos)

Cuando se termina de implementar uno o varios cambios y hay que dejar todo listo para el usuario final,
seguir este orden. No todos los pasos aplican siempre — evaluar cada uno:

1. **¿El cambio afecta algo que ve o hace el usuario?** (una pantalla, una regla del juego, una opción
   nueva, una plataforma nueva, un requisito del sistema). Si es así:
   - Actualizar `tool/generate_manual.dart` (agregar/editar el contenido en la sección que corresponda;
     si el cambio es nuevo del todo, ver si conviene su propia sub-sección, como se hizo con "Exportar /
     Importar un partido" en la sección 11).
   - Regenerar con `dart run tool/generate_manual.dart` y releer el PDF completo (todas las páginas) para
     corregir a mano las constantes de número de página del índice (`_pXxx`) y `_coverTotalPages` si la
     paginación total cambió.
   - Si el cambio también aplica al README (nueva funcionalidad en la lista de "Funcionalidades", nuevo
     requisito de plataforma, nuevo comando de build), actualizar `README.md` en la misma pasada.
2. **Verificar que compila**: `flutter analyze` sin errores nuevos.
3. **Generar el APK**: `flutter build apk --release`. Ver la sección de abajo si falla con
   `Gradle task assembleRelease failed` sin más detalle.
4. **Generar el ejecutable de Windows**: `flutter build windows --release`. Queda en
   `build\windows\x64\runner\Release\` (el `.exe` + varios `.dll` + la carpeta `data\`; hay que
   compartir la carpeta entera, no el `.exe` suelto).
5. **Borrar el .zip anterior del escritorio si ya existe**: antes de armar uno nuevo, revisar si
   `C:\Users\Usuario\Desktop\RallyStats-Windows.zip` existe y, en ese caso, borrarlo (para no dejar dos
   versiones distintas con el mismo nombre dando vueltas y mandar por error la vieja):
   ```powershell
   $zipPath = "C:\Users\Usuario\Desktop\RallyStats-Windows.zip"
   if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
   ```
6. **Armar el .zip para compartir la versión de Windows, guardado en el escritorio**: comprimir toda la
   carpeta `build\windows\x64\runner\Release\` (copiarla a una carpeta con nombre prolijo, p. ej.
   `RallyStats-Windows`, y `Compress-Archive` sobre esa carpeta) directo a
   `C:\Users\Usuario\Desktop\RallyStats-Windows.zip`. No alcanza con zippear solo el `.exe`.
7. **Generar el instalador de Windows (Inno Setup)**: requiere tener instalado Inno Setup 6.3+
   (https://jrsoftware.org/isinfo.php; en esta máquina está instalado vía `winget install
   JRSoftware.InnoSetup`, que lo dejó en `C:\Users\Usuario\AppData\Local\Programs\Inno Setup 6\ISCC.exe`,
   no en Archivos de Programa — si se reinstala con el instalador oficial en vez de winget puede terminar
   en `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`, revisar cuál corresponde). Si cambió `version:` en
   `pubspec.yaml` desde el último release, actualizar a mano `MyAppVersion` en `installer\rallystats.iss`
   para que coincida (no se lee automáticamente de `pubspec.yaml`). Compilar con:
   ```powershell
   & "C:\Users\Usuario\AppData\Local\Programs\Inno Setup 6\ISCC.exe" installer\rallystats.iss
   ```
   Esto empaqueta `build\windows\x64\runner\Release\` (por eso el paso 4 tiene que estar hecho antes) y
   genera `installer\Output\RallyStats-Setup-<version>.exe`: un wizard de instalación autocontenido (no
   necesita el `.zip` ni la carpeta `Release` para funcionar en la máquina de destino). Copiar ese
   instalador al escritorio o subirlo como asset de un GitHub Release para compartirlo — es la vía
   recomendada para el usuario final; el `.zip` del paso 6 sigue sirviendo como alternativa portátil sin
   instalación.

## Particularidades del entorno de build en esta máquina (Windows)

Estos ajustes ya están hechos en el repo/configuración de Flutter de esta máquina; documentados acá para
no volver a perder tiempo re-diagnosticándolos si algo los pisa (una reinstalación de Android Studio, un
`flutter upgrade`, etc.):

- **JDK usado para invocar Gradle**: el JBR embebido en Android Studio de esta máquina
  (`D:\Android\jbr`, un build de OpenJDK 25) crashea con un stack overflow nativo al lanzar el wrapper de
  Gradle 9.3.1, y lo hace en milisegundos y sin ningún mensaje de error (`flutter build apk`/`windows`
  fallan con "Gradle task ... failed with exit code 1" sin más detalle). Está resuelto apuntando Flutter
  al JDK del sistema (Eclipse Temurin 17) con `flutter config --jdk-dir="C:\Program Files\Eclipse
  Adoptium\jdk-17.0.15.6-hotspot"` — es una config global de esta instalación de Flutter, no del repo, así
  que si se reinstala Flutter o se cambia de máquina hay que volver a correrlo. Si un build falla
  instantáneamente y sin salida de Gradle, sospechar primero de esto antes que de un error real de Gradle.
- **`android/build.gradle.kts`**: fuerza `compileSdk = 36` en todos los subproyectos Android de tipo
  librería (`subprojects { afterEvaluate { ... } }`), porque algunos plugins (p. ej. `file_picker`
  8.x) traían un `compileSdk` viejo hardcodeado en su propio `build.gradle`, incompatible con
  `flutter_plugin_android_lifecycle`. Con `file_picker` ya en `^12.0.0` puede que ya no haga falta para
  ese plugin puntual, pero se dejó como red de seguridad general para cualquier otro plugin.
- **`android/gradle.properties`**: `android.builtInKotlin=true` es necesario para que compile
  `share_plus` 13.x (su código Kotlin propio no resuelve si esta flag está en `false`). Si en el futuro
  algún plugin todavía no migrado a Built-in Kotlin rompe el build pidiendo lo contrario, es un conflicto
  real entre plugins, no un capricho de configuración.
