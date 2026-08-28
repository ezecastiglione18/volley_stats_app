import 'legal_section.dart';

/// Texto de la Política de Privacidad de RallyStats, mostrado en el diálogo
/// de aceptación al crear una cuenta (`showLegalDocumentDialog`).
///
/// Transcripción textual (sin el maquetado HTML) del documento publicado en
/// https://claude.ai/code/artifact/a4fe6398-98ad-416f-b495-5078529de1d7 — si
/// se actualiza ese documento, actualizar este archivo en la misma pasada y
/// subir [kPrivacyPolicyVersion]/[kPrivacyPolicyEffectiveDate] para que quede
/// registro de qué versión aceptó cada cuenta nueva (ver
/// `AuthService.register`).
const kPrivacyPolicyVersion = '1.0';
const kPrivacyPolicyEffectiveDate = '26 de agosto de 2026';

const List<LegalSection> privacyPolicySections = [
  LegalSection(
    'En síntesis',
    'Tus partidos son tuyos y se quedan en tu dispositivo. Equipos, jugadores, partidos y la '
        'pizarra táctica se guardan solo en el almacenamiento local del celular o la PC. '
        'RallyStats no tiene servidor para esos datos: nunca los vemos, ni podríamos verlos '
        'aunque quisiéramos.\n\n'
        'Para iniciar sesión usamos Firebase (Google). Guardamos tu email, tu nombre y '
        'apellido, y un identificador de instalación por cada dispositivo donde entrás — solo '
        'para verificar tu cuenta y controlar cuántos dispositivos la usan a la vez, según tu '
        'plan.\n\n'
        'La suscripción paga la administra Google. En Android, todo el cobro pasa por Google '
        'Play Billing y RevenueCat. Ni nosotros ni RevenueCat vemos tu tarjeta ni ningún dato '
        'de pago: eso queda entre vos y Google.\n\n'
        'No hay publicidad ni rastreo. RallyStats no incluye analítica, publicidad ni medición '
        'de terceros, y no vende ni cede datos a nadie con fines comerciales.\n\n'
        'Vos decidís qué compartir. Exportar un partido o compartir un PDF es una acción tuya, '
        'explícita, con las apps que elijas — nunca pasa por nuestros servidores.',
  ),
  LegalSection(
    '01. Alcance y responsable del tratamiento',
    'Esta política aplica a RallyStats, la aplicación de estadísticas de vóley para Android y '
        'Windows desarrollada y operada por Ezequiel Castiglione y Federico Perez ("los '
        'desarrolladores", "nosotros"). Describe qué datos personales se procesan al usar la '
        'app —tanto los que se guardan únicamente en tu dispositivo como los pocos que sí '
        'llegan a un servidor—, con qué finalidad, con qué base legal, con qué terceros se '
        'comparten y qué derechos tenés sobre ellos, conforme a la Ley N.º 25.326 de '
        'Protección de los Datos Personales y su Decreto Reglamentario N.º 1558/2001.\n\n'
        'Al crear una cuenta y usar RallyStats, aceptás los términos descriptos en esta '
        'política. Si tenés cualquier consulta, escribinos a ezecastiglione18@gmail.com o a '
        'federicotomasperez2002@outlook.com.',
  ),
  LegalSection(
    '02. Datos que se guardan únicamente en tu dispositivo',
    'La mayor parte de lo que cargás en RallyStats no tiene backend: se guarda con Hive, una '
        'base de datos local, directamente en el almacenamiento del dispositivo donde '
        'instalaste la app. Esto incluye:\n\n'
        '• Equipos y jugadores: nombre, apellido, número de camiseta, posición, altura, peso, '
        'mano hábil, alcances de bloqueo y ataque, fecha de nacimiento o edad, y una foto '
        'opcional.\n'
        '• Partidos: el registro jugada por jugada de cada set (saques, recepciones, ataques, '
        'bloqueos, errores, rotaciones, cambios de jugador y de líbero) y las estadísticas '
        'calculadas a partir de ese registro.\n'
        '• Pizarra táctica: los dibujos y formaciones que guardás como jugadas.\n'
        '• Reportes en PDF: se generan en el propio dispositivo a partir de esos datos.\n\n'
        'Nada de esto se sube automáticamente a ningún servidor nuestro ni de terceros. No '
        'tenemos backend para estos datos, así que no podemos acceder a ellos. Si desinstalás '
        'la app o borrás sus datos, esta información se pierde, salvo que la hayas exportado '
        'vos mismo.\n\n'
        'La única forma en que esta información sale del dispositivo es si vos, de forma '
        'explícita, elegís exportar un partido como archivo .json (para pasarlo a otro '
        'dispositivo) o compartir un reporte en PDF con las apps que elijas (WhatsApp, email, '
        'etc.) o guardarlo donde vos indiques. Esa decisión y ese destino son enteramente '
        'tuyos: RallyStats no interviene en el envío ni recibe copia.',
  ),
  LegalSection(
    '03. Cuenta y control de dispositivos',
    'Para usar RallyStats hace falta crear una cuenta con email y contraseña. Esta es la única '
        'parte de la app con un backend real, y existe con un propósito puntual: evitar que '
        'una misma cuenta se use en más dispositivos de los que permite tu plan. Para esto '
        'usamos Firebase Authentication y Cloud Firestore, dos servicios de Google.\n\n'
        'Al registrarte guardamos:\n\n'
        '• Tu email y contraseña, gestionados por Firebase Authentication. La contraseña nunca '
        'queda en texto plano ni la almacenan los desarrolladores: Firebase la guarda con hash, y '
        'no tenemos forma de leerla.\n'
        '• Tu nombre y apellido, que cargás al registrarte.\n'
        '• Por cada dispositivo donde iniciás sesión: un identificador de instalación generado '
        'al azar y guardado localmente (no es el IMEI ni ningún identificador de hardware o de '
        'publicidad), una etiqueta con el sistema operativo y su versión (por ejemplo '
        '"android 14" o "windows 10"), y la fecha y hora en que iniciaste sesión desde ese '
        'dispositivo.\n\n'
        'Todo esto se guarda en un único documento de Firestore por cuenta, identificado con '
        'tu uid de Firebase, protegido con reglas de seguridad que solo permiten que tu propia '
        'cuenta autenticada lea o escriba ese documento — ninguna otra cuenta puede verlo.\n\n'
        'Usamos esta información exclusivamente para autenticarte y para calcular y hacer '
        'cumplir el límite de dispositivos simultáneos de tu plan (ver sección 07). No la '
        'usamos con fines de marketing ni la cruzamos con ninguna otra base.',
  ),
  LegalSection(
    '04. Suscripción y pagos (solo Android)',
    'En Windows, RallyStats no tiene restricciones de plan: todas las funciones están '
        'disponibles sin cargo. En Android, algunas funciones (pizarra táctica, estadísticas, '
        'zona de destino, y los topes de partidos y sets guardados) están limitadas en la '
        'versión gratuita y se desbloquean con una suscripción mensual paga.\n\n'
        'Esa suscripción se procesa enteramente a través de Google Play Billing y RevenueCat, '
        'un proveedor que administra el estado de las suscripciones. Cuando iniciás sesión, le '
        'informamos a RevenueCat tu uid de Firebase (para asociar tu suscripción a tu cuenta), '
        'y RevenueCat nos informa de vuelta el estado de tu suscripción (activa o no, qué '
        'producto compraste, fecha de vencimiento) para que la app sepa qué funciones '
        'habilitarte.\n\n'
        'Ni nosotros ni RevenueCat vemos ni almacenamos tu número de tarjeta, CVV ni ningún '
        'otro dato de tu medio de pago: esa información queda exclusivamente entre vos y '
        'Google Play. Para cancelar o gestionar tu suscripción, la app te dirige directamente '
        'a Google Play.',
  ),
  LegalSection(
    '05. A quién le confiamos el procesamiento',
    'Para operar el login y la suscripción trabajamos con dos proveedores externos, que actúan '
        'como encargados del tratamiento por nuestra cuenta, bajo sus propias políticas de '
        'seguridad:\n\n'
        '• Google (Firebase Authentication y Cloud Firestore): aloja tu email, contraseña, '
        'nombre, apellido y los registros de dispositivo descriptos en la sección 03.\n'
        '• RevenueCat (y, detrás de esta, Google Play Billing): administra el estado de tu '
        'suscripción según lo descripto en la sección 04.\n\n'
        'Ninguno de estos proveedores tiene autorización nuestra para usar tus datos con fines '
        'propios de publicidad o analítica; los usan únicamente para prestarnos el servicio '
        'contratado. No compartimos, vendemos ni cedemos tus datos a ningún otro tercero con '
        'fines comerciales o publicitarios.',
  ),
  LegalSection(
    '06. Transferencia internacional de datos',
    'Firebase y RevenueCat operan infraestructura fuera de la Argentina (típicamente en '
        'Estados Unidos y otros países donde estos proveedores tienen centros de datos). Esto '
        'implica que tu email, nombre, contraseña (hasheada) y los registros de dispositivo y '
        'suscripción se procesan en servidores ubicados fuera del país.\n\n'
        'El artículo 12 de la Ley N.º 25.326 restringe este tipo de transferencias a países que '
        'no cuenten con niveles de protección adecuados, salvo que medie el consentimiento del '
        'titular de los datos. Al crear una cuenta en RallyStats y aceptar esta política, '
        'prestás ese consentimiento, en tanto esta transferencia es necesaria para poder '
        'ofrecerte el servicio de login y, en Android, de suscripción.',
  ),
  LegalSection(
    '07. Para qué usamos cada dato y con qué base legal',
    'Email y contraseña → crear y autenticar tu cuenta (consentimiento informado al '
        'registrarte, art. 5).\n'
        'Nombre y apellido → identificar la cuenta (consentimiento).\n'
        'ID de instalación, SO y fecha de login por dispositivo → calcular y hacer cumplir el '
        'límite de dispositivos de tu plan (ejecución del servicio contratado).\n'
        'Uid compartido con RevenueCat → asociar tu suscripción a tu cuenta (ejecución del '
        'contrato de suscripción).\n'
        'Estado de suscripción → habilitar o restringir funciones premium (ejecución del '
        'contrato de suscripción).\n'
        'Equipos, jugadores, partidos, pizarra → que la app funcione como planilla y anotador '
        '(no hay tratamiento de nuestra parte: no salen del dispositivo).',
  ),
  LegalSection(
    '08. Plazos de conservación',
    'Datos de cuenta (email, nombre, apellido, registros de dispositivo): se conservan '
        'mientras la cuenta exista. Podés eliminar tu cuenta vos mismo desde la app (botón '
        '"Eliminar cuenta" en la pantalla principal), o escribiendo a '
        'ezecastiglione18@gmail.com o federicotomasperez2002@outlook.com.\n\n'
        'Datos de suscripción: los conserva RevenueCat según sus propios plazos, asociados a '
        'tu historial de compras en Google Play (necesario, entre otras cosas, para procesar '
        'reclamos o restauraciones de compra).\n\n'
        'Datos locales (equipos, jugadores, partidos, pizarra): quedan en tu dispositivo hasta '
        'que vos los borres desde la propia app, o hasta que desinstales RallyStats. No '
        'tenemos control ni conocimiento de estos plazos, porque no tenemos acceso a esos '
        'datos.',
  ),
  LegalSection(
    '09. Cómo protegemos tu información',
    'Toda comunicación entre la app y Firebase/RevenueCat viaja cifrada (HTTPS/TLS), como es '
        'estándar en los SDKs oficiales que usamos. Tu contraseña nunca se guarda en texto '
        'plano: Firebase Authentication la guarda con hash. El documento de Firestore con tus '
        'datos de cuenta y dispositivos está protegido con reglas de seguridad que solo '
        'permiten que tu propia cuenta autenticada lo lea o lo modifique.\n\n'
        'La app no pide permisos de cámara, ubicación, contactos ni acceso general al '
        'almacenamiento. En Android, el único permiso que declara es el de Facturación de '
        'Google Play (com.android.vending.BILLING), necesario para procesar la suscripción; '
        'para elegir una foto de jugador, un PDF o un archivo exportado, se usan los '
        'selectores nativos del sistema operativo.\n\n'
        'Ningún sistema es 100% infalible, pero no guardamos de más: al no tener servidor para '
        'tus datos de equipos, jugadores y partidos, ese riesgo directamente no existe para '
        'esa información.',
  ),
  LegalSection(
    '10. Tus derechos sobre tus datos personales',
    'De acuerdo con los artículos 14 a 16 de la Ley N.º 25.326, sobre los datos de cuenta que '
        'sí procesamos (sección 03) tenés derecho a:\n\n'
        '• Acceso: pedirnos qué datos tuyos tenemos guardados.\n'
        '• Rectificación y actualización: corregir datos inexactos o desactualizados.\n'
        '• Supresión: pedir que eliminemos tu cuenta y los datos asociados (o hacerlo vos '
        'mismo desde la app).\n'
        '• Revocar tu consentimiento en cualquier momento, sin efecto retroactivo, lo que '
        'implica dejar de poder usar la app con esa cuenta.\n\n'
        'Para ejercer cualquiera de estos derechos, escribinos a '
        'ezecastiglione18@gmail.com o a federicotomasperez2002@outlook.com. Vamos a pedirte '
        'que verifiques tu identidad (por '
        'ejemplo, escribiendo desde el mismo email de tu cuenta) antes de hacer cualquier '
        'cambio, y a responderte en un plazo razonable.\n\n'
        'Estos derechos no aplican del mismo modo a los datos que se guardan solo en tu '
        'dispositivo (equipos, jugadores, partidos, pizarra): esos ya están enteramente bajo '
        'tu control, y se acceden, corrigen o eliminan directamente desde la app o '
        'desinstalándola, sin que medie ningún pedido a nosotros.',
  ),
  LegalSection(
    '11. Si cargás datos de otras personas (tus jugadores)',
    'Cuando armás un equipo en RallyStats, vos cargás datos de otras personas —tus jugadores— '
        'como nombre, apellido, fecha de nacimiento, medidas físicas o una foto. Esos datos, '
        'igual que el resto de la información de equipos y partidos, se guardan solo en tu '
        'dispositivo: los desarrolladores de RallyStats no los reciben, no los procesan y no '
        'tienen forma de acceder a ellos.\n\n'
        'Esto significa que, respecto de esos datos, sos vos —como entrenador, delegado o '
        'quien cargue esa información— quien actúa como responsable del tratamiento frente a '
        'esos jugadores o sus padres/tutores, y quien debe evaluar si corresponde informarles '
        'que sus datos están cargados en la app, según las reglas de tu club o institución. '
        'RallyStats es, en ese sentido, una herramienta que usás para llevar esa planilla, del '
        'mismo modo que lo sería un cuaderno o una hoja de cálculo guardada en tu propio '
        'dispositivo.\n\n'
        'Si exportás un partido o compartís un reporte en PDF que incluye estos datos, sos vos '
        'quien decide con quién compartirlo: tené en cuenta que esos archivos pueden contener '
        'nombres y otros datos de tus jugadores antes de enviarlos a terceros.',
  ),
  LegalSection(
    '12. Uso por menores de edad',
    'RallyStats está pensado para que lo usen entrenadores, delegados o jugadores adultos que '
        'administran o anotan un partido, no para que un chico cree y gestione su propia '
        'cuenta. No solicitamos deliberadamente cuentas de menores de edad ni construimos '
        'perfiles de comportamiento de nadie, sea o no menor.\n\n'
        'Los datos de jugadores menores de edad que un entrenador carga en la planilla del '
        'equipo se guardan únicamente en el dispositivo del entrenador, según lo explicado en '
        'la sección 11, y no en ningún servidor nuestro.',
  ),
  LegalSection(
    '13. Publicidad, analítica y cookies',
    'RallyStats no muestra publicidad, no incluye ningún SDK de analítica, medición de uso, '
        'atribución ni rastreo de terceros (no hay Google Analytics, Meta SDK, Crashlytics ni '
        'similares integrados en la app), y no usa cookies, porque no es una aplicación web. '
        'No armamos perfiles de tus hábitos de uso ni los compartimos con anunciantes, porque '
        'no recolectamos esa información en absoluto.',
  ),
  LegalSection(
    '14. Cambios a esta política',
    'Podemos actualizar esta política si cambia algo en cómo tratamos tus datos (por ejemplo, '
        'si sumamos un nuevo proveedor o una función que lo requiera). Vas a encontrar siempre '
        'la versión vigente dentro de la app, en esta misma pantalla, con la fecha de última '
        'actualización indicada arriba. Si el cambio es significativo, vamos a intentar '
        'avisarte dentro de la app antes de que entre en vigencia.',
  ),
  LegalSection(
    '15. Autoridad de control',
    'La Agencia de Acceso a la Información Pública (AAIP) es el órgano de control de la Ley '
        'N.º 25.326 en la República Argentina. Si considerás que no resolvimos tu consulta o '
        'reclamo de forma satisfactoria, tenés derecho a presentar una denuncia ante la AAIP: '
        'argentina.gob.ar/aaip.',
  ),
  LegalSection(
    '16. Contacto',
    'Para preguntas sobre esta política, para ejercer tus derechos sobre tus datos de cuenta, '
        'o para reportar cualquier inquietud de privacidad, escribinos a '
        'ezecastiglione18@gmail.com o federicotomasperez2002@outlook.com.',
  ),
];
