import 'legal_section.dart';

/// Texto de los Términos y Condiciones de RallyStats, mostrado en el diálogo
/// de aceptación al crear una cuenta (`showLegalDocumentDialog`).
///
/// Borrador redactado siguiendo el marco legal argentino aplicable a una app
/// con una suscripción vendida a través de Google Play (Ley N.º 24.240 de
/// Defensa del Consumidor, Código Civil y Comercial en materia de contratos
/// de consumo, y remisión a la Ley N.º 25.326 para todo lo relativo a datos
/// personales, ya cubierto en la Política de Privacidad). No reemplaza la
/// revisión de un abogado antes de una publicación pública amplia.
///
/// Si se actualiza este texto, subir [kTermsVersion]/[kTermsEffectiveDate]
/// para que quede registro de qué versión aceptó cada cuenta nueva (ver
/// `AuthService.register`).
const kTermsVersion = '1.0';
const kTermsEffectiveDate = '26 de agosto de 2026';

const List<LegalSection> termsConditionsSections = [
  LegalSection(
    '01. Objeto y aceptación',
    'Estos Términos y Condiciones ("los Términos") regulan el uso de RallyStats, la aplicación '
        'de estadísticas de vóley para Android y Windows desarrollada y operada por Ezequiel '
        'Castiglione y Federico Perez ("los desarrolladores", "nosotros"), por parte de '
        'cualquier persona que cree una cuenta y la use ("vos", "el usuario").\n\n'
        'Al tildar la casilla correspondiente y crear una cuenta, declarás que leíste, '
        'entendiste y aceptás estos Términos en su totalidad, junto con la Política de '
        'Privacidad. Si no estás de acuerdo con alguna parte, no debés crear una cuenta ni usar '
        'la app.',
  ),
  LegalSection(
    '02. Descripción del servicio',
    'RallyStats es una herramienta para anotar en vivo estadísticas de vóley (saque, '
        'recepción, ataque, contraataque, bloqueo, errores) jugada por jugada, aplicando las '
        'reglas oficiales de la FIVB para cambios de jugador y de líbero, generar reportes en '
        'PDF y usar una pizarra táctica para dibujar formaciones y jugadas.\n\n'
        'En Windows, todas las funciones están disponibles sin cargo. En Android, algunas '
        'funciones (pizarra táctica, estadísticas, zona de destino, y los topes de partidos y '
        'sets guardados) están limitadas en la versión gratuita y se desbloquean con una '
        'suscripción mensual paga ("versión premium"), según se detalla en la sección 04.\n\n'
        'Los datos de juego (equipos, jugadores, partidos, jugadas de pizarra) se guardan '
        'exclusivamente en el almacenamiento local del dispositivo: RallyStats funciona '
        'offline para toda esa información. Solo el inicio de sesión y, en Android, la '
        'suscripción premium dependen de conexión a un servicio externo.',
  ),
  LegalSection(
    '03. Cuenta de usuario',
    'Para usar RallyStats hace falta crear una cuenta con email y contraseña. Al registrarte, '
        'te comprometés a:\n\n'
        '• Ser mayor de edad, o contar con la autorización de tu padre, madre o tutor si sos '
        'menor, conforme a la capacidad para contratar que exige el Código Civil y Comercial.\n'
        '• Proporcionar un email válido y datos verídicos (nombre y apellido).\n'
        '• Mantener la confidencialidad de tu contraseña: sos responsable de toda actividad '
        'que ocurra en tu cuenta, salvo que nos avises de un uso no autorizado.\n\n'
        'Cada cuenta puede tener sesión activa en una cantidad limitada de dispositivos a la '
        'vez, según el plan contratado (ver sección 04). Si intentás iniciar sesión superando '
        'ese límite, el nuevo inicio de sesión se rechaza hasta que liberes un lugar cerrando '
        'sesión en otro dispositivo o sumando un complemento de dispositivo adicional.',
  ),
  LegalSection(
    '04. Suscripción, precios y facturación (solo Android)',
    'La versión premium de RallyStats en Android se contrata como una suscripción mensual '
        'recurrente, facturada y cobrada íntegramente a través de Google Play Billing. El '
        'desarrollador no procesa ni almacena tus datos de pago: esa relación de facturación es '
        'directamente entre vos y Google.\n\n'
        'La suscripción se renueva automáticamente al final de cada período mensual, al precio '
        'vigente en Google Play al momento de la renovación, salvo que la canceles antes de esa '
        'fecha. Sin una suscripción activa, la cuenta puede seguir usando RallyStats de forma '
        'gratuita e indefinida, con las limitaciones propias de esa versión (tope de partidos '
        'guardados y de sets por partido, sin pizarra táctica, estadísticas ni zona de destino).\n\n'
        'El plan base habilita 1 dispositivo con sesión simultánea; se pueden sumar hasta 3 '
        'complementos de "dispositivo adicional" (se compran de a uno, en orden), hasta un '
        'máximo de 4 dispositivos por cuenta.\n\n'
        'Podés cancelar la renovación automática en cualquier momento desde Google Play (la app '
        'incluye un acceso directo a "Gestionar o cancelar suscripción" en la pantalla "Mi '
        'suscripción"). La cancelación evita el próximo cobro, pero no genera un reembolso '
        'automático del período ya pagado: los reembolsos se rigen por las políticas propias de '
        'Google Play.',
  ),
  LegalSection(
    '05. Derecho de revocación (botón de arrepentimiento)',
    'Conforme al artículo 34 de la Ley N.º 24.240 y al artículo 1110 del Código Civil y '
        'Comercial, en las contrataciones a distancia el consumidor tiene derecho a revocar la '
        'aceptación durante el plazo de 10 días corridos contados desde la contratación, sin '
        'responsabilidad alguna.\n\n'
        'Como el cobro de la suscripción de RallyStats lo procesa Google Play y no el '
        'desarrollador directamente, este derecho se ejerce a través de los mecanismos de '
        'reembolso y cancelación que Google Play pone a disposición del comprador para ese '
        'período. Fuera de ese plazo, o si Google Play ya no ofrece el reembolso, la '
        'cancelación evita cobros futuros pero no genera devolución del período ya abonado, '
        'salvo que Google disponga lo contrario.',
  ),
  LegalSection(
    '06. Propiedad intelectual',
    'RallyStats, su código, diseño, marca y contenidos (con excepción de los datos que vos '
        'cargás) son propiedad de los desarrolladores y están protegidos por la normativa de '
        'propiedad intelectual aplicable. Se te concede una licencia personal, no exclusiva e '
        'intransferible para usar la app de acuerdo con estos Términos, mientras tengas una '
        'cuenta activa.\n\n'
        'Los datos que vos cargás (equipos, jugadores, partidos, jugadas de pizarra, fotos que '
        'subís) siguen siendo tuyos: RallyStats no reclama ninguna propiedad sobre ese '
        'contenido, y —como se explica en la Política de Privacidad— ni siquiera tiene acceso a '
        'él, porque se guarda localmente en tu dispositivo.',
  ),
  LegalSection(
    '07. Tus datos personales',
    'El tratamiento de tus datos personales (qué se guarda, dónde, con qué finalidad y qué '
        'derechos tenés al respecto) está descripto en detalle en la Política de Privacidad, '
        'que forma parte integral de estos Términos. Te recomendamos leerla junto con este '
        'documento antes de crear tu cuenta.',
  ),
  LegalSection(
    '08. Uso aceptable',
    'Al usar RallyStats te comprometés a no:\n\n'
        '• Usar la app para fines ilícitos o contrarios a estos Términos.\n'
        '• Intentar acceder sin autorización a cuentas de otros usuarios, ni a la '
        'infraestructura de backend (Firebase, RevenueCat) que usa la app.\n'
        '• Realizar ingeniería inversa, descompilar o modificar la app más allá de lo que la '
        'ley permita expresamente.\n'
        '• Compartir tu cuenta de forma que evada los límites de dispositivos de tu plan.\n\n'
        'El incumplimiento de este punto puede derivar en la suspensión o eliminación de tu '
        'cuenta.',
  ),
  LegalSection(
    '09. Disponibilidad del servicio, tus datos y limitación de responsabilidad',
    'RallyStats se ofrece "tal cual está" ("as is"). Hacemos un esfuerzo razonable para que la '
        'app funcione correctamente, pero no garantizamos que el servicio de login o de '
        'suscripción esté disponible sin interrupciones en todo momento, ya que dependen de '
        'proveedores externos (Firebase, Google Play, RevenueCat) fuera de nuestro control '
        'directo.\n\n'
        'Los datos de equipos, jugadores, partidos y pizarra se guardan únicamente en tu '
        'dispositivo, sin respaldo en ningún servidor nuestro. Si desinstalás la app, se rompe '
        'o perdés el dispositivo sin haber exportado tus partidos, esa información se pierde de '
        'forma irrecuperable — te recomendamos exportar los partidos importantes (función '
        'disponible en la app) como respaldo periódico.\n\n'
        'En la medida permitida por la ley aplicable, los desarrolladores no son responsables '
        'por daños indirectos derivados del uso de la app, ni por la pérdida de datos guardados '
        'localmente. Nada en este punto limita los derechos irrenunciables que la Ley N.º '
        '24.240 reconoce a los consumidores.',
  ),
  LegalSection(
    '10. Modificaciones a estos Términos',
    'Podemos actualizar estos Términos cuando cambie algo relevante del servicio (por ejemplo, '
        'una nueva función, un cambio en el esquema de suscripción o un nuevo proveedor). Vas a '
        'encontrar siempre la versión vigente dentro de la app, en esta misma pantalla, con la '
        'fecha de última actualización indicada arriba. Si el cambio es significativo, vamos a '
        'intentar avisarte dentro de la app antes de que entre en vigencia. Seguir usando la '
        'app después de un cambio implica aceptar la versión actualizada.',
  ),
  LegalSection(
    '11. Eliminación de cuenta',
    'Podés eliminar tu cuenta en cualquier momento desde la app (botón "Eliminar cuenta" en la '
        'pantalla principal), lo que borra tu email, contraseña y los registros de dispositivo '
        'y consentimiento asociados a la cuenta, de forma permanente e irreversible.\n\n'
        'Eliminar la cuenta no cancela automáticamente una suscripción premium activa en Google '
        'Play: esa suscripción se sigue renovando y cobrando hasta que la canceles vos mismo '
        'desde Google Play (la app te ofrece un acceso directo a esa gestión antes de '
        'confirmar la eliminación). Los datos de equipos, jugadores y partidos guardados '
        'localmente en el dispositivo no se borran al eliminar la cuenta, porque no forman '
        'parte de ella (ver sección 02 y la Política de Privacidad).',
  ),
  LegalSection(
    '12. Ley aplicable y jurisdicción',
    'Estos Términos se rigen por las leyes de la República Argentina. Para cualquier '
        'controversia derivada de la relación de consumo, y conforme al artículo 36 de la Ley '
        'N.º 24.240 y al artículo 2654 del Código Civil y Comercial, será competente, a '
        'elección del consumidor, el tribunal correspondiente a su domicilio real, sin '
        'perjuicio de otros fueros que la ley le autorice a elegir.',
  ),
  LegalSection(
    '13. Autoridad de aplicación en defensa del consumidor',
    'Sin perjuicio de la vía judicial, si tenés un reclamo como consumidor podés recurrir a la '
        'Dirección Nacional de Defensa del Consumidor (Ministerio de Economía de la Nación) o '
        'al organismo de defensa del consumidor de tu jurisdicción provincial o de la Ciudad '
        'Autónoma de Buenos Aires.',
  ),
  LegalSection(
    '14. Contacto',
    'Para consultas sobre estos Términos, escribinos a ezecastiglione18@gmail.com o a '
        'federicotomasperez2002@outlook.com.',
  ),
];
