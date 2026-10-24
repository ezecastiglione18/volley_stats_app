# Play Console → Contenido de la app → Seguridad de los datos (versión con la nube)

Redactado el 23/10/2026 para la versión que trae "Partidos y equipos en la nube" (sección 3, Etapa 2).
Lo de **nuevo** respecto de la declaración actual está marcado. Lo que ya estaba declarado (email,
nombre, ids de dispositivo, historial de compras vía RevenueCat) no cambia. Revisarlo contra el
formulario real antes de enviarlo: Play cambia los nombres de las opciones cada tanto.

## Preguntas generales

| Pregunta | Respuesta |
|---|---|
| ¿La app recopila o comparte alguno de los tipos de datos del usuario requeridos? | Sí |
| ¿Todos los datos recopilados se encriptan en tránsito? | Sí (HTTPS/TLS de los SDK de Firebase y RevenueCat) |
| ¿Ofrecés una forma de que los usuarios soliciten que se borren sus datos? | Sí: desde la app (Configuración → Eliminar cuenta, que borra también la copia de la nube) y por email. Además, apagar la nube permite borrar solo la copia de la nube |

## Tipos de datos

| Categoría → tipo | Recopilado | Compartido | ¿Opcional? | Finalidad |
|---|---|---|---|---|
| Información personal → Nombre | Sí | No | Requerido (cuenta) / **opcional (nombres de jugadores, solo con la nube)** | Funcionalidad de la app, Administración de la cuenta |
| Información personal → Dirección de correo electrónico | Sí | No | Requerido | Administración de la cuenta |
| Información personal → IDs de usuario | Sí | No | Requerido | Administración de la cuenta |
| **Información personal → Otra información** (fechas de nacimiento, edad, número, posición, medidas y mano hábil de los jugadores) | **Sí** | No | **Opcional** (solo si se activa la nube) | Funcionalidad de la app |
| **Actividad en la app → Otro contenido generado por el usuario** (partidos: registro jugada por jugada y notas; equipos) | **Sí** | No | **Opcional** (solo si se activa la nube) | Funcionalidad de la app |
| Dispositivo u otros IDs | Sí | No | Requerido | Administración de la cuenta (límite de dispositivos) |
| Información financiera → Historial de compras | (como hoy) | No | — | Funcionalidad de la app (estado de la suscripción) |

- Firebase (Google) y RevenueCat son **proveedores de servicios**: para Play eso no cuenta como "compartir".
- Las fotos de los jugadores **no** se recopilan (nunca salen del dispositivo).
- Ningún dato se usa para publicidad, analítica ni personalización.
- Para cada tipo nuevo, Play pregunta si se procesa de forma efímera: **No** (se guarda hasta que el
  usuario lo borra).

## Texto corto (para la ficha o para responder a Play si lo pide)

> RallyStats guarda tus partidos, equipos y jugadores en tu dispositivo. Si activás "Partidos y equipos
> en la nube", los partidos terminados y los equipos con sus jugadores (nombres, números, posiciones,
> medidas y fechas de nacimiento, sin fotos) se guardan también en tu cuenta para verlos en todos tus
> dispositivos. No se usan para nada más, no se comparten y solo tu cuenta puede verlos. Podés apagar la
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
