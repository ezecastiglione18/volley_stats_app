# RallyStats

App de estadísticas de vóley — carga en vivo, planillas de equipo y reportes en PDF.

RallyStats permite anotar en tiempo real las estadísticas de un partido de vóley (saque, recepción,
ataque, contraataque, bloqueo y errores, jugada por jugada y jugador por jugador), aplicando las reglas
oficiales de la FIVB para cambios de jugador y de líbero, y genera automáticamente una planilla de
estadísticas exportable como reporte en PDF.

## Funcionalidades

- Carga en vivo del partido, punto por punto, con calificación de cada toque y zona de destino opcional
  (saque, ataque y contraataque), en 6 zonas o en 9 (suma la franja media 7-8-9, elegible set a set).
- Edición de la formación ya comenzada: mientras el set no tenga ninguna acción cargada, "Editar
  formación" vuelve a la pantalla de formación con todo precargado para corregir sexteto, saque, líberos
  u opciones de registro sin tener que cargar el partido de nuevo.
- Rotación manual opcional (se habilita en la configuración del partido): gira al equipo propio un puesto
  hacia adelante o hacia atrás entre punto y punto, para corregir la rotación, y se deshace como cualquier
  otra acción.
- Confirmación explícita de fin de set: al llegar al puntaje de cierre, el set queda pendiente (se puede
  seguir deshaciendo si el árbitro revierte el último punto) hasta confirmarlo con un botón dedicado del
  encabezado, incluido el set decisivo que cierra el partido.
- Planteles de equipo de hasta 35 jugadores, con posición (incluye Universal, además de Armador, Opuesto,
  Central, Punta/Receptor y Líbero), edad (a mano o calculada desde la fecha de nacimiento), datos
  físicos, alcances de bloqueo/ataque y foto, todos opcionales, y una planilla de hasta 16 habilitados por
  partido. Los equipos también admiten datos opcionales del cuerpo técnico (entrenador, asistente,
  auxiliar, médico y preparador físico), y se pueden exportar (plantel, cuerpo técnico y todos sus
  partidos ya jugados) para pasarlos a otro dispositivo e importarlos ahí, conservando la estadística
  acumulada contra cada rival.
- Cambios de jugador según el reglamento oficial de la FIVB (cambio regular y cambio de líbero), con los
  roles de líbero configurables set a set, entrada automática (opcional) del líbero defensor por un
  central que rota al fondo mientras el equipo propio saca, cambios por set ilimitados si se prefiere, y
  opción de deshacer el último cambio o la última jugada cargada por error. Cualquier líbero de la
  planilla puede entrar o intercambiarse con el que está en cancha aunque no tenga un rol asignado en el
  set (Regla 19.3.2 de la FIVB: cambios de líbero ilimitados, con un punto jugado entre dos cambios).
- Carga de sanciones y tarjetas del árbitro (amonestación, tarjeta amarilla, roja, expulsión y
  descalificación) según el reglamento oficial de la FIVB, con el punto o la salida de cancha
  correspondiente aplicados automáticamente y la sustitución obligatoria cuando corresponde.
- Formato de partido configurable (cantidad de sets, puntos por set, cambios permitidos por set, rotación
  manual).
- Estadísticas del partido completo o por set (propias y del rival), con porcentajes de efectividad de
  saque, ataque, contraataque y recepción, y reporte en PDF listo para compartir (incluye desglose por
  jugador, sanciones y zonas de destino de saque, ataque y contraataque).
- Exportar un partido guardado (no solo el PDF) para pasarlo a otro dispositivo e importarlo ahí,
  conservando todos sus datos.
- Archivo histórico de partidos, con retoma automática de un partido en curso donde quedó.
- Scouting de rivales: elegido un equipo propio, arma automáticamente la estadística acumulada contra
  cada rival ya enfrentado (récord, errores más frecuentes del rival y con qué toque suele ganar el
  punto), a partir de los partidos ya guardados en el archivo, sin tener que revisarlos uno por uno.
- Pizarra táctica: cancha dibujable a mano (formaciones, rotaciones, sistemas de ataque/defensa), con
  colores, modo flecha, fichines arrastrables para representar jugadores por puesto (armador, punta/
  receptor, central, opuesto, líbero) y archivo propio de jugadas guardadas, accesible desde la pantalla
  principal, la formación previa al set y la carga en vivo.
- Modo claro y modo oscuro.
- Suscripción premium mensual (Android, vía Google Play Billing/RevenueCat): la versión gratuita permite
  hasta 3 partidos guardados (siempre al mejor de 5 sets), sin pizarra ni zona de destino, y estadística/
  reporte en PDF disponible para un único partido de toda la cuenta —a elección propia, y solo una vez que
  ese partido está guardado y terminado en el archivo, nunca en vivo ni entre sets—, y se puede seguir
  usando así de forma indefinida sin suscribirse; premium quita esos límites y permite sumar hasta 3
  dispositivos adicionales. Incluye restaurar compras y gestión/cancelación desde Google Play, y un link
  "Cómo cancelar sin problemas" con una guía completa sobre en qué orden dar de baja los complementos (ver
  la sección 19 del manual de usuario para el detalle completo).
- "Tengo un código" (Configuración de la cuenta): canjear un código promocional para activar premium sin
  pasar por Google Play Billing — pensado para dar acceso gratuito puntual (ej. a una federación) sin
  otorgarlo a mano por cuenta. Depende del backend en `volley_stats_app_backend` (ver esa sección más
  abajo); todavía no salió en ninguna versión publicada en Play Store.
- En Android, la app se usa solo en orientación vertical.
- Los datos de juego (equipos, jugadores, partidos y jugadas de pizarra) se guardan solo en el
  dispositivo (Hive), sin backend. El inicio de sesión es la excepción: usa Firebase Authentication +
  Firestore para controlar cuántos dispositivos pueden tener la cuenta abierta a la vez (1 por defecto,
  hasta 4 sumando complementos de dispositivo adicional — ver [`SETUP_FIREBASE.md`](SETUP_FIREBASE.md)),
  así que necesita conexión a internet para validarse. Si la cuenta baja de plan con más dispositivos
  conectados de los que el nuevo límite permite, no se cierra ninguna sesión en el momento: se aplica
  recién la próxima vez que cada dispositivo de más abre la app, empezando por el que se conectó más
  recientemente.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) estable (probado con Flutter 3.47 / Dart
  ^3.3).
- Para instalar y correr la app compilada: Android 7.0 (API 24) o superior.

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
flutter test      # tests de widgets y de las reglas de juego de MatchController
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
  models/     # Team, Player, VolleyMatch, MatchSet, RallyEvent, SubstitutionEvent, ManualRotationEvent,
              # MatchConfig, Play
  state/      # MatchController (reglas del juego y estado en vivo), AppDataController, ThemeController,
              # SubscriptionController (estado de la suscripción premium)
  screens/    # pantallas: home, auth, equipos, armado de partido, carga en vivo, resumen, archivo, pizarra,
              # suscripción/paywall, canje de código promocional, configuración de cuenta
  services/   # persistencia local (Hive), estadísticas, reportes en PDF, exportar/importar partidos,
              # auth (Firebase), compras (RevenueCat), canje de código (Cloud Functions)
```

## Login / control de dispositivo único (Firebase)

El inicio de sesión y el bloqueo de "una cuenta, un dispositivo a la vez" necesitan un proyecto de
Firebase propio (Authentication + Firestore). Los pasos para configurarlo están en
[`SETUP_FIREBASE.md`](SETUP_FIREBASE.md).

## Suscripción premium (Google Play Billing vía RevenueCat)

Android usa [RevenueCat](https://app.revenuecat.com) (`purchases_flutter`) para la suscripción premium
mensual (qué queda bloqueado sin ella está detallado en la sección 18 del manual de usuario). Para que las
compras funcionen de verdad hace falta:

- Un producto de suscripción cargado en Play Console con el mismo product id / base plan que
  `kBasePremiumProductId` en [`lib/services/subscription_tiers.dart`](lib/services/subscription_tiers.dart)
  (y los 3 complementos de "dispositivo adicional" de `kDeviceAddOnProductIds`, en ese mismo archivo).
- Un proyecto de RevenueCat conectado a ese Play Console, con un entitlement asociado al producto base
  (identificador `rallystats_pro`, coincide con `kPremiumEntitlementId`). La API key pública de RevenueCat
  va hardcodeada en `lib/main.dart`, igual que la de Firebase.

La versión de Windows queda deliberadamente fuera de este esquema por ahora (no existe Play Billing fuera
de Android): `isRevenueCatSupported` en
[`lib/utils/platform_support.dart`](lib/utils/platform_support.dart) desactiva ahí toda la lógica de
RevenueCat y fuerza `isPremium = true`.

## Códigos promocionales (backend aparte)

"Tengo un código" (`lib/screens/subscription/redeem_code_screen.dart` +
`lib/services/redeem_code_service.dart`) le pega a una Cloud Function (`redeemPromoCode`) del repo
[`volley_stats_app_backend`](https://github.com/ezecastiglione18/volley_stats_app_backend) — un repo
separado, sobre el mismo proyecto de Firebase. Ahí está toda la lógica de validación, el modelo de datos y
cómo generar códigos nuevos. De este lado, dos cosas no obvias si se vuelve a tocar este flujo:

- La función vive en la región `southamerica-east1`, no en la región por defecto de `cloud_functions`
  (`us-central1`) — hay que instanciar `FirebaseFunctions.instanceFor(region: 'southamerica-east1')`, si no
  el llamado no la encuentra.
- Después de un canje exitoso hay que llamar a `Purchases.invalidateCustomerInfoCache()` antes de refrescar
  `SubscriptionController` — el otorgamiento lo hizo la Cloud Function directo contra la API de RevenueCat
  (server-to-server), y a diferencia de una compra hecha con el propio SDK, éste no se entera solo y
  devuelve el `CustomerInfo` viejo en caché si no se invalida a mano primero (comportamiento documentado de
  RevenueCat, no un bug de acá).

## Manual de usuario

El manual completo de uso de la app está en [`manual_usuario_rallystats.pdf`](manual_usuario_rallystats.pdf).
Se genera con el script [`tool/generate_manual.dart`](tool/generate_manual.dart) (`dart run
tool/generate_manual.dart`), así que se puede volver a producir o actualizar sin depender de una
herramienta externa.

## Contacto

Consultas, reportes de problemas o sugerencias: ecastiglione@frba.utn.edu.ar - federperez@frba.utn.edu.ar