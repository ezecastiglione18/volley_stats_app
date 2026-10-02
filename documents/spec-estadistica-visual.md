# Spec — Estadística visual (Gráficos + Mapas)

**Estado:** aprobada el 29/09/2026 · **Etapas 1 y 2 implementadas el 02/10/2026** (ver `CLAUDE.md` → Trabajo planificado) · pendiente la Etapa 3.

**Documentos que la acompañan:**

- `documents/RallyStats-Propuesta-Estadistica-Visual.pdf`: el boceto visual con datos de ejemplo (maquetas de pantalla, planilla por jugador, todos los gráficos). Leerlo completo antes de empezar: esta spec define las reglas y el PDF muestra cómo tiene que verse.
- `tool/generate_propuesta_estadistica.dart`: el script que genera ese PDF. **Es la referencia de dibujo.** `drawShot()` tiene los 5 trazos, `CourtMap` la cancha compacta, y `divergingBars`, `groupedPctBars`, `wormChart` y `stackedBar` los gráficos. Esa geometría se reproduce tal cual en `CustomPainter` (pantalla) y en `pdf_report_service.dart` (reporte). Se regenera con `dart run tool/generate_propuesta_estadistica.dart` y solo corre en Windows (usa Arial de `C:\Windows\Fonts`).

Si algo de esta spec contradice al PDF, **manda la spec**.

---

## 1. Decisiones tomadas

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Distinguir afuera y red dentro de NN? | **Sí**, deducido del lugar donde se toca la cancha en la carga (Etapa 3). Sin pasos extra. |
| 2 | ¿Origen del toque deducido o tocado? | **Deducido por defecto + segundo toque opcional** en la mitad propia de la cancha (Etapa 3). |
| 3 | ¿Bloqueado y red como trazos propios? | **Sí, 5 trazos**: punto, adentro, afuera, bloqueado, red. Si NN no tiene el dato afuera/red (partidos viejos o sin toque en cancha), se usa un 6º trazo de **"error" genérico**. |
| 4 | Vista por defecto de la pestaña Mapas | **Mapa con resumen numérico**. "Ver como tabla" queda a un toque. |
| 5 | Por dónde arrancar | **Etapa 1** (gráficos de equipo). Después Etapa 2 (mapas con datos de hoy) y Etapa 3 (carga precisa). |

## 2. Reglas generales (valen para todas las etapas)

- **Todo es derivado del log de eventos.** Igual que `StatsEngine.compute`: nada de contadores incrementales ni campos cacheados en los modelos. Se calcula al abrir la pantalla (un partido tiene unos pocos cientos de eventos).
- **Filtro de set:** todas las funciones nuevas aceptan `{int? setNumber}` con la misma semántica que `StatsEngine.compute` (`null` = partido completo).
- **Sin dependencias nuevas.** Los gráficos se dibujan con `CustomPainter`, como la pizarra (`WhiteboardPainter`). No agregar `fl_chart` ni similares.
- **Separar datos de dibujo:** los cálculos van en `lib/services/stats_engine.dart` (Dart puro, testeable sin UI) y devuelven clases de datos simples en `lib/models/stat_line.dart` o en un archivo de modelos nuevo. Los painters solo dibujan.
- **Modo claro/oscuro:** la app tiene los dos (`ThemeController`). Ejes, grilla y texto salen de `Theme.of(context).colorScheme` y de `surfaceAltColor(context)`. Los colores "de dato" son fijos en los dos modos:
  - positivo / punto: `0xFF1E88E5` (el color de PP en `grade_labels.dart`);
  - negativo / error: `0xFFE64A3B` (el color de NN);
  - adentro sin punto: `0xFF475569`;
  - bloqueado: `0xFFE39A12`;
  - side-out: `AppColors.primaryLight` en modo claro y `AppColors.accentDark` en oscuro, porque el navy no se ve sobre fondo oscuro;
  - break-point: el acento (`colorScheme.secondary`);
  - recepción por calificación: los colores de `receptionGrades` en `grade_labels.dart`.
- **Premium:** no hace falta lógica nueva. Todo vive dentro de `MatchSummaryScreen`, que ya resuelve el gate (premium o cupo de estadística gratis) antes de construir el `Scaffold`.
- **Estilo:** comentarios y textos de UI en español rioplatense, como el resto del repo. Modelos con `toJson`/`fromJson` a mano (ver CLAUDE.md), nunca `build_runner`.

## 3. Definiciones de datos (Etapa 1)

### 3.1 Rally y quién sacaba

- Un **rally** es un grupo de `RallyEvent` de un mismo set con el mismo `rallyNumber`.
- Su **evento de cierre** es el que tiene `endsRally == true && pointWinner != null`. Hay exactamente uno por rally terminado. Si el último rally de un set en curso no tiene cierre, **se ignora**.
- **Quién sacaba** en el rally es el `servingTeamBefore` del evento de cierre.
- **Side-out:** un rally en el que sacaba el rival. Se gana si `pointWinner == own`.
- **Break-point:** un rally en el que sacaba el equipo propio. Se gana si `pointWinner == own`.
- **% side-out** = side-outs ganados / rallies con saque rival. **% break-point** = break-points ganados / rallies con saque propio. Si el denominador es 0, se muestra "—" (no 0 %).

### 3.2 Rotación de cada rally (P1–P6)

La rotación que cuenta es la **vigente durante el rally**, antes de que un side-out ganado la haga avanzar. Algoritmo, por cada set:

1. `offset = 0` y `serving = set.startingServer`.
2. Se recorren los rallies en orden de `rallyNumber`. **Antes** de procesar el rally `r`, se suman al offset los `steps` de todos los `set.manualRotations` con `rallyNumber == r`, módulo 6 (usar `((x % 6) + 6) % 6`). El `rallyNumber` de una rotación manual es el rally que venía a continuación (`MatchController.rotateManually` guarda `_rallyCounter`). **Ojo:** `MatchController.resume` aplica las rotaciones manuales todas juntas al final, porque solo le importa la rotación final. Acá no sirve eso: hay que aplicarlas en su rally.
3. Se registra el rally con el `offset` actual.
4. Si `pointWinner != serving` (se ganó o perdió el saque): si ganó el equipo propio, `offset = (offset + 1) % 6`. En cualquier caso, `serving = pointWinner`. Es la misma regla que `MatchController.resume`.

**Etiqueta de la rotación.** Se usa la convención de la captura 2 (estilo DataVolley): **P = posición en la cancha del armador**.

- Slot del armador `s` = índice en `set.startingOrderOwn` del **único** jugador con `position == PlayerPosition.armador`. Se busca en `match.ownRoster`.
- Posición en la cancha = `((s - offset) % 6 + 6) % 6 + 1`, la misma fórmula que `MatchController._courtPositionOfSlot`.
- Se usa el slot, no el id del jugador: si el armador sale por un cambio, su reemplazo ocupa el mismo slot y la rotación sigue siendo la misma.
- Si en `startingOrderOwn` hay **cero o más de un** armador, ese set usa una etiqueta de respaldo: **"R1–R6"**, donde `R = offset + 1` (R1 es la formación inicial). Si la selección mezcla sets con P y sets con R, se muestra una sola tabla con las filas "P" y una nota de que el set N se agrupó aparte por no tener un armador identificable. En la práctica casi siempre hay uno.
- Las rotaciones se acumulan entre sets por etiqueta (el P1 del set 1 se suma con el P1 del set 2).

### 3.3 A qué columna va cada rally (tabla de rotaciones y "Origen de los puntos")

Cada rally cerrado se clasifica **por su evento de cierre**, en una sola categoría:

| Evento de cierre | Categoría | Columna de la tabla | Ganado / perdido |
|---|---|---|---|
| `serve` propio, grade PP | Punto de saque | +Pts, Saque Pts | ganado |
| `serve` propio, grade NN | Error de saque | −Err, Saque Err | perdido |
| `reception` propia, grade NN | Error de recepción | −Err, Rec. Err | perdido |
| `attack` o `counter` propio, PP | Punto de ataque / contra | +Pts, Ataque Pts | ganado |
| `attack` o `counter` propio, NN | Error de ataque | −Err, Ataque Err | perdido |
| `attack` o `counter` propio, BLOQ | Bloqueado | −Err, Ataque Bl | perdido |
| `block` | Punto de bloqueo | +Pts, Bloq Tot | ganado |
| `genericError` | Error genérico | −Err, Err gen. | perdido |
| `opponentPoint` | Punto directo rival | Adv −Pts | perdido |
| `opponentError` | Error rival | Adv +Err | ganado |
| `sanction` con `pointWinner == own` (sancionaron al rival) | Error rival | Adv +Err | ganado |
| `sanction` con `pointWinner == rival` (sancionaron al equipo propio) | Error genérico | −Err, Err gen. | perdido |

- "Ataque" junta K1 (`attack`) y K2+ (`counter`) en la tabla de rotaciones, como la captura 2. En "Origen de los puntos" van separados en Ataque y Contra.
- Si aparece un evento de cierre que no está en la tabla, se cuenta solo en G-P y en ganados/perdidos, sin columna. Hay que agregar un `assert` para detectarlo en desarrollo.
- **Invariante (va en un test):** `G-P = (+Pts + Adv+Err) − (Adv−Pts + −Err)`. Además, sumando todas las rotaciones de un set, `G-P = ownScore − rivalScore` de ese set.
- En la tabla, los ceros se muestran como "." (como la captura 2), y "Adv −Pts" y "−Err" van con signo menos.

### 3.4 Evolución del marcador

- Por set: la lista de eventos de cierre en orden, con `diff = ownScoreAfter − rivalScoreAfter`.
- **Rachas:** secuencias de 4 o más puntos seguidos del mismo equipo. Se etiquetan "Racha 5-0" o "Racha 0-4".
- Con "partido completo" se muestra un gráfico por set, uno debajo del otro (small multiples). Nunca se concatenan sets en un solo eje.
- Opcional, si entra fácil: marcas finitas en los rallies donde hubo un cambio de jugador (`SubstitutionEvent.rallyNumber`, excluyendo `isLiberoAction`).

### 3.5 Eficiencia de ataque, recepción, mapa de calor y tablero

- **Eficiencia de ataque por jugador** = `(PP − NN − BLOQ) / total` sobre `ataque + contra` de `PlayerStatLine`, que ya existe. Solo jugadores con total > 0, ordenados de mayor a menor. A la derecha: "X pts · Y err · Z tot".
- **Recepción por jugador:** barra al 100 % con PP / P / ! / N / V- / NN de `ReceptionStats`. A la derecha, `efficiency` (la fórmula actual, (PP+P)/total) y el total. Solo jugadores con total > 0.
- **Mapa de calor:** usa `StatsEngine.computeZones`, que ya existe. Tiene un selector Saque / Ataque / Contra. Si hay datos de las zonas 7–9 (`ZoneStats.hasMiddleZoneData`), la grilla es de 3 filas: `1 6 5` / `9 8 7` / `2 3 4` (fondo arriba, red abajo, como `HitZonePicker`); si no, `1 6 5` / `2 3 4`. En cada celda va la cantidad (la intensidad del color es cantidad / máximo) y el % que terminó en punto (PP / total). Si ningún set de la selección registró zona, se oculta la tarjeta y se muestra el aviso "No hay zonas de destino registradas".
- **Tablero rápido** (4 indicadores arriba de todo):
  - % side-out;
  - % break-point;
  - eficiencia de ataque del equipo (misma fórmula, fila `team`);
  - errores no forzados = saque NN + ataque NN + contra NN + errores genéricos. **No** incluye BLOQ ni recepción NN.

## 4. Etapa 1 — Pestaña "Gráficos" (lo próximo a implementar)

### 4.1 Datos (`stats_engine.dart`)

Funciones nuevas sugeridas (los nombres son orientativos):

- `static RotationStats computeRotations(VolleyMatch match, {int? setNumber})`: filas P1–P6 (o R1–R6) con todas las columnas de 3.3, más rallies con saque propio/rival y ganados de cada tipo (para side-out y break por rotación). También los totales del equipo para el tablero.
- `static List<SetTimeline> computeTimelines(VolleyMatch match, {int? setNumber})`: una línea por set (3.4).
- `static PointOriginStats computePointOrigin(VolleyMatch match, {int? setNumber})`: ganados y perdidos por categoría (3.3).

Eficiencia, recepción y mapa de calor salen de `compute` y `computeZones`, que ya existen.

### 4.2 Pantalla (`match_summary_screen.dart`)

- Hoy el `Scaffold` tiene un `ListView` con la cabecera del partido, el selector de set, `_StatsTable` y la estadística del rival.
- Pasa a tener un `TabBar` en el `AppBar` con dos pestañas: **Tabla** (todo el contenido actual, sin cambios) y **Gráficos**. En la Etapa 2 se agrega **Mapas** en el medio: Tabla · Mapas · Gráficos.
- `_selectedSet` queda en el `State` padre y lo comparten las pestañas. El selector de set se muestra arriba de cada pestaña; conviene extraerlo a un widget.
- La pestaña Gráficos es un `ListView` de tarjetas en este orden:
  1. tablero rápido;
  2. diferencia por rotación (barras);
  3. tabla de rotaciones (con scroll horizontal si no entra);
  4. side-out y break por rotación;
  5. evolución del marcador;
  6. origen de los puntos;
  7. eficiencia de ataque;
  8. recepción;
  9. mapa de calor.
- Cada tarjeta tiene título y una línea corta de ayuda (los textos del PDF, sección 6–7, sirven de base). Tocar una tarjeta la abre a pantalla completa, lo que sirve en celulares chicos.
- Los painters van en `lib/widgets/charts/`, un archivo por gráfico. Cada uno es un `CustomPainter` que recibe los datos ya calculados y los colores resueltos desde el tema.
- **Estados vacíos:** partido o set sin rallies cerrados → "Todavía no hay puntos cargados" en vez de gráficos vacíos.

### 4.3 PDF (`pdf_report_service.dart`)

- Agregar después de lo actual una sección "Gráficos" con el tablero, la tabla y las barras de rotación, side-out/break, la evolución del marcador (partido completo: un gráfico por set), el origen de los puntos, la eficiencia y la recepción. El reporte ya es A4 apaisado.
- Para dibujar con `package:pdf`, usar el patrón del widget `Draw` del script de referencia (un `pw.Widget` con `layout` y `paint` propios, para tener `context` y poder medir y dibujar texto). `pw.CustomPaint` no da acceso a las fuentes.
- Envolver cada gráfico en `pw.Inseparable`, como ya se hace con la tabla de sets, para que no se corte entre hojas.

### 4.4 Tests (`test/`)

Usar el helper de `test/match_controller_test.dart` (`_newController`, roster con A1 como armador en slot 0) y cargar rallies con `logServe` / `logReception` / `logAttack` / `logBlockPoint` / `logGenericError` / `logOpponentPoint` / `logOpponentError` / `rotateManually`. Si el archivo se hace muy largo, crear `test/stats_charts_test.dart` con su propio helper, copiando el `setUpAll` del mock de `path_provider`. Casos mínimos:

1. Rallies con `offset 0` → P1 (armador en slot 0). Después de un side-out ganado → P6. Después de otro → P5.
2. Una rotación manual se aplica **desde su rally** y no antes: los rallies anteriores quedan en la rotación vieja.
3. Invariante de 3.3 por fila, y la suma de G-P por set igual a `ownScore − rivalScore`.
4. Conteos de side-out y break en un set armado a mano, con denominadores conocidos.
5. Los `diff` del timeline coinciden con `ownScoreAfter − rivalScoreAfter`, y se detecta una racha de 4.
6. Sanción con punto: a favor → "Error rival"; en contra → "Err gen.".
7. Set sin armador identificable → etiquetas R1–R6.
8. Filtro `setNumber`: solo cuenta ese set.
9. Widget test: la pestaña Gráficos aparece y muestra el tablero con un partido simulado.

### 4.5 Cómo verificar a mano

- En la pantalla en vivo, el menú tiene **"Simular resto del set"** (`MatchController.simulateRestOfSet`): carga un set completo con jugadas aleatorias, incluidos bloqueos, errores y zonas.
- Simular 3 sets, abrir Estadísticas → Gráficos y revisar en **modo claro y oscuro** y en un ancho de celular chico.
- Compartir el PDF y revisar que ningún gráfico se corte entre hojas.

### 4.6 Cierre de la etapa

Seguir el "Proceso de release" de `CLAUDE.md`:

- manual (`tool/generate_manual.dart`, sección del resumen/estadísticas) y regenerarlo;
- README (lista de funcionalidades);
- `flutter analyze` sin issues nuevos;
- `flutter test`;
- builds.

## 5. Etapa 2 — Pestaña "Mapas" con los datos de hoy

### 5.1 Sistema de coordenadas (el mismo para las etapas 2 y 3)

Coordenadas normalizadas de cancha completa, vista desde el banco propio mirando al rival:

- `x`: 0.0 = línea lateral izquierda, 1.0 = derecha (9 m).
- `y`: 0.0 = fondo rival, **0.5 = red**, 1.0 = fondo propio (18 m).
- Valores fuera de [0, 1] = fuera de la cancha (hace falta para "afuera" y para el origen del saque).
- Zonas rivales, vistas así: fila de la red (`1/3 ≤ y < 0.5`) = **2 · 3 · 4** de izquierda a derecha; fondo (`y < 1/3`) = **1 · 6 · 5**. Con 9 zonas, la mitad rival se divide en tres bandas de 3 m: `y < 1/6` → 1·6·5, `1/6 ≤ y < 1/3` → 9·8·7, `1/3 ≤ y < 0.5` → 2·3·4. Es consistente con `HitZonePicker`.
- Zonas propias (para el origen), mirando a la red: adelante 4 · 3 · 2 de izquierda a derecha, atrás 5 · 6 · 1.

**Dibujo compacto** (como `CourtMap` del script): la mitad rival se dibuja a escala real (cuadrada) y la mitad propia comprimida al 50 %, con un margen para "afuera" (arriba 0.17, costados 0.12 y abajo 0.15 del ancho de la cancha).

### 5.2 Un toque = una flecha (`StatsEngine.computeShots`)

Para cada `RallyEvent` propio de fase `serve`, `attack` o `counter`, con jugador, que tenga destino:

- **Destino:**
  - Si hay `targetX`/`targetY` (Etapa 3), se usa eso.
  - Si no, el centro de la zona (`targetZone`), según si **ese set** usaba 9 zonas (`MatchSet.nineHitZones`). Con 6 zonas, los centros son 1:(1/6, 1/6), 6:(1/2, 1/6), 5:(5/6, 1/6), 2:(1/6, 5/12), 3:(1/2, 5/12), 4:(5/6, 5/12). Con 9, el centro de cada banda.
  - Al centro de zona se le suma un desvío **determinístico** (derivado de un hash de `event.id`, ±0.05) para que las flechas no se encimen y el dibujo sea siempre igual.
  - Sin zona y sin punto → no se dibuja, y el resumen dice "N toques sin zona".
- **Origen:**
  - Si hay `originX`/`originY` (Etapa 3), se usa eso.
  - Si no, se deduce. Para saber si el jugador estaba adelante o atrás en ese rally hay que reproducir la rotación (3.2) **y los cambios** (`SubstitutionEvent.slotIndex` / `rallyNumber`, igual que `MatchController`), y así saber qué slot ocupaba. Su posición en la cancha es `((slot - offset) % 6 + 6) % 6 + 1`, y las posiciones 2, 3 y 4 son la fila de adelante.

  | Caso | Origen (x, y) |
  |---|---|
  | Saque | (0.82, 1.06): detrás del fondo, del lado de la zona 1 |
  | Punta receptor adelante / atrás | zona 4 (0.13, 0.60) / pipe por zona 6 (0.50, 0.77) |
  | Opuesto adelante / atrás | zona 2 (0.87, 0.60) / zona 1 (0.85, 0.76) |
  | Central adelante / atrás | zona 3 (0.50, 0.59) / zona 6 (0.50, 0.77) |
  | Armador (segunda pelota) | (0.80, 0.56), pegado a la red del lado de la zona 2 |
  | Universal, líbero o sin posición | según la posición en la cancha de ese rally: 4 (0.13, 0.60), 3 (0.50, 0.59), 2 (0.87, 0.60), 5 (0.15, 0.76), 6 (0.50, 0.77), 1 (0.85, 0.76) |

- **Resultado → trazo** (los mismos 5 del PDF, más el genérico de la decisión 3):

  | grade | missType | Trazo |
  |---|---|---|
  | PP | — | **Punto:** línea continua azul con punta de flecha |
  | P o N | — | **Adentro:** punteada gris con punta |
  | BLOQ | — | **Bloqueado:** continua naranja que termina en la red con una barra perpendicular (el destino se fuerza a `y = 0.52`) |
  | NN | `out` | **Afuera:** doble línea punteada roja con punta |
  | NN | `net` | **Red:** punteado fino rojo que termina en la red con una cruz (el destino se fuerza a `y = 0.503`) |
  | NN | `null` | **Error genérico:** punteada roja simple con punta, hacia el destino registrado |

  En todos los casos el origen lleva un punto gris chico. Los tamaños y trazos exactos están en `drawShot()` del script.

### 5.3 Pantalla y PDF

- **Pestaña Mapas** (maqueta en la página 6 del PDF), de arriba hacia abajo:
  - selector de set;
  - chips de jugador: solo los que tienen toques del fundamento elegido, en orden de número;
  - segmentado Saque / Ataque / Contra;
  - la cancha con las flechas;
  - leyenda fija;
  - resumen: Total · Puntos · Adentro · Errores · Eficiencia;
  - "Ver como tabla por zona", que despliega la tabla por zona del jugador (`ZoneStats.*ByZoneByPlayer`).
- **Vista por defecto: mapa con resumen** (decisión 4).
- Tocar una flecha muestra set, marcador (`ownScoreAfter`–`rivalScoreAfter`) y calificación. El hit-test se hace por distancia al segmento.
- **PDF:** "Planilla por jugador" (páginas 4–5 del PDF): una fila por jugador con toques y tres canchas (Saque / Ataque K1 / Contraataque K2+), con la línea "tot · pts · err · Ef" debajo de cada una.

### 5.4 Tests

- Origen deducido para punta, opuesto y central, adelante y atrás, incluyendo un caso con un cambio de jugador en el medio.
- Centro de zona más desvío determinístico: dos llamadas dan exactamente el mismo resultado.
- Correspondencia calificación → trazo, incluido NN sin missType → genérico.

## 6. Etapa 3 — Carga precisa

### 6.1 Modelo (`rally_event.dart`)

Campos opcionales nuevos, siguiendo el patrón de `targetZone` en `toJson`/`fromJson` (`null` si no están, para leer partidos viejos):

- `double? targetX, targetY`: destino tocado, en las coordenadas de 5.1.
- `double? originX, originY`: origen tocado (opcional).
- `String? missType`: `'out'` o `'net'`, solo con grade NN. Constantes en una clase `MissType`, como `RivalAction`.

`targetZone` **se sigue guardando**, calculado a partir del punto cuando cae dentro de la mitad rival, para que las tablas de zona y `computeZones` sigan funcionando sin cambios. Si el punto cae afuera o en la red, `targetZone = null`.

### 6.2 Selector (`hit_zone_picker.dart` y `touch_dialog.dart`)

- La grilla se reemplaza por el dibujo de la cancha compacta: la mitad rival con margen de "afuera" y la mitad propia comprimida.
- **No hay modos.** Cada toque se clasifica según dónde cae:
  - en la mitad rival → **destino** (adentro);
  - en el margen de afuera (superior o laterales) → **destino afuera** (`missType = out`);
  - en la franja de la red (`|y − 0.5| < 0.03`, que se dibuja como una banda gruesa tocable) → **red** (`missType = net`);
  - en la mitad propia → **origen** (opcional).
- Volver a tocar reemplaza el destino o el origen. Se muestran los dos puntos y la flecha provisoria. Hay un botón "Quitar" para cada uno.
- Si hay afuera o red y la calificación elegida no es NN, se muestra un aviso no bloqueante ("¿Seguro? La pelota fue afuera"), pero se deja confirmar igual.
- Todo sigue siendo **opcional** y detrás del mismo interruptor por set (`MatchSet.trackHitZones`, gate premium en `lineup_screen.dart`). Con 9 zonas, la zona calculada usa las bandas de 5.1.
- `logServe` / `logAttack` / `logCounter` en `match_controller.dart` suman los parámetros nuevos. `simulateOnePoint` tiene que generar puntos coherentes con la calificación, para poder probar los mapas con "Simular resto del set".

### 6.3 Tests

- `RallyEvent.fromJson` de un evento viejo sin los campos nuevos → todos en `null`.
- Ida y vuelta `toJson`/`fromJson` con los campos nuevos.
- Punto → zona calculada, con 6 y con 9 zonas, incluidos los bordes.
- Toque en el margen → `missType = out` y `targetZone = null`.
- Widget test del selector: un toque en cada región deja el estado esperado.

### 6.4 Cierre

Actualizar la sección "Zona de destino" del manual, que cambia la forma de cargar, y seguir el proceso de release de `CLAUDE.md`.

## 7. Fuera de alcance por ahora (ideas para después)

- Comparación entre sets en small multiples para todos los gráficos, no solo el marcador.
- Ataque según la calidad de la recepción previa (% de punto con recepción PP vs. N).
- Evolución de un jugador a lo largo de varios partidos del archivo.
- Cruce con el scouting del rival (`scouting_engine.dart`).
