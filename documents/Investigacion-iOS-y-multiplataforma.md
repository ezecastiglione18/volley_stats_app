# Investigación: RallyStats en iOS — y qué hace falta para que el código funcione en iOS, Android y Windows

Issue relacionado: #25 "Investigar implementación para iOS".
Estado del documento: investigación inicial hecha leyendo el código actual del repo (no se compiló ni probó nada para iOS: no hay Mac disponible en este entorno). Todo lo marcado como **[verificar]** son afirmaciones sobre reglas externas (Apple, Google, RevenueCat) que conviene confirmar en la documentación vigente antes de decidir, porque cambian con el tiempo.

---

## 1. Conclusión corta

- **La mayor parte de la app ya es portable a iOS sin reescribir nada**: la lógica de juego, las estadísticas, el scouting, la temporada, el impacto en cancha, la pizarra, los PDF y el guardado local son Dart/Flutter puro.
- **Lo que no es portable "gratis" es todo lo que toca una tienda o un servicio con configuración por plataforma**: suscripciones (RevenueCat/StoreKit), identificación del dispositivo, Firebase (un archivo de configuración por app) y las reglas de revisión de Apple.
- **Tres puntos son de decisión de negocio, no solo de código**: (1) el canje de códigos promocionales, que puede chocar con las reglas de Apple; (2) los product ids de los complementos de dispositivo, que hoy son de Google Play; (3) el costo y el trabajo extra de sostener una tercera plataforma.
- **Sin una Mac no se puede compilar para iOS, pero tampoco hace falta tener una**: existen compilaciones en la nube (ver §6).

---

## 2. Qué hace que un código sea "funcional" en una plataforma

Una app Flutter no es "un código que corre en todos lados" de forma automática. Hay cinco capas, y cada una puede romperse por separado:

| Capa | Qué es | ¿Portable sola? | Ejemplo en RallyStats |
| --- | --- | --- | --- |
| 1. Lógica en Dart puro | Reglas, cálculos, modelos | **Sí, 100%.** Corre igual en Android, iOS y Windows | `StatsEngine`, `ScoutingEngine`, `SeasonEngine`, `ImpactEngine`, `MatchController`, modelos con `toJson` |
| 2. Interfaz Flutter | Widgets, pantallas | **Sí**, pero hay que revisar tamaños y orientación | Pantallas de `lib/screens/`, tema claro/oscuro |
| 3. Plugins con código nativo | Cada plugin trae una implementación distinta por plataforma (Kotlin/Java en Android, Swift/Obj-C en iOS, C++ en Windows) | **No automáticamente.** Funciona solo si el plugin *tiene* implementación para esa plataforma *y* el proyecto nativo está configurado (permisos, claves, entitlements) | `purchases_flutter`, `firebase_*`, `file_picker`, `share_plus`, `printing`, `android_id`, `path_provider` |
| 4. Servicios externos y su configuración | Cuentas y claves que existen **por app / por plataforma** | **No.** Hay que registrar la app en cada servicio | Firebase (un archivo por app), RevenueCat (una clave por tienda), productos de suscripción por tienda |
| 5. Build y distribución | Con qué se compila y cómo se publica | **No.** Cada plataforma tiene su cadena | Android: Gradle + JDK (cualquier SO). Windows: Visual Studio con C++ (solo en Windows). iOS: Xcode (**solo en macOS**) |

**Regla práctica para decidir si algo "ya anda" en otra plataforma:**
1. ¿Es Dart puro? → sí, anda.
2. ¿Usa un plugin? → ¿el plugin soporta esa plataforma? (se ve en su ficha de pub.dev) → ¿hay configuración nativa pendiente (permisos, claves, archivo de configuración)?
3. ¿Depende de un servicio externo? → ¿la app está registrada en ese servicio *para esa plataforma*?
4. ¿Depende de una regla de la tienda? → ¿la cumple?

Una consecuencia importante: **que compile no significa que funcione**. En este proyecto ya pasó algo parecido con Windows: `purchases_flutter` compila pero rompe en tiempo de ejecución, por eso existe `lib/utils/platform_support.dart` (`isRevenueCatSupported`). Ese es el patrón correcto: **un único lugar** que responde "¿esta plataforma soporta X?", en vez de `Platform.isWindows` sueltos por todo el código.

---

## 3. Estado actual por plataforma (lo que dice el código hoy)

| Aspecto | Android | Windows | iOS (hoy) |
| --- | --- | --- | --- |
| Se distribuye | Sí (Play Store) | Sí (instalador / zip) | **No** |
| Carpeta de plataforma | `android/` configurada, `applicationId = com.rallystats.app` | `windows/` | `ios/` existe pero es la **plantilla por defecto** de Flutter |
| Identificador de app | `com.rallystats.app` | — | `com.example.volleyStatsApp` (**placeholder**; en Android ya se cambió el prefijo `com.example`, en iOS no) |
| Versión mínima | — | — | iOS 15.0 (razonable para los plugins actuales) |
| Firebase | `google-services.json` en el repo | Usa la configuración "Web" del mismo proyecto | `ios` en `firebase_options.dart` tiene **valores `REEMPLAZAR`**; no existe `GoogleService-Info.plist` |
| Suscripciones (RevenueCat) | Sí, clave `goog_…` | **No** (`isRevenueCatSupported` es `false`): premium = `true` sin restricciones | `isRevenueCatSupported` da `true`, pero ver §4.1 |
| Id de dispositivo | `ANDROID_ID` (sobrevive a reinstalar) | Id aleatorio en Hive | Id aleatorio en Hive (**se pierde al reinstalar**, ver §4.3) |
| Compartir/exportar | `share_plus` (hoja nativa) | `file_picker` (elegir carpeta) | Código ya contempla `Platform.isIOS` → hoja de compartir |
| Orientación | Solo vertical (`setPreferredOrientations`) | No aplica | Hay que reflejarlo también en `Info.plist` (ver §4.8) |

---

## 4. Qué habría que resolver para iOS (con su implicancia)

### 4.1 Suscripciones: la clave de RevenueCat es solo de Android
`main.dart` configura RevenueCat con **una sola** constante, `goog_…`, y la usa en toda plataforma donde `isRevenueCatSupported` es verdadero. En iOS hace falta la clave **`appl_…`** (la del proyecto iOS de RevenueCat) y los productos creados en **App Store Connect**.
- **Hoy, en iOS**: `Purchases.configure` con la clave de Google falla; el código lo captura (`try/catch`) y sigue, así que **la app abriría pero nadie podría comprar ni activar premium**, sin ningún error visible.
- **Implicancia**: hay que elegir la clave según la plataforma (y centralizarlo en `platform_support.dart`).

### 4.2 Los productos de dispositivo adicional son ids de Google Play
`subscription_tiers.dart` define `kBasePremiumProductId = 'premium_mensual:prem'` y `kDeviceAddOnProductIds = ['da_mensual:da-men', …]`. El formato `producto:plan-base` es **propio de Google Play** (Play Billing). En App Store los ids tienen otra forma.
- **Implicancia**: `deviceLimitFrom` solo reconoce un complemento si su id aparece en `activeSubscriptions`, o si está su *entitlement* (`device_addon_N`). En iOS los ids no coincidirían, así que **un usuario de iOS que compre un complemento seguiría con límite de 1 dispositivo** (solo andaría la vía por entitlement).
- **Solución probable**: que el límite se calcule **solo desde entitlements** (que son independientes de la tienda y ya existen: `rallystats_pro`, `device_addon_1..3`), asociando en RevenueCat los productos de ambas tiendas a esos mismos entitlements. Es un cambio chico en código, pero hay que configurarlo bien en el panel de RevenueCat.
- **Dato a favor**: la app ya hace `Purchases.logIn(uid)` con el uid de Firebase. En RevenueCat, si el *App User ID* es el mismo, **el entitlement se comparte entre plataformas** (alguien que pagó en Android y entra con la misma cuenta en iOS ve premium). **[verificar]** el comportamiento exacto de compras cruzadas entre tiendas en la documentación de RevenueCat.

### 4.3 Identificación del dispositivo (control de "una cuenta, N dispositivos")
Solo Android usa un id que sobrevive a reinstalar (`ANDROID_ID`). En cualquier otra plataforma se guarda un id aleatorio en Hive, que **se borra al desinstalar**.
- **Implicancia**: en iOS reaparecería exactamente el problema que ya tuvimos: reinstalar crea un "dispositivo fantasma" y, con el límite de 1 del plan gratis, el usuario puede quedar **afuera de su propia cuenta**.
- **Opciones**: guardar el id en el **Keychain** de iOS (en general persiste entre reinstalaciones **[verificar]**) o usar `identifierForVendor` (cambia si se borran todas las apps del mismo desarrollador). Hace falta un plugin de almacenamiento seguro y una migración parecida a la de Android.

### 4.4 Gestión de suscripción
`subscription_management_launcher.dart` abre la URL de **Play Store**. Apple exige que el usuario pueda gestionar/cancelar desde la app; la URL equivalente es la de suscripciones de la cuenta de Apple. Es un `if` por plataforma.

### 4.5 Canje de códigos promocionales — el punto de mayor riesgo de rechazo
La función `redeemPromoCode` otorga premium o dispositivos **por fuera de la compra dentro de la app**. Las reglas de Apple (App Store Review Guidelines, 3.1.1) dicen que las apps no pueden desbloquear funciones con mecanismos propios como códigos de licencia; para eso Apple ofrece sus propios *offer codes*. Hay excepciones y matices (por ejemplo para servicios que funcionan en varias plataformas, 3.1.3) **[verificar el texto vigente]**.
- **Implicancia**: es un riesgo real de que Apple rechace la app. Hay tres caminos: (a) ocultar el canje en iOS, (b) migrar a *offer codes* de Apple en iOS, (c) consultar con Apple en la revisión. **Es una decisión de negocio**, no solo de código.

### 4.6 Firebase en iOS
Hay que registrar una app iOS en el proyecto Firebase, descargar `GoogleService-Info.plist`, completar `firebase_options.dart` (o regenerarlo con `flutterfire configure`) y usar un **bundle id definitivo** (recomendado: el mismo `com.rallystats.app`, para coherencia con Android). Auth por email/contraseña, Firestore y Cloud Functions tienen soporte oficial en iOS.

### 4.7 Requisitos de revisión de Apple que conviene chequear
- **Eliminar cuenta dentro de la app**: Apple lo exige y **ya lo tenemos**.
- **Sign in with Apple**: solo es obligatorio si se ofrece login con terceros (Google, Facebook…). Nosotros usamos email/contraseña, así que **no aplica** hoy; si algún día se agrega login social, sí.
- **Etiquetas de privacidad ("App Privacy") y manifiesto de privacidad**: hay que declarar qué datos se recogen. Sale de nuestra política de privacidad; si se activa la sincronización en la nube (#47) hay que reflejarlo ahí.
- **Capturas y metadatos** propios de App Store (tamaños de pantalla de iPhone/iPad).

### 4.8 Detalles de configuración nativa
- `Info.plist`: restringir orientaciones a vertical (en iPad, App Store exige además declarar si la app necesita pantalla completa para no admitir todas las orientaciones **[verificar]**).
- Íconos de app para iOS, nombre visible y permisos si se usan cámara/fotos para las fotos de jugadores (cada permiso necesita su texto en `Info.plist`).
- `share_plus` en iPad necesita indicar desde dónde se abre la hoja de compartir **[verificar]**.
- El `Podfile` y las dependencias nativas se generan en el primer build en Mac (CocoaPods); el primer build con Firebase es lento.

### 4.9 Lo que ya anda sin tocar
Lógica de juego, estadísticas, scouting, temporada, impacto, pizarra, PDF e impresión (`printing` soporta iOS), guardado local con Hive, tema, y la mayoría de las pantallas.

---

## 5. Windows: qué implica hoy (y por qué importa)

- Windows **no tiene** RevenueCat: `SubscriptionController.refresh()` deja `isPremium = true` en esa plataforma. **La versión de Windows es, de hecho, gratuita y sin restricciones**, aunque la de Android sea de pago. Es una decisión que ya está en el código ("fuera del esquema de suscripción por ahora"); conviene que sea una decisión consciente del negocio, porque cualquiera con la versión de escritorio tiene todo lo premium.
- El control de dispositivos en Windows usa el id aleatorio de Hive (mismo problema de reinstalación que iOS).
- Compilar para Windows exige Visual Studio con "Desarrollo para el escritorio con C++" y **hacerlo en una máquina Windows**. Windows tampoco tiene tienda integrada en el flujo actual (se reparte instalador/zip).

## 6. Cómo trabajar iOS sin tener una Mac

| Opción | Qué da | Costo/limitación |
| --- | --- | --- |
| Mac física (propia o prestada) | Todo: compilar, probar en simulador, firmar, subir | Hardware |
| Mac en la nube (alquiler por hora/mes) | Lo mismo, por escritorio remoto | Pago por uso |
| CI con macOS (Codemagic, GitHub Actions `macos`, etc.) | Compilar y subir a **TestFlight** sin Mac local | No hay simulador interactivo; probar requiere un iPhone real o TestFlight. Hay que configurar firma (certificados/perfiles) |
| Cuenta **Apple Developer Program** | Imprescindible para publicar y para TestFlight | Pago anual **[verificar monto vigente]** |

## 7. Implicancias para nosotros (resumen para decidir)

1. **Esfuerzo técnico**: moderado. Gran parte es configuración (Firebase, RevenueCat, App Store Connect) más 4–5 cambios puntuales de código (clave por plataforma, límite por entitlements, gestión de suscripción, id de dispositivo, canje de códigos). Los cambios de código son chicos; **lo que consume tiempo es la burocracia de tienda y las pruebas en un iPhone real**.
2. **Costo recurrente**: cuenta de desarrollador de Apple, más eventual CI/Mac en la nube, más la comisión de Apple sobre las suscripciones (existen tramos reducidos para desarrolladores chicos **[verificar condiciones]**).
3. **Mantenimiento**: pasamos de 2 a 3 plataformas; cada cambio con plugins nativos hay que probarlo en las tres. Conviene mantener `platform_support.dart` como **única fuente** de "qué soporta cada plataforma".
4. **Riesgo de revisión**: el canje de códigos (4.5) es el principal. Conviene decidirlo **antes** de invertir en el resto.
5. **Modelo de negocio**: hoy hay tres situaciones distintas (Android de pago, Windows gratis, iOS sin definir). Si iOS sale, hay que definir precios por tienda y si una suscripción compartida entre tiendas es una promesa que queremos hacer.
6. **Datos**: el sync de partidos (#47) y el backup (#52) usan Firestore, que funciona igual en iOS; pero actualizan la política de privacidad y las etiquetas de App Store.

## 8. Plan sugerido (orden de menor a mayor riesgo)

1. **Decidir** el canje de códigos en iOS (4.5) y el modelo de precios/entitlements (4.2).
2. **Preparar sin Mac**: bundle id definitivo, registrar app iOS en Firebase, crear app y productos en App Store Connect, proyecto iOS en RevenueCat, cuenta de desarrollador.
3. **Código** (cambios chicos y testeables en Windows/Android): clave de RevenueCat por plataforma, límite de dispositivos por entitlements, gestión de suscripción por plataforma, id de dispositivo en Keychain, ocultar/adaptar canje.
4. **Primer build en iOS** (Mac o CI), probar en un iPhone real vía TestFlight.
5. **Material de tienda y revisión** (capturas, privacidad, descripción).

## 9. Qué no sabemos todavía (para verificar)
- Comportamiento exacto de compras compartidas entre tiendas en RevenueCat con nuestro esquema de entitlements.
- Texto vigente de las guías de Apple sobre códigos propios (3.1.1 / 3.1.3) y su aplicación a nuestro caso.
- Si el Keychain conserva el id tras reinstalar en las versiones de iOS que soportamos.
- Montos y condiciones actuales (cuenta de desarrollador, comisiones, CI).
- Estado de los íconos y permisos nativos de iOS (la carpeta `ios/` es la plantilla por defecto).
