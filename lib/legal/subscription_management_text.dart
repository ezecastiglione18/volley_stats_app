import 'legal_section.dart';

/// Texto de la guía "Cómo gestionar o cancelar tu suscripción", mostrada
/// desde `SubscriptionScreen` con `showLegalDocumentDialog` (igual que la
/// política de privacidad, pero sin botón "Aceptar": es puramente
/// informativa, no pide ningún consentimiento).
const kSubscriptionManagementSubtitle =
    'Plan premium y dispositivos adicionales: cómo administrarlos sin sorpresas';

const List<LegalSection> subscriptionManagementSections = [
  LegalSection(
    'En síntesis',
    'Tu plan premium y cada complemento de dispositivo adicional son suscripciones '
        'independientes de Google Play: se compran y se cancelan por separado. Quien las '
        'administra es Google Play, no RallyStats — la app no puede cancelar nada por vos, sólo '
        'te lleva directo a la pantalla correcta. Cancelar no te deja sin nada de un día para el '
        'otro: seguís teniendo el beneficio hasta que termina el período que ya pagaste. Y si '
        'tenés más de un complemento activo, para que todo funcione bien conviene darlos de baja '
        'en el orden correcto — lo explicamos más abajo.',
  ),
  LegalSection(
    '1. Cancelar el plan completo',
    'Si querés dejar de tener premium por completo (perdés pizarra táctica, estadísticas, zona '
        'de destino, y vuelven a aplicarse los topes de partidos y sets guardados), tocá '
        '"Gestionar o cancelar suscripción" en la pantalla de "Mi suscripción": te lleva directo '
        'a Google Play, a la gestión de tu plan base. Ahí confirmás la cancelación con los '
        'controles de Google.\n\n'
        'También podés llegar al mismo lugar sin pasar por la app: abrí Play Store → tocá tu '
        'foto de perfil, arriba a la derecha → Pagos y suscripciones → Suscripciones.',
  ),
  LegalSection(
    '2. Dar de baja solo un dispositivo adicional (sin cancelar todo)',
    'Si lo que querés es bajar la cantidad de dispositivos habilitados pero seguir teniendo '
        'premium, no canceles el plan base: cada complemento de dispositivo adicional es una '
        'suscripción aparte, y hoy no hay un botón directo en la app para cancelar una en '
        'particular.\n\n'
        'Para hacerlo: abrí Play Store → tu foto de perfil → Pagos y suscripciones → '
        'Suscripciones. Ahí vas a ver el plan base y cada complemento como líneas separadas '
        '("Dispositivo Adicional", "Dispositivo Adicional 2", "Dispositivo Adicional 3"). '
        'Cancelá sólo el que corresponda; el resto sigue activo sin cambios.',
  ),
  LegalSection(
    '3. Muy importante: en qué orden cancelar si tenés más de un complemento',
    'Los complementos se habilitan siempre en el mismo orden: primero, segundo, tercero. Si '
        'tenés más de uno activo y querés dar de baja alguno, cancelá siempre el último que '
        'compraste — nunca uno del medio dejando uno más nuevo activo.\n\n'
        'Ejemplo: si tenés los 3 complementos activos y querés bajar a 2 dispositivos '
        'adicionales, cancelá el complemento 3 (el último), no el 1 ni el 2.\n\n'
        'Si cancelás fuera de ese orden, la pantalla de "Mi suscripción" puede llegar a '
        'ofrecerte para comprar un complemento que en los hechos ya tenés activo, lo cual puede '
        'generar confusión o que termines pagando de más por algo que no sumó ningún dispositivo '
        'nuevo. Cancelar siempre del más nuevo al más viejo evita este problema.',
  ),
  LegalSection(
    '4. Cuándo se aplica el cambio',
    'Cancelar no es instantáneo: seguís teniendo el beneficio (el dispositivo habilitado, o el '
        'plan premium) hasta el final del período que ya pagaste — recién ahí deja de contar. '
        'Además, la app sólo revisa el estado actualizado en momentos puntuales (al iniciar '
        'sesión, al volver a abrirla, o al cerrar esta misma pantalla de suscripción), así que '
        'puede haber una demora corta entre que el período termina y que la app lo refleja.',
  ),
  LegalSection(
    '5. Qué pasa con los dispositivos que ya tenían la sesión abierta',
    'Bajar la cantidad de dispositivos habilitados no cierra la sesión de nadie en el momento. '
        'Los dispositivos que ya estaban conectados siguen funcionando con normalidad; recién la '
        'próxima vez que alguno de ellos abra (o vuelva a abrir) la app, si ya no entra dentro '
        'del nuevo límite, se cierra sesión ahí automáticamente — empezando siempre por el que '
        'se conectó más recientemente. Ese dispositivo va a ver un aviso explicando por qué, con '
        'la opción de volver a entrar en otro dispositivo con lugar disponible, o de sumar un '
        'complemento para recuperarlo.',
  ),
  LegalSection(
    '6. Si te arrepentís',
    'Mientras el período ya pagado no haya terminado, podés volver a activar lo que cancelaste '
        'desde la misma pantalla de Play Store, sin perder nada. No hace falta hacer nada '
        'especial del lado de la app: la próxima vez que revise el estado de tu cuenta lo va a '
        'ver activo de nuevo.',
  ),
  LegalSection(
    '7. ¿Necesitás ayuda?',
    'Si cancelaste algo y después de un rato la app no refleja lo que esperabas, o tenés '
        'cualquier duda sobre tu suscripción o tus dispositivos habilitados, escribinos a '
        'ezecastiglione18@gmail.com o a federicotomasperez2002@outlook.com.',
  ),
];
