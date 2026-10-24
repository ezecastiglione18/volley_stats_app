import 'legal_section.dart';

/// Texto de la Política de Privacidad de RallyStats, mostrado en el diálogo
/// de aceptación al crear una cuenta (`showLegalDocumentDialog`), en
/// Configuración y en el aviso de "Partidos y equipos en la nube".
///
/// Transcripción textual (sin el maquetado HTML) del documento publicado en
/// https://claude.ai/code/artifact/a4fe6398-98ad-416f-b495-5078529de1d7 — si
/// se actualiza ese documento, actualizar este archivo en la misma pasada y
/// subir [kPrivacyPolicyVersion]/[kPrivacyPolicyEffectiveDate] para que quede
/// registro de qué versión aceptó cada cuenta: al registrarse
/// (`AuthService.register`, campo `consent`) y al activar la nube
/// (`MatchSyncService.setCloudSync`, campo `cloudConsent`).
///
/// Versión 2.0: suma la nube opcional de partidos y equipos (sección 03). A
/// quien no la activa no le cambia nada, así que no se pide volver a aceptar
/// la política: el consentimiento para la nube se pide al activarla.
const kPrivacyPolicyVersion = '2.0';
const kPrivacyPolicyEffectiveDate = '23 de octubre de 2026';

const List<LegalSection> privacyPolicySections = [
  LegalSection(
    'En síntesis',
    'Tus partidos son tuyos. Equipos, jugadores, partidos, la pizarra táctica y el fixture se '
        'guardan en el almacenamiento local del celular o la PC. Solo si vos activás "Partidos y '
        'equipos en la nube", los partidos terminados y los equipos con sus jugadores se guardan '
        'además en tu cuenta, para verlos en todos tus dispositivos. Si no la activás, nada de eso '
        'sale de tu dispositivo.\n\n'
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
        'app —tanto los que se guardan únicamente en tu dispositivo como los que llegan a un '
        'servidor—, con qué finalidad, con qué base legal, con qué terceros se comparten y qué '
        'derechos tenés sobre ellos, conforme a la Ley N.º 25.326 de Protección de los Datos '
        'Personales y su Decreto Reglamentario N.º 1558/2001.\n\n'
        'Al crear una cuenta y usar RallyStats, aceptás los términos descriptos en esta '
        'política. Si tenés cualquier consulta, escribinos a ezecastiglione18@gmail.com o a '
        'federicotomasperez2002@outlook.com.',
  ),
  LegalSection(
    '02. Datos que se guardan en tu dispositivo',
    'Lo que cargás en RallyStats se guarda con Hive, una base de datos local, directamente en '
        'el almacenamiento del dispositivo donde instalaste la app, separado por cuenta. Esto '
        'incluye:\n\n'
        '• Equipos y jugadores: nombre, apellido, número de camiseta, posición, altura, peso, '
        'mano hábil, alcances de bloqueo y ataque, fecha de nacimiento o edad, y una foto '
        'opcional.\n'
        '• Partidos: el registro jugada por jugada de cada set (saques, recepciones, ataques, '
        'bloqueos, errores, rotaciones, cambios de jugador y de líbero), las notas que '
        'escribas y las estadísticas calculadas a partir de ese registro.\n'
        '• Pizarra táctica: los dibujos y formaciones que guardás como jugadas.\n'
        '• Fixture: los partidos por jugar que cargás.\n'
        '• Reportes en PDF: se generan en el propio dispositivo a partir de esos datos.\n\n'
        'Mientras no actives la nube (sección 03), nada de esto se sube a ningún servidor '
        'nuestro ni de terceros. Si desinstalás la app o borrás sus datos, esta información se '
        'pierde, salvo que la hayas exportado vos mismo o la tengas en la nube.\n\n'
        'Además, vos podés elegir de forma explícita exportar un partido o todos tus datos como '
        'archivo (para pasarlos a otro dispositivo o guardarlos aparte) o compartir un reporte '
        'en PDF con las apps que elijas (WhatsApp, email, etc.). Esa decisión y ese destino son '
        'enteramente tuyos: RallyStats no interviene en el envío ni recibe copia.',
  ),
  LegalSection(
    '03. Partidos y equipos en la nube (opcional)',
    'Si activás "Partidos y equipos en la nube" (te lo preguntamos una vez después de iniciar '
        'sesión, y lo podés cambiar cuando quieras en Configuración), guardamos en Cloud '
        'Firestore (Google), asociado a tu cuenta, lo siguiente:\n\n'
        '• Los partidos terminados, completos: datos del partido (fecha, torneo, instancia, '
        'cancha, categoría, rival), el plantel con los datos de cada jugador, el registro jugada '
        'por jugada de cada set y las notas que hayas escrito.\n'
        '• Tus equipos (propios y rivales precargados) con sus jugadores: nombre, apellido, '
        'número, posición, altura, peso, mano hábil, alcances, fecha de nacimiento o edad, y el '
        'cuerpo técnico.\n'
        '• La fecha de la última modificación de cada partido y equipo, y si lo mandaste a la '
        'papelera.\n\n'
        'No se suben las fotos de los jugadores, las jugadas de la pizarra, el fixture ni los '
        'partidos en curso.\n\n'
        'Para qué: únicamente para que veas y uses los mismos partidos y equipos en todos los '
        'dispositivos de tu cuenta, y como respaldo si cambiás o perdés el dispositivo. No los '
        'miramos, no los analizamos, no los usamos para ningún otro fin ni los compartimos con '
        'nadie. Están protegidos con reglas de seguridad que solo permiten que tu propia cuenta '
        'autenticada los lea o los modifique.\n\n'
        'Cómo borrarlos: un partido que eliminás va a la papelera (en todos tus dispositivos) y '
        'se borra definitivamente, también de la nube, a los 30 días o cuando lo elimines '
        'definitivamente desde la papelera; un equipo que eliminás se borra a los 30 días. Si '
        'apagás la nube podés elegir borrar toda la copia de la nube; si no, queda guardada hasta '
        'que la borres o elimines tu cuenta. Al eliminar tu cuenta se borra toda la copia de la '
        'nube. Apagar la nube o eliminar la copia nunca borra lo que tenés en tu dispositivo.\n\n'
        'Al activarla queda registrado que aceptaste esta versión de la política y cuándo.',
  ),
  LegalSection(
    '04. Cuenta y control de dispositivos',
    'Para usar RallyStats hace falta crear una cuenta con email y contraseña. Para la cuenta y '
        'para evitar que se use en más dispositivos de los que permite tu plan usamos Firebase '
        'Authentication y Cloud Firestore, dos servicios de Google.\n\n'
        'Al registrarte guardamos:\n\n'
        '• Tu email y contraseña, gestionados por Firebase Authentication. La contraseña nunca '
        'queda en texto plano ni la almacenan los desarrolladores: Firebase la guarda con hash, y '
        'no tenemos forma de leerla.\n'
        '• Tu nombre y apellido, que cargás al registrarte, y qué versión de esta política y de '
        'los términos aceptaste.\n'
        '• Por cada dispositivo donde iniciás sesión: un identificador de instalación (no es el '
        'IMEI ni ningún identificador de publicidad), una etiqueta con el sistema operativo y su '
        'versión (por ejemplo "android 14" o "windows 10"), y la fecha y hora en que iniciaste '
        'sesión desde ese dispositivo.\n'
        '• En la versión gratuita, el identificador del partido con el que usaste la estadística '
        'gratis, para que ese cupo sea uno por cuenta.\n'
        '• Si activaste o no la nube (sección 03).\n\n'
        'Todo esto se guarda en un único documento de Firestore por cuenta, identificado con '
        'tu uid de Firebase, protegido con reglas de seguridad que solo permiten que tu propia '
        'cuenta autenticada lea o escriba ese documento — ninguna otra cuenta puede verlo.\n\n'
        'Usamos esta información exclusivamente para autenticarte, para calcular y hacer '
        'cumplir el límite de dispositivos simultáneos de tu plan y las funciones de la versión '
        'gratuita (ver sección 08). No la usamos con fines de marketing ni la cruzamos con '
        'ninguna otra base.',
  ),
  LegalSection(
    '05. Suscripción y pagos (solo Android)',
    'En Windows, RallyStats no tiene restricciones de plan: todas las funciones están '
        'disponibles sin cargo. En Android, algunas funciones (pizarra táctica, zona de destino, '
        'estadísticas más allá de un partido, y el tope de partidos guardados) están limitadas '
        'en la versión gratuita y se desbloquean con una suscripción mensual paga. La nube de '
        'partidos y equipos está disponible en las dos versiones.\n\n'
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
    '06. A quién le confiamos el procesamiento',
    'Para operar el login, la nube y la suscripción trabajamos con dos proveedores externos, que '
        'actúan como encargados del tratamiento por nuestra cuenta, bajo sus propias políticas de '
        'seguridad:\n\n'
        '• Google (Firebase Authentication y Cloud Firestore): aloja tu email, contraseña, '
        'nombre, apellido y los registros de dispositivo descriptos en la sección 04 y, si '
        'activaste la nube, tus partidos y equipos (sección 03).\n'
        '• RevenueCat (y, detrás de esta, Google Play Billing): administra el estado de tu '
        'suscripción según lo descripto en la sección 05.\n\n'
        'Ninguno de estos proveedores tiene autorización nuestra para usar tus datos con fines '
        'propios de publicidad o analítica; los usan únicamente para prestarnos el servicio '
        'contratado. No compartimos, vendemos ni cedemos tus datos a ningún otro tercero con '
        'fines comerciales o publicitarios.',
  ),
  LegalSection(
    '07. Transferencia internacional de datos',
    'Firebase y RevenueCat operan infraestructura fuera de la Argentina (típicamente en '
        'Estados Unidos y otros países donde estos proveedores tienen centros de datos). Esto '
        'implica que tu email, nombre, contraseña (hasheada), los registros de dispositivo y '
        'suscripción y, si activaste la nube, tus partidos y equipos se procesan en servidores '
        'ubicados fuera del país.\n\n'
        'El artículo 12 de la Ley N.º 25.326 restringe este tipo de transferencias a países que '
        'no cuenten con niveles de protección adecuados, salvo que medie el consentimiento del '
        'titular de los datos. Al crear una cuenta en RallyStats y aceptar esta política '
        '—y, para tus partidos y equipos, al activar la nube— prestás ese consentimiento, en '
        'tanto esta transferencia es necesaria para poder ofrecerte el servicio.',
  ),
  LegalSection(
    '08. Para qué usamos cada dato y con qué base legal',
    'Email y contraseña → crear y autenticar tu cuenta (consentimiento informado al '
        'registrarte, art. 5).\n'
        'Nombre y apellido → identificar la cuenta (consentimiento).\n'
        'ID de instalación, SO y fecha de login por dispositivo → calcular y hacer cumplir el '
        'límite de dispositivos de tu plan (ejecución del servicio contratado).\n'
        'Partido de la estadística gratis → que ese cupo sea uno por cuenta (ejecución del '
        'servicio).\n'
        'Uid compartido con RevenueCat → asociar tu suscripción a tu cuenta (ejecución del '
        'contrato de suscripción).\n'
        'Estado de suscripción → habilitar o restringir funciones premium (ejecución del '
        'contrato de suscripción).\n'
        'Partidos y equipos en la nube → verlos en todos tus dispositivos y como respaldo '
        '(consentimiento, al activar la nube; lo podés revocar apagándola).\n'
        'Equipos, jugadores, partidos, pizarra y fixture en tu dispositivo → que la app funcione '
        'como planilla y anotador (no hay tratamiento de nuestra parte: no salen del '
        'dispositivo salvo lo descripto en la sección 03).',
  ),
  LegalSection(
    '09. Plazos de conservación',
    'Datos de cuenta (email, nombre, apellido, registros de dispositivo): se conservan '
        'mientras la cuenta exista. Podés eliminar tu cuenta vos mismo desde la app '
        '(Configuración → "Eliminar cuenta"), o escribiendo a ezecastiglione18@gmail.com o '
        'federicotomasperez2002@outlook.com. Al eliminarla se borran también tus partidos y '
        'equipos de la nube y los datos de esa cuenta en el dispositivo desde donde la '
        'eliminás.\n\n'
        'Partidos y equipos en la nube: mientras la nube esté activada, o hasta que borres la '
        'copia o elimines tu cuenta. Lo que mandás a la papelera se borra a los 30 días.\n\n'
        'Datos de suscripción: los conserva RevenueCat según sus propios plazos, asociados a '
        'tu historial de compras en Google Play (necesario, entre otras cosas, para procesar '
        'reclamos o restauraciones de compra).\n\n'
        'Datos locales (equipos, jugadores, partidos, pizarra, fixture): quedan en tu dispositivo '
        'hasta que vos los borres desde la propia app, o hasta que desinstales RallyStats. No '
        'tenemos control ni conocimiento de estos plazos, porque no tenemos acceso a esos '
        'datos.',
  ),
  LegalSection(
    '10. Cómo protegemos tu información',
    'Toda comunicación entre la app y Firebase/RevenueCat viaja cifrada (HTTPS/TLS), como es '
        'estándar en los SDKs oficiales que usamos, y Google guarda los datos cifrados. Tu '
        'contraseña nunca se guarda en texto plano: Firebase Authentication la guarda con hash. '
        'Tus datos de cuenta y, si activaste la nube, tus partidos y equipos están protegidos con '
        'reglas de seguridad que solo permiten que tu propia cuenta autenticada los lea o los '
        'modifique.\n\n'
        'La app no pide permisos de cámara, ubicación, contactos ni acceso general al '
        'almacenamiento. En Android, el único permiso que declara es el de Facturación de '
        'Google Play (com.android.vending.BILLING), necesario para procesar la suscripción; '
        'para elegir una foto de jugador, un PDF o un archivo exportado, se usan los '
        'selectores nativos del sistema operativo.\n\n'
        'Ningún sistema es 100% infalible, pero no guardamos de más: si no activás la nube, tus '
        'equipos, jugadores y partidos no están en ningún servidor; si la activás, las fotos '
        'igual nunca salen de tu dispositivo.',
  ),
  LegalSection(
    '11. Tus derechos sobre tus datos personales',
    'De acuerdo con los artículos 14 a 16 de la Ley N.º 25.326, sobre los datos que sí '
        'procesamos (secciones 03 y 04) tenés derecho a:\n\n'
        '• Acceso: pedirnos qué datos tuyos tenemos guardados.\n'
        '• Rectificación y actualización: corregir datos inexactos o desactualizados (los '
        'partidos y equipos de la nube se corrigen editándolos en la app).\n'
        '• Supresión: pedir que eliminemos tu cuenta y los datos asociados (o hacerlo vos '
        'mismo desde la app, igual que borrar la copia de la nube).\n'
        '• Revocar tu consentimiento en cualquier momento, sin efecto retroactivo: para la nube, '
        'apagándola; para la cuenta, eliminándola, lo que implica dejar de poder usar la app '
        'con esa cuenta.\n\n'
        'Para ejercer cualquiera de estos derechos, escribinos a '
        'ezecastiglione18@gmail.com o a federicotomasperez2002@outlook.com. Vamos a pedirte '
        'que verifiques tu identidad (por '
        'ejemplo, escribiendo desde el mismo email de tu cuenta) antes de hacer cualquier '
        'cambio, y a responderte en un plazo razonable.\n\n'
        'Los datos que se guardan solo en tu dispositivo ya están enteramente bajo tu control, '
        'y se acceden, corrigen o eliminan directamente desde la app o desinstalándola, sin que '
        'medie ningún pedido a nosotros.',
  ),
  LegalSection(
    '12. Si cargás datos de otras personas (tus jugadores)',
    'Cuando armás un equipo en RallyStats, vos cargás datos de otras personas —tus jugadores— '
        'como nombre, apellido, fecha de nacimiento, medidas físicas o una foto. Si no activás '
        'la nube, esos datos se guardan solo en tu dispositivo. Si la activás, los datos de los '
        'jugadores (sin las fotos) se guardan también en la nube de tu cuenta, con el único fin '
        'descripto en la sección 03: los desarrolladores de RallyStats no los miran ni los usan '
        'para nada más.\n\n'
        'Respecto de esos datos, sos vos —como entrenador, delegado o quien cargue esa '
        'información— quien actúa como responsable del tratamiento frente a esos jugadores o '
        'sus padres/tutores, y quien debe evaluar si corresponde informarles que sus datos '
        'están cargados en la app (y, si activás la nube, guardados en ella), según las reglas '
        'de tu club o institución. RallyStats es, en ese sentido, una herramienta que usás para '
        'llevar esa planilla, del mismo modo que lo sería una hoja de cálculo guardada en tu '
        'propio dispositivo o en tu cuenta de un servicio en la nube.\n\n'
        'Si exportás un partido o compartís un reporte en PDF que incluye estos datos, sos vos '
        'quien decide con quién compartirlo: tené en cuenta que esos archivos pueden contener '
        'nombres y otros datos de tus jugadores antes de enviarlos a terceros.',
  ),
  LegalSection(
    '13. Uso por menores de edad',
    'RallyStats está pensado para que lo usen entrenadores, delegados o jugadores adultos que '
        'administran o anotan un partido, no para que un chico cree y gestione su propia '
        'cuenta. No solicitamos deliberadamente cuentas de menores de edad ni construimos '
        'perfiles de comportamiento de nadie, sea o no menor.\n\n'
        'Los datos de jugadores menores de edad que un entrenador carga en la planilla del '
        'equipo se guardan en el dispositivo del entrenador y, solo si el entrenador activa la '
        'nube, en la nube de su cuenta, según lo explicado en las secciones 03 y 12. Nunca se '
        'suben sus fotos.',
  ),
  LegalSection(
    '14. Publicidad, analítica y cookies',
    'RallyStats no muestra publicidad, no incluye ningún SDK de analítica, medición de uso, '
        'atribución ni rastreo de terceros (no hay Google Analytics, Meta SDK, Crashlytics ni '
        'similares integrados en la app), y no usa cookies, porque no es una aplicación web. '
        'No armamos perfiles de tus hábitos de uso ni los compartimos con anunciantes, porque '
        'no recolectamos esa información en absoluto.',
  ),
  LegalSection(
    '15. Cambios a esta política',
    'Podemos actualizar esta política si cambia algo en cómo tratamos tus datos (por ejemplo, '
        'si sumamos un nuevo proveedor o una función que lo requiera). Vas a encontrar siempre '
        'la versión vigente dentro de la app, en Configuración, con la fecha de última '
        'actualización indicada arriba. Si el cambio es significativo, vamos a intentar '
        'avisarte dentro de la app antes de que entre en vigencia. Si una función nueva '
        'necesita subir datos que antes quedaban en tu dispositivo, te lo vamos a preguntar '
        'antes, como con la nube de la sección 03.',
  ),
  LegalSection(
    '16. Autoridad de control',
    'La Agencia de Acceso a la Información Pública (AAIP) es el órgano de control de la Ley '
        'N.º 25.326 en la República Argentina. Si considerás que no resolvimos tu consulta o '
        'reclamo de forma satisfactoria, tenés derecho a presentar una denuncia ante la AAIP: '
        'argentina.gob.ar/aaip.',
  ),
  LegalSection(
    '17. Contacto',
    'Para preguntas sobre esta política, para ejercer tus derechos sobre tus datos, o para '
        'reportar cualquier inquietud de privacidad, escribinos a '
        'ezecastiglione18@gmail.com o federicotomasperez2002@outlook.com.',
  ),
];
