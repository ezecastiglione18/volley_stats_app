# Play Console → Contenido de la app → Seguridad de los datos (versión con la nube)

Redactado el 23/10/2026 para la versión que trae "Partidos y equipos en la nube" (sección 3, Etapa 2).
**Actualizado el 26/10/2026** (política 2.1): la nube suma las jugadas de la pizarra y el fixture. No hay
tipos de datos nuevos: entran en "Otro contenido generado por usuarios", que ya estaba declarado. En Play
Console solo cambia la descripción de ese tipo (si el formulario la pide) y el texto corto; el resto queda
igual. Lo de **nuevo** respecto de la declaración del 23/10 está marcado. Lo que ya estaba declarado (email,
nombre, ids de dispositivo, historial de compras vía RevenueCat) no cambia. Revisarlo contra el
formulario real antes de enviarlo: Play cambia los nombres de las opciones cada tanto.

## Preguntas generales

| Pregunta | Respuesta |
|---|---|
| ¿La app recopila o comparte alguno de los tipos de datos del usuario requeridos? | Sí |
| ¿Todos los datos recopilados se encriptan en tránsito? | Sí (HTTPS/TLS de los SDK de Firebase y RevenueCat) |
| ¿Ofrecés una forma de que los usuarios soliciten que se borren sus datos? | Sí: desde la app (Configuración → Eliminar cuenta, que borra también la copia de la nube) y por email. Además, apagar la nube permite borrar solo la copia de la nube |

## Tipos de datos

Respuestas cargadas en Play (secciones 3 y 4, 24/10/2026). En los 7 tipos: **Recopilados** (no
"Compartidos"), **no** efímeros; la pregunta "¿Para qué se comparten?" no aparece porque no se comparte nada.

| Categoría → tipo | ¿Necesario u opcional? | ¿Por qué se recopilan? |
|---|---|---|
| Información personal → Nombre | Necesario (nombre y apellido de la cuenta; los nombres de jugadores con la nube son el uso opcional) | Funciones de la app, Administración de la cuenta |
| Información personal → Dirección de correo electrónico | Necesario | Funciones de la app, Administración de la cuenta |
| Información personal → ID de usuario | Necesario | Funciones de la app, Administración de la cuenta |
| **Información personal → Otra información** (fechas de nacimiento, edad, número, posición, medidas y mano hábil de los jugadores) | **Opcional** (solo si se activa la nube) | Funciones de la app |
| Información financiera → Historial de compras | Necesario | Funciones de la app (estado de la suscripción) |
| Actividad en apps → Otro contenido generado por usuarios (partidos: registro jugada por jugada y notas; equipos; **jugadas de la pizarra y fixture**, desde el 26/10) | Opcional (solo si se activa la nube) | Funciones de la app |
| Dispositivo u otros IDs | Necesario | Administración de la cuenta; Seguridad, cumplimiento y prevención de fraudes (límite de dispositivos) |

- Firebase (Google) y RevenueCat son **proveedores de servicios**: para Play eso no cuenta como "compartir".
- Las fotos de los jugadores **no** se recopilan (nunca salen del dispositivo).
- Ningún dato se usa para publicidad, analítica ni personalización.
- Para cada tipo nuevo, Play pregunta si se procesa de forma efímera: **No** (se guarda hasta que el
  usuario lo borra).

## Texto corto (para la ficha o para responder a Play si lo pide)

> RallyStats guarda tus partidos, equipos, jugadores, jugadas y fixture en tu dispositivo. Si activás la
> nube, los partidos terminados, los equipos con sus jugadores (nombres, números, posiciones, medidas y
> fechas de nacimiento, sin fotos), las jugadas de la pizarra y el fixture se guardan también en tu cuenta
> para verlos en todos tus dispositivos. No se usan para nada más, no se comparten y solo tu cuenta puede verlos. Podés apagar la
> nube y borrar la copia cuando quieras, y eliminar tu cuenta desde la app borra todo.

## Sección 2 · Recopilación y seguridad de los datos (respuestas)

| Pregunta | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos requeridos? | Sí |
| ¿Todos los datos se encriptan en tránsito? | Sí |
| Métodos de creación de cuentas | Solo **Nombre de usuario y contraseña** (el email es el usuario) |
| Vínculo para solicitar que se borre la cuenta | `https://volleystatsapp-be835.web.app/eliminar-cuenta` (`hosting/eliminar-cuenta.html`, con `cleanUrls`, se publica con `firebase deploy --only hosting`) |
| ¿Pones a disposición un método para borrar datos sin borrar la cuenta? | **Sí** (apagar la nube borrando la copia, o por email) |
| URL de eliminación de datos | La misma página (sección "Borrar solo tus datos") |
| ¿Los usuarios pueden acceder con cuentas creadas fuera de la app? | No |
| Política de Familias / MASA / insignia | No aplica / No / No |
