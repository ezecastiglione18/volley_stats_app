// Genera manual_usuario_rallystats.pdf en la raíz del repo.
//
// No existe ningún archivo fuente "editable" del manual (se armó en algún
// momento con una herramienta externa y solo quedó commiteado el PDF final),
// así que este script lo reconstruye por completo con package:pdf, tomando
// la paleta real de la app (ver lib/utils/theme.dart) para que el documento
// se sienta parte de RallyStats. Correrlo con:
//
//   dart run tool/generate_manual.dart
//
// Los números de página del índice (_toc más abajo) están escritos a mano:
// package:pdf no expone una forma simple de resolver "en qué página cayó
// este widget" dentro del mismo pase de armado. Después de generar, conviene
// revisar el PDF resultante y ajustar esos números si algún contenido corrió
// de página.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------------------
// Paleta (misma que AppColors en lib/utils/theme.dart, tokens de modo claro).
// ---------------------------------------------------------------------------
final _navy = PdfColor.fromInt(0xFF1E2A38);
final _cyan = PdfColor.fromInt(0xFF3DC2EC);
final _textDark = PdfColor.fromInt(0xFF1B1F24);
final _textGrey = PdfColor.fromInt(0xFF6B7280);
final _border = PdfColor.fromInt(0xFFE5E7EB);
final _surfaceAlt = PdfColor.fromInt(0xFFEEF1F4);
const _white = PdfColors.white;

/// Total de páginas del documento, para el pie de la portada (que se arma
/// como página suelta, fuera del flujo de MultiPage que sí sabe su propio
/// total). Ajustar tras generar si cambia la paginación real.
const _coverTotalPages = 19;

/// Página donde arranca cada sección/subsección, para el índice. Ajustar
/// tras generar y revisar el PDF si algún contenido corrió de página.
const _pIntroduccion = 4;
const _pPantallaPrincipal = 4;
const _pGestionEquipos = 5;
const _pCrearEquipo = 5;
const _pAgregarJugadores = 5;
const _pEquipoEjemplo = 6;
const _pCrearPartido = 6;
const _pDatosRival = 6;
const _pConfigPartido = 6;
const _pPlanilla = 6;
const _pSeleccionJugadores = 7;
const _pFormacionInicial = 7;
const _pRolesLibero = 7;
const _pPantallaVivo = 8;
const _pMarcador = 8;
const _pCancha = 8;
const _pBotonesAccion = 8;
const _pZonaDestino = 9;
const _pCambiosJugador = 9;
const _pCambioRegular = 9;
const _pCambioLibero = 10;
const _pDeshacerCambio = 10;
const _pSancionesTarjetas = 10;
const _pComoCargarSancion = 11;
const _pEscalaSanciones = 11;
const _pHerramientas = 12;
const _pFinSet = 13;
const _pArchivo = 13;
const _pExportarPartido = 13;
const _pImportarPartido = 13;
const _pResumen = 14;
const _pExportarPdf = 14;
const _pGlosario = 15;
const _pFaq = 16;
const _pContacto = 18;

Future<void> main() async {
  final doc = pw.Document();
  final logoBytes = File('assets/icon/app_icon_petals.png').readAsBytesSync();
  final logo = pw.MemoryImage(logoBytes);

  doc.addPage(_coverPage(logo));
  doc.addPage(_bodyPages(logo));

  final bytes = await doc.save();
  final outFile = File('manual_usuario_rallystats.pdf');
  await outFile.writeAsBytes(bytes);
  // ignore: avoid_print
  print('Manual generado: ${outFile.path} (${bytes.length} bytes)');
}

// ---------------------------------------------------------------------------
// Portada
// ---------------------------------------------------------------------------

pw.Page _coverPage(pw.MemoryImage logo) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (context) => pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.fromLTRB(50, 40, 50, 32),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.Image(logo, width: 16, height: 16),
                pw.SizedBox(width: 8),
                pw.Text('RALLYSTATS',
                    style: pw.TextStyle(
                        color: _white, fontSize: 10, letterSpacing: 1.5, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text('MANUAL DE USUARIO',
                  style: pw.TextStyle(color: PdfColors.blueGrey200, fontSize: 10, letterSpacing: 1)),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 1, color: PdfColors.blueGrey700),
          pw.Expanded(
            child: pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF212B37),
                  borderRadius: pw.BorderRadius.circular(18),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 72,
                      height: 72,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF29323F),
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      child: pw.Image(logo, width: 54, height: 54),
                    ),
                    pw.SizedBox(height: 20),
                    pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: 'Rally',
                            style: pw.TextStyle(color: _white, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                        pw.TextSpan(
                            text: 'Stats',
                            style: pw.TextStyle(color: _cyan, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Manual de Usuario', style: pw.TextStyle(color: _cyan, fontSize: 15)),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Carga de estadísticas en vivo, planillas de equipo y reportes en PDF\npara partidos de vóley.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(color: PdfColors.blueGrey100, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          pw.Container(height: 1, color: PdfColors.blueGrey700),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(color: PdfColors.blueGrey200, fontSize: 9),
                  children: [
                    const pw.TextSpan(text: 'Versión de la app '),
                    pw.TextSpan(text: '1.0', style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Text('Saque · Recepción · Ataque · Bloqueo · Reportes PDF',
                  style: pw.TextStyle(color: PdfColors.blueGrey200, fontSize: 9)),
              pw.Text('1 / $_coverTotalPages', style: pw.TextStyle(color: PdfColors.blueGrey200, fontSize: 9)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Resto del documento: índice + secciones, como un único MultiPage para que
// la numeración de página y el pie ("N / total") salgan solos.
// ---------------------------------------------------------------------------

pw.MultiPage _bodyPages(pw.MemoryImage logo) {
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(50, 34, 50, 34),
    header: (context) => _pageHeader(logo),
    footer: (context) => _pageFooter(context),
    build: (context) => [
      ..._indexContent(),
      pw.NewPage(),
      ..._section1Introduccion(),
      ..._section2PantallaPrincipal(),
      ..._section3GestionEquipos(),
      ..._section4CrearPartido(),
      ..._section5Planilla(),
      ..._section6FormacionInicial(),
      ..._section7PantallaVivo(),
      ..._section8CambiosJugador(),
      ..._section9SancionesTarjetas(),
      ..._section10Herramientas(),
      ..._section11FinSet(),
      ..._section12Archivo(),
      ..._section13Resumen(),
      ..._section14ExportarPdf(),
      ..._section15Glosario(),
      ..._section16Faq(),
      ..._section17Contacto(),
    ],
  );
}

pw.Widget _pageHeader(pw.MemoryImage logo) {
  return pw.Column(children: [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(children: [
          pw.Image(logo, width: 12, height: 12),
          pw.SizedBox(width: 6),
          pw.Text('RallyStats', style: pw.TextStyle(color: _navy, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Manual de Usuario', style: pw.TextStyle(color: _textGrey, fontSize: 9)),
      ],
    ),
    pw.SizedBox(height: 8),
    pw.Container(height: 0.75, color: _border),
    pw.SizedBox(height: 12),
  ]);
}

pw.Widget _pageFooter(pw.Context context) {
  // context.pageNumber/pagesCount ya son globales al documento completo (o
  // sea que ya cuentan la portada, que es una página aparte agregada antes
  // que este MultiPage), así que no hace falta compensarlos a mano.
  final page = context.pageNumber;
  final total = context.pagesCount;
  return pw.Column(children: [
    pw.Container(height: 0.75, color: _border),
    pw.SizedBox(height: 6),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('RallyStats - Manual de Usuario', style: pw.TextStyle(color: _textGrey, fontSize: 8)),
        pw.Text('$page / $total', style: pw.TextStyle(color: _textGrey, fontSize: 8)),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Helpers de contenido
// ---------------------------------------------------------------------------

pw.Widget _sectionTitle(int number, String title) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 18),
      pw.Container(height: 0.75, color: _border),
      pw.SizedBox(height: 18),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(
          width: 22,
          height: 22,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text('$number', style: pw.TextStyle(color: _white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 10),
        pw.Text(title, style: pw.TextStyle(color: _textDark, fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 4),
      pw.Container(width: 42, height: 2.5, color: _cyan),
      pw.SizedBox(height: 12),
    ],
  );
}

pw.Widget _subHeading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
      child: pw.Text(text, style: pw.TextStyle(color: _cyan, fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _p(String text, {double fontSize = 10.2, PdfColor? color, double bottom = 8}) => pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom),
      child: pw.Text(text, style: pw.TextStyle(color: color ?? _textDark, fontSize: fontSize, lineSpacing: 2)),
    );

pw.TextSpan _b(String text) => pw.TextSpan(text: text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold));
pw.TextSpan _t(String text) => pw.TextSpan(text: text);

pw.Widget _bullets(List<List<pw.InlineSpan>> items, {double bottom = 10}) => pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items
            .map((spans) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(right: 8, top: 4.5),
                        decoration: pw.BoxDecoration(color: _textGrey, shape: pw.BoxShape.circle),
                      ),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                              style: pw.TextStyle(color: _textDark, fontSize: 10.2, lineSpacing: 2), children: spans),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );

pw.Widget _numbered(List<List<pw.InlineSpan>> items) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: List.generate(items.length, (i) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 15,
                  height: 15,
                  margin: const pw.EdgeInsets.only(right: 8, top: 1),
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(color: _cyan, shape: pw.BoxShape.circle),
                  child: pw.Text('${i + 1}', style: pw.TextStyle(color: _white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(
                        style: pw.TextStyle(color: _textDark, fontSize: 10.2, lineSpacing: 2), children: items[i]),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );

pw.Widget _infoBox(String text) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _surfaceAlt, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Text(text, style: pw.TextStyle(color: _textDark, fontSize: 9.6, lineSpacing: 2)),
    );

pw.Widget _faqCard(String question, String answer) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(color: _surfaceAlt, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(question, style: pw.TextStyle(color: _textDark, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(answer, style: pw.TextStyle(color: _textDark, fontSize: 9.6, lineSpacing: 2)),
        ],
      ),
    );

pw.Widget _pill(String text, {double fontSize = 8}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Text(text, style: pw.TextStyle(color: _white, fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
    );

/// Tabla con encabezado navy y, opcionalmente, la primera columna renderizada
/// como una "pastilla" oscura (como los botones/íconos del manual original).
pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  List<int>? flex,
  bool pillFirstColumn = false,
}) {
  final widths = flex == null
      ? null
      : {for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i].toDouble())};
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.6),
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _navy),
        children: headers
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: pw.Text(h, style: pw.TextStyle(color: _white, fontSize: 9.2, fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      ),
      for (var r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: r.isOdd ? _surfaceAlt : _white),
          children: List.generate(rows[r].length, (c) {
            final cell = rows[r][c];
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: (pillFirstColumn && c == 0)
                  ? pw.Align(alignment: pw.Alignment.centerLeft, child: _pill(cell))
                  : pw.Text(cell, style: pw.TextStyle(color: _textDark, fontSize: 9.2, lineSpacing: 1.6)),
            );
          }),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Índice
// ---------------------------------------------------------------------------

List<pw.Widget> _indexContent() {
  pw.Widget entry(String title, int page, {bool sub = false}) => pw.Padding(
        padding: pw.EdgeInsets.only(left: sub ? 16 : 0, bottom: sub ? 6 : 9),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            sub
                ? pw.Text('-  ', style: pw.TextStyle(color: _textGrey, fontSize: 9.5))
                : pw.Container(
                    width: 5,
                    height: 5,
                    margin: const pw.EdgeInsets.only(right: 9),
                    decoration: pw.BoxDecoration(color: _cyan, shape: pw.BoxShape.circle),
                  ),
            pw.Expanded(
              child: pw.Text(title,
                  style: pw.TextStyle(
                    color: sub ? _textGrey : _textDark,
                    fontSize: sub ? 9.5 : 10.8,
                    fontWeight: sub ? pw.FontWeight.normal : pw.FontWeight.bold,
                  )),
            ),
            pw.Text('$page',
                style: pw.TextStyle(
                  color: sub ? _textGrey : _cyan,
                  fontSize: sub ? 9.5 : 10.8,
                  fontWeight: sub ? pw.FontWeight.normal : pw.FontWeight.bold,
                )),
          ],
        ),
      );

  return [
    pw.SizedBox(height: 6),
    pw.Text('Índice', style: pw.TextStyle(color: _textDark, fontSize: 22, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 20),
    entry('Introducción', _pIntroduccion),
    entry('Pantalla principal', _pPantallaPrincipal),
    entry('Gestión de equipos', _pGestionEquipos),
    entry('Crear un equipo', _pCrearEquipo, sub: true),
    entry('Agregar y editar jugadores', _pAgregarJugadores, sub: true),
    entry('Equipo de ejemplo', _pEquipoEjemplo, sub: true),
    entry('Crear un partido nuevo', _pCrearPartido),
    entry('Datos del rival y del partido', _pDatosRival, sub: true),
    entry('Configuración del partido', _pConfigPartido, sub: true),
    entry('Planilla del partido (16 jugadores)', _pPlanilla),
    entry('Selección de jugadores', _pSeleccionJugadores, sub: true),
    entry('Formación inicial', _pFormacionInicial),
    entry('Roles de líbero (por set)', _pRolesLibero, sub: true),
    entry('Pantalla de partido en vivo', _pPantallaVivo),
    entry('Marcador', _pMarcador, sub: true),
    entry('Cancha', _pCancha, sub: true),
    entry('Botones de acción y calificación', _pBotonesAccion, sub: true),
    entry('Zona de destino (opcional)', _pZonaDestino, sub: true),
    entry('Cambios de jugador', _pCambiosJugador),
    entry('Cambio regular', _pCambioRegular, sub: true),
    entry('Cambio de líbero', _pCambioLibero, sub: true),
    entry('Deshacer un cambio', _pDeshacerCambio, sub: true),
    entry('Sanciones y tarjetas', _pSancionesTarjetas),
    entry('Cómo cargar una sanción', _pComoCargarSancion, sub: true),
    entry('Escala de sanciones (Regla 21 de la FIVB)', _pEscalaSanciones, sub: true),
    entry('Herramientas durante el partido', _pHerramientas),
    entry('Fin de set y fin de partido', _pFinSet),
    entry('Archivo de partidos', _pArchivo),
    entry('Exportar un partido', _pExportarPartido, sub: true),
    entry('Importar un partido', _pImportarPartido, sub: true),
    entry('Resumen del partido y estadísticas', _pResumen),
    entry('Exportar el reporte en PDF', _pExportarPdf),
    entry('Glosario de calificaciones y abreviaturas', _pGlosario),
    entry('Preguntas frecuentes', _pFaq),
    entry('Contacto', _pContacto),
  ];
}

// ---------------------------------------------------------------------------
// 1. Introducción
// ---------------------------------------------------------------------------

List<pw.Widget> _section1Introduccion() => [
      _sectionTitle(1, 'Introducción'),
      _p(
        'RallyStats es una aplicación para registrar, en tiempo real y desde el celular o la tablet, '
        'las estadísticas de un partido de vóley: saque, recepción, ataque, contraataque, bloqueo y '
        'errores, jugada por jugada y jugador por jugador. Con esos datos, la app arma automáticamente '
        'una planilla de estadísticas y permite compartirla o imprimirla como reporte en PDF.',
      ),
      _p('Con RallyStats podés:', bottom: 6),
      _bullets([
        [_t('Guardar tus equipos y planteles de jugadores (hasta 35 por equipo).')],
        [_t('Configurar un partido nuevo (rival, torneo, formato de sets, cambios permitidos).')],
        [_t('Armar la planilla de 16 jugadores habilitados y la formación inicial de cada set.')],
        [_t('Cargar el partido en vivo, punto por punto, con calificación de cada toque.')],
        [
          _t('Registrar cambios de jugador respetando las reglas oficiales de la FIVB (cambio regular y '
              'cambio de líbero), eligiendo los roles de líbero de nuevo en cada set.')
        ],
        [_t('Deshacer un toque, un cambio de jugador o una sanción cargada por error, sin perder el resto de lo anotado.')],
        [
          _t('Registrar las sanciones/tarjetas del árbitro (amonestación, tarjeta amarilla, roja, expulsión '
              'y descalificación) según el reglamento oficial de la FIVB, con el punto o la salida de '
              'cancha correspondiente aplicados solos.')
        ],
        [_t('Ver la estadística del partido completo o de un set en particular.')],
        [_t('Exportar y compartir un reporte en PDF con el resultado, la estadística por jugador, la del rival y las zonas de destino de saque, ataque y contraataque.')],
        [
          _t('Exportar un partido guardado como archivo (no el PDF) para pasarlo a otro dispositivo '
              'e importarlo ahí, conservando todos sus datos.')
        ],
        [_t('Elegir entre modo claro y modo oscuro, según preferencia.')],
        [_t('Guardar el archivo histórico de partidos jugados.')],
      ]),
      _p(
        'Además del celular o la tablet (Android), RallyStats también tiene una versión de escritorio '
        'para Windows, con las mismas funciones (ver sección 16 para los requisitos).',
      ),
      _infoBox(
        'Nota: todos los datos (equipos, jugadores y partidos) se guardan únicamente en el dispositivo '
        'donde se usa la app. No se suben a internet ni se sincronizan solos entre dispositivos: conviene '
        'exportar (sección 12.1) o generar el PDF (sección 14) de los partidos importantes para '
        'conservarlos, pasarlos a otro dispositivo o compartirlos con el cuerpo técnico.',
      ),
    ];

// ---------------------------------------------------------------------------
// 2. Pantalla principal
// ---------------------------------------------------------------------------

List<pw.Widget> _section2PantallaPrincipal() => [
      _sectionTitle(2, 'Pantalla principal'),
      _p(
        'Al abrir la app aparece la pantalla principal con tres accesos, que son también el orden natural '
        'en el que se usa la app para armar y jugar un partido:',
        bottom: 6,
      ),
      _numbered([
        [_b('Nuevo Partido: '), _t('inicia el asistente para configurar y arrancar un partido nuevo.')],
        [_b('Archivo de Partidos: '), _t('lista todos los partidos guardados, terminados o en curso.')],
        [_b('Equipos: '), _t('administra los equipos propios y sus planteles de jugadores.')],
      ]),
      _p(
        'En la parte superior derecha de casi todas las pantallas hay un interruptor de modo claro / modo '
        'oscuro (ícono de sol / luna) para alternar entre los dos. La preferencia elegida queda guardada '
        'en el dispositivo y se aplica automáticamente la próxima vez que se abre la app. La excepción es '
        'la pantalla de partido en vivo (sección 7), donde este interruptor está dentro del menú "Más '
        'opciones" del encabezado (sección 10), para no competir con los accesos propios de la carga en '
        'vivo.',
      ),
    ];

// ---------------------------------------------------------------------------
// 3. Gestión de equipos
// ---------------------------------------------------------------------------

List<pw.Widget> _section3GestionEquipos() => [
      _sectionTitle(3, 'Gestión de equipos'),
      _p(
        'Antes de cargar un partido hace falta tener creado, al menos, el equipo propio con sus jugadores. '
        'Desde la pantalla principal, tocá Equipos para ver la lista de equipos guardados.',
      ),
      _subHeading('3.1 Crear un equipo'),
      _numbered([
        [_b('En la pantalla "Equipos", tocá el botón '), _b('+ Nuevo equipo'), _t('.')],
        [_t('Escribí el nombre del equipo o club.')],
        [
          _t('Opcionalmente, completá los datos del cuerpo técnico: Entrenador, Asistente de entrenador, '
              'Auxiliar, Médico y Preparador físico.')
        ],
        [_t('El equipo se guarda automáticamente a medida que se completan los datos (no hace falta un botón "Guardar" aparte para el nombre ni para el cuerpo técnico).')],
      ]),
      _p(
        'Desde la lista de equipos también podés tocar cualquier equipo existente para editarlo, o usar el '
        'ícono de tacho para borrar un jugador.',
      ),
      _subHeading('3.2 Agregar y editar jugadores'),
      _p(
        'Dentro de la pantalla de un equipo ("Editar equipo"), tocá Agregar para sumar un jugador nuevo, o '
        'tocá un jugador de la lista para editarlo. Cada equipo admite hasta 35 jugadores cargados; de esa '
        'lista después se elige, para cada partido, una planilla de hasta 16 habilitados.',
      ),
      _p(
        'Los campos obligatorios son Apellido, Nombre, Número de camiseta y Posición (están marcados con '
        'un asterisco); el resto de los datos son opcionales. Los datos que se cargan por jugador son, en '
        'el orden en que aparecen en el formulario:',
        bottom: 6,
      ),
      _bullets([
        [_t('Apellido y Nombre (obligatorios).')],
        [_t('Número de camiseta (obligatorio).')],
        [_t('Mano hábil (opcional): derecha o izquierda.')],
        [
          _t('Posición (obligatoria): Armador, Opuesto, Central, Punta/Receptor, Líbero o Universal '
              '(un jugador que puede cubrir cualquier puesto salvo el de líbero).')
        ],
        [_t('Foto (opcional): se elige desde el selector de archivos del dispositivo.')],
        [
          _b('Edad (opcional): '),
          _t('se puede escribir a mano, o dejar que se calcule sola cargando la fecha de '
              'nacimiento (también opcional); si hay fecha de nacimiento cargada, tiene prioridad y la edad se '
              'recalcula sola, sin poder editarse a mano.')
        ],
        [_t('Datos físicos (opcionales): altura, peso, alcance en bloqueo y alcance en ataque (en cm).')],
      ]),
      _p(
        'Para borrar un equipo completo, entrá a su pantalla de edición y usá el ícono de tacho de basura '
        'del encabezado; la app pide confirmación antes de eliminarlo.',
      ),
      _subHeading('3.3 Equipo de ejemplo'),
      _p(
        'En la pantalla "Equipos", el ícono con forma de estrella del encabezado carga automáticamente un '
        'equipo de ejemplo (Club Atlético Central) con 35 jugadores ya cargados, repartidos en partes '
        'iguales entre las posiciones y con la edad cargada de las dos formas posibles '
        '(algunos con edad a mano, otros con fecha de nacimiento), además del cuerpo técnico ya completo. '
        'No trae fotos cargadas (son opcionales y no hay ninguna foto real para asignarles a jugadores de '
        'ejemplo). Es útil para probar la app rápidamente sin tener que escribir un plantel entero a mano.',
      ),
    ];

// ---------------------------------------------------------------------------
// 4. Crear un partido nuevo
// ---------------------------------------------------------------------------

List<pw.Widget> _section4CrearPartido() => [
      _sectionTitle(4, 'Crear un partido nuevo'),
      _p(
        'Tocá Nuevo Partido en la pantalla principal. El armado de un partido tiene cuatro pasos: datos del '
        'partido, planilla de 16, formación inicial y, recién ahí, arranca la carga en vivo.',
      ),
      _subHeading('4.1 Datos del rival y del partido'),
      _bullets([
        [_b('Mi equipo: '), _t('elegí uno de los equipos ya cargados en "Equipos".')],
        [
          _b('Rival: '),
          _t('escribí el nombre del equipo rival. Si el rival también está precargado como equipo propio '
              'en la app, se lo puede seleccionar desde "Equipo rival precargado" para autocompletar el nombre.')
        ],
        [_b('Fecha del partido '), _t('(por defecto, la fecha de hoy).')],
        [_b('Torneo / Liga, Instancia, Categoría y Cancha / sede '), _t('(todos opcionales, quedan en el reporte).')],
      ]),
      _subHeading('4.2 Configuración del partido'),
      _p(
        'Desplegando "Configuración del partido" se pueden ajustar las reglas con las que se juega, con '
        'valores por defecto ya cargados según el reglamento estándar:',
      ),
      _table(
        headers: ['Parámetro', 'Valor por defecto', 'Qué controla'],
        flex: [3, 2, 5],
        rows: [
          ['Cantidad máxima de sets', '5', 'Sets totales que se juegan como máximo (mejor de 5).'],
          ['Puntos para ganar un set (1° al 4°)', '25', 'Puntos necesarios para ganar los sets regulares.'],
          ['Diferencia mínima (sets 1° al 4°)', '2', 'Ventaja mínima de puntos para cerrar esos sets.'],
          ['Puntos para ganar el tie-break', '15', 'Puntos del set decisivo (el último posible).'],
          ['Diferencia mínima (tie-break)', '2', 'Ventaja mínima de puntos para cerrar el tie-break.'],
          ['Cambios permitidos por set', '6', 'Cambios regulares de jugador habilitados por set y por equipo. Se puede tildar "Sin límite" para no restringirlos.'],
        ],
      ),
      pw.SizedBox(height: 10),
      _p('Cuando todo esté completo, tocá Continuar: elegir planilla de 16.'),
    ];

// ---------------------------------------------------------------------------
// 5. Planilla del partido
// ---------------------------------------------------------------------------

List<pw.Widget> _section5Planilla() => [
      _sectionTitle(5, 'Planilla del partido (16 jugadores)'),
      _p(
        'En esta pantalla se eligen, del plantel completo del equipo, los jugadores habilitados para este '
        'partido en particular (mínimo 6, máximo 16). Los chips de arriba (Todos, ARM, OP, CEN, P/R, LIB, '
        'UNI) sirven solo para filtrar la lista visible; no afectan a los jugadores ya seleccionados.',
      ),
      _subHeading('5.1 Selección de jugadores'),
      _p('Tocá cada jugador de la lista para marcarlo o desmarcarlo como habilitado para el partido.'),
      _p('Tocá Continuar: formación inicial para seguir.'),
    ];

// ---------------------------------------------------------------------------
// 6. Formación inicial
// ---------------------------------------------------------------------------

List<pw.Widget> _section6FormacionInicial() => [
      _sectionTitle(6, 'Formación inicial'),
      _p('Antes de arrancar el set (o cada set siguiente) hay que definir:', bottom: 6),
      _bullets([
        [
          _b('Quién saca primero: '),
          _t('el equipo propio o el rival. A partir del segundo set, la app sugiere alternar el saque '
              'respecto al set anterior (se puede cambiar si hace falta corregirlo); en el set decisivo '
              '(tie-break) no sugiere nada, porque el reglamento indica un nuevo sorteo.')
        ],
        [
          _b('La formación '),
          _t('de las 6 posiciones en cancha, asignando un jugador a cada una: fila delantera (4-3-2) y '
              'fila trasera (5-6-1, donde el puesto 1 es el que saca). El líbero nunca ocupa una de estas 6 '
              'posiciones: se asigna aparte, más abajo, y entra en cancha durante el set mediante el cambio '
              'de líbero (ver sección 8.2). A partir del segundo set del partido, las 6 posiciones aparecen '
              'precargadas con la misma formación titular del set anterior, para no tener que volver a '
              'elegir jugador por jugador cuando el equipo repite sexteto; se puede cambiar libremente antes '
              'de tocar Comenzar set.')
        ],
        [
          _b('Roles de líbero '),
          _t('(opcional): si entre los jugadores habilitados hay uno o más líberos, aparece acá, debajo del '
              'sexteto, la sección "Roles de líbero" (ver más abajo).')
        ],
        [_b('Armador rival '), _t('(opcional): solo a modo informativo, en qué posición arranca.')],
        [
          _b('Registrar zona de destino en saque y ataque: '),
          _t('si está activada, al calificar un saque o un ataque se va a poder marcar (opcionalmente) a '
              'qué zona de la cancha rival fue dirigido. Esta opción se define una vez por set.')
        ],
      ]),
      _subHeading('6.1 Roles de líbero (por set)'),
      _p(
        'Si el equipo tiene uno o más líberos entre los jugadores habilitados para el partido, debajo del '
        'sexteto inicial aparecen dos selectores opcionales: líbero defensor (el que entra cuando saca el '
        'equipo propio) y líbero receptor (el que entra cuando saca el rival). Ambos roles pueden recaer en '
        'el mismo jugador.',
      ),
      _p(
        'Esta elección se hace de nuevo antes de cada set, porque el equipo puede usar líberos distintos '
        'set a set: a partir del segundo set los selectores aparecen precargados con lo elegido en el set '
        'anterior, pero se pueden cambiar libremente. Definirlos habilita, durante ese set, la sugerencia '
        'automática de cambio de líbero cuando corresponde (ver sección 8.2).',
      ),
      _p(
        'Debajo de los selectores de líbero aparece el checkbox "Líbero automático por central en el '
        'fondo", tildado por defecto: si está activado, entra solo el líbero que corresponda por el '
        'central que rota a la fila de fondo (el defensor cuando saca el equipo propio, salvo que sea ese '
        'central quien va a sacar, o el receptor cuando saca el rival), sin necesitar el cambio manual. '
        'Destildado, esos cambios se siguen sugiriendo pero hay que aplicarlos a mano desde el panel de '
        'cambios (sección 8.2). También se elige de nuevo en cada set.',
      ),
      _p('Con todas las posiciones asignadas, tocá Comenzar partido (o Comenzar set N si es un set siguiente '
          'dentro de un partido ya en curso) para pasar a la pantalla de carga en vivo.'),
    ];

// ---------------------------------------------------------------------------
// 7. Pantalla de partido en vivo
// ---------------------------------------------------------------------------

List<pw.Widget> _section7PantallaVivo() => [
      _sectionTitle(7, 'Pantalla de partido en vivo'),
      _p(
        'Es la pantalla principal de uso durante el partido. Se divide en tres partes: el marcador, la '
        'cancha con la formación actual y la grilla de botones de acción.',
      ),
      _subHeading('7.1 Marcador'),
      _p(
        'Muestra el nombre y el puntaje de cada equipo en el set actual, un ícono de pelota junto al equipo '
        'que está sacando, y debajo el resultado en sets y el número de set en curso. Si se cargó la '
        'posición del armador rival al armar el set (sección 6), también se muestra ahí abajo como dato '
        'informativo durante todo el partido.',
      ),
      _subHeading('7.2 Cancha'),
      _p(
        'Representa las 6 posiciones de la cancha propia (fila delantera 4-3-2 arriba, fila trasera 5-6-1 '
        'abajo) con el jugador que ocupa cada una en este momento. El puesto que saca (posición 1) se '
        'resalta en color. La cancha se actualiza sola con cada rotación y con cada cambio de jugador.',
      ),
      _subHeading('7.3 Botones de acción y calificación'),
      _p(
        'Debajo de la cancha hay ocho botones de acción. La app solo habilita en cada momento los botones '
        'que corresponden a la etapa actual del punto (por ejemplo, no deja registrar un ataque si todavía '
        'no hubo recepción); los botones deshabilitados se ven en gris.',
      ),
      _table(
        headers: ['Botón', 'Cuándo se habilita', 'Qué registra'],
        flex: [3, 4, 6],
        pillFirstColumn: true,
        rows: [
          ['Saque', 'Cuando le toca sacar al equipo propio.', 'Calificación del saque del jugador que está en el puesto 1.'],
          ['Contra', 'Con la pelota en juego del lado rival.', 'Calificación de un contraataque (posterior a defensa/bloqueo).'],
          ['Recepción', 'Cuando el rival sacó.', 'Calificación de la recepción, eligiendo qué jugador recibió.'],
          ['Ataque', 'Después de una recepción no terminal.', 'Calificación del primer ataque (K1), eligiendo el jugador.'],
          ['Bloqueo (Punto)', 'Con la pelota en juego del lado rival.', 'Punto de bloqueo; permite elegir uno o más bloqueadores.'],
          ['Error Genérico', 'En cualquier momento.', 'Error propio no atribuible a un toque puntual (rotación, cuatro toques, etc.), con jugador opcional.'],
          ['Punto Rival', 'Al recibir o defender.', 'Punto directo del rival no atribuible a una acción propia cargada aparte; pide elegir si fue de ataque o de contraataque.'],
          ['Error Rival', 'Al recibir o defender.', 'Error no forzado del rival que le da el punto al equipo propio; pide elegir si fue de saque, ataque, contraataque o genérico.'],
        ],
      ),
      pw.SizedBox(height: 10),
      _p(
        'Al tocar Punto Rival o Error Rival se abre un panel chico para elegir con qué tocó el rival, antes '
        'de registrar el punto. Es una clasificación distinta e independiente de Error Genérico, que sigue '
        'siendo para errores propios (de rotación, cuatro toques, etc.), no del rival.',
      ),
      _p(
        'Al tocar Saque, Recepción, Ataque o Contra se abre un panel donde, si corresponde, primero se '
        'elige el jugador y después se toca la calificación del toque. Las escalas de calificación son:',
      ),
      _table(
        headers: ['Fase', 'Escala de calificación'],
        flex: [3, 7],
        rows: [
          ['Saque', 'PP Punto (Doble Positiva) · P Positiva · N Negativa · NN Error (Doble Negativa)'],
          ['Ataque / Contra', 'PP Punto (Doble Positiva) · P Positiva · N Negativa · BLOQ Bloqueado · NN Error (Doble Negativa)'],
          ['Recepción', 'PP Perfecta (Doble Positiva) · P Positiva · ! Exclamativa · N Negativa · V/ Vendida · NN Error (Doble Negativa)'],
        ],
      ),
      pw.SizedBox(height: 10),
      _p(
        'Una recepción calificada como V/ Vendida no habilita Ataque (la pelota quedó descontrolada del '
        'lado rival, no en condiciones de armar un ataque propio): habilita Contra, Bloqueo (Punto), Error '
        'Genérico, Punto Rival y Error Rival, igual que cualquier otra pelota en juego del lado rival.',
      ),
      _p('Para el bloqueo se puede elegir uno o más jugadores (bloqueo doble o triple); para "Error Genérico" se puede elegir un jugador o dejarlo sin asignar.'),
      _p(
        'Las fichas para elegir jugador en estos paneles se muestran agrupadas por línea de juego: primero '
        'armador y opuesto, después el/los central/es, después punta(s) y universal(es), y el líbero al '
        'final (junto a las puntas), en vez del orden de posición en cancha.',
      ),
      _subHeading('7.4 Zona de destino (opcional)'),
      _p(
        'Si en la formación del set se activó "Registrar zona de destino", al calificar un saque o un '
        'ataque aparece además un cuadro dividido en las 6 zonas de la cancha rival, numeradas de frente '
        'para quien anota (2-3-4 junto a la red, 1-6-5 en el fondo) para marcar, de forma opcional, hacia '
        'dónde fue dirigido el toque. Esta información después se resume en el reporte en PDF (sección 14).',
      ),
      _p(
        'Al usar la app en una ventana ancha (por ejemplo, en una computadora), los ocho botones de acción '
        'se acomodan solos en un formato más compacto para entrar siempre completos en pantalla, sin '
        'necesidad de hacer scroll para llegar a los de más abajo.',
      ),
    ];

// ---------------------------------------------------------------------------
// 8. Cambios de jugador
// ---------------------------------------------------------------------------

List<pw.Widget> _section8CambiosJugador() => [
      _sectionTitle(8, 'Cambios de jugador'),
      _p(
        'Se registran desde el ícono de flechas cruzadas del encabezado de la pantalla en vivo. El panel de '
        'cambios tiene dos modos: Cambio regular y Cambio de líbero, cada uno con sus propias reglas (las '
        'mismas que usa el reglamento oficial de la FIVB, vigente también en los torneos de FeVA y de las '
        'federaciones metropolitanas):',
      ),
      _subHeading('8.1 Cambio regular'),
      _bullets([
        [_t('Cada titular tiene, como máximo, un único suplente fijo: puede salir por él una vez y volver a entrar una vez más, siempre entre esos dos mismos jugadores.')],
        [_t('Un líbero nunca puede intervenir en un cambio regular.')],
        [_t('Cada cambio regular consume un cupo del total configurado para el partido (por defecto, 6 por set); el contador de cambios usados se muestra arriba del panel.')],
        [_t('Para hacerlo: elegí primero quién sale (solo se pueden elegir jugadores en cancha habilitados según la regla anterior) y después quién entra del banco.')],
        [
          _t('Entre las opciones del banco, la app resalta con una estrella y un borde de color a quienes '
              'juegan la misma posición que el titular que sale, como "cambio sugerido": es solo una '
              'ayuda visual, no una restricción, se puede elegir cualquier otro jugador habilitado del '
              'banco igual.')
        ],
      ]),
      _subHeading('8.2 Cambio de líbero'),
      _p('Solo está disponible si el equipo tiene al menos un líbero declarado en la formación de este set (sección 6.1). Reglas:', bottom: 6),
      _bullets([
        [_t('El líbero solo puede entrar en un puesto de fila trasera (posiciones 1, 5 o 6), y no puede ocupar el puesto que está a punto de sacar.')],
        [_t('Solo puede haber un líbero en cancha a la vez, aunque el equipo haya declarado dos.')],
        [_t('El líbero en cancha solo puede salir por el mismo jugador al que reemplazó, o cambiarse directamente por el otro líbero declarado (si el equipo tiene dos).')],
        [_t('El cambio de líbero no consume el cupo de cambios regulares del set, y es prácticamente ilimitado (con al menos una jugada de diferencia entre dos cambios seguidos en el mismo puesto).')],
      ]),
      _p('La app además puede automatizar estas situaciones, sin necesitar acción manual:', bottom: 6),
      _bullets([
        [_b('Central que saca y pierde el punto: '), _t('si estaba configurado un líbero receptor, entra automáticamente por ese central en cuanto el punto pasa a manos del rival.')],
        [_b('Líbero que rota a la fila delantera: '), _t('sale automáticamente y vuelve el jugador al que había reemplazado, ya que un líbero nunca puede jugar adelante.')],
        [
          _b('Central que queda en el fondo (sacando nosotros o el rival): '),
          _t('si está tildado el checkbox "Líbero automático por central en el fondo" de la formación de '
              'este set (sección 6.1), entra solo el líbero que corresponda por ese central: el defensor '
              'si el saque es nuestro (salvo que ese central sea quien va a sacar), o el receptor si saca '
              'el rival, incluso al arrancar el set si ya arranca sacando el rival. Destildado, la app lo '
              'sigue sugiriendo pero hay que aplicarlo a mano, igual que antes.')
        ],
      ]),
      _p('Cuando corresponde y no se aplicó solo, el panel de cambio de líbero también sugiere directamente el cambio recomendado para un central que quedó en el fondo, con un botón para aplicarlo en un toque.'),
      _subHeading('8.3 Deshacer un cambio'),
      _p(
        'Si te equivocaste al registrar un cambio (regular o de líbero), el mismo panel de cambios tiene un '
        'botón Deshacer último cambio. Solo deshace el cambio más reciente del set (no uno anterior), '
        'devuelve a la cancha al jugador que había salido y, si el cambio deshecho era regular, no queda '
        'contado contra el cupo de cambios del set.',
      ),
      _p(
        'Los cambios automáticos (central reemplazado por el líbero receptor al perder el saque, o líbero '
        'que sale obligado al rotar a la fila delantera) no se pueden deshacer desde este botón, porque '
        'responden a una regla del reglamento y no a un error de carga.',
      ),
      _p(
        'El botón Deshacer del encabezado (sección 10) es más general: deshace lo último que haya pasado en '
        'el set, sea una jugada o un cambio de jugador manual. Si un cambio automático quedó colgando '
        'justo después de la última jugada (por ejemplo, el líbero receptor que entró solo al perder el '
        'saque), ese botón lo revierte junto con la jugada, para dejar la cancha como estaba antes.',
      ),
    ];

// ---------------------------------------------------------------------------
// 9. Sanciones y tarjetas
// ---------------------------------------------------------------------------

List<pw.Widget> _section9SancionesTarjetas() => [
      _sectionTitle(9, 'Sanciones y tarjetas'),
      _p(
        'Se registran desde el ícono de tarjetas del encabezado de la pantalla en vivo, según el '
        'reglamento oficial de conducta incorrecta de la FIVB (Regla 21), vigente también en los '
        'torneos de FeVA y de las federaciones metropolitanas.',
      ),
      _subHeading('9.1 Cómo cargar una sanción'),
      _p(
        'Al abrir el panel aparece primero un historial con las sanciones ya cargadas en el set actual '
        '(a quién, con qué equipo, la sanción y en qué punto del marcador fue), para llevar la cuenta '
        'sin tener que salir de la pantalla en vivo. El ícono de tarjetas del encabezado también muestra '
        'esa cantidad como numerito mientras haya alguna cargada en el set.',
      ),
      _p(
        'El panel se completa paso a paso (equipo > a quién > categoría > confirmar), con botones Atrás y '
        'Siguiente para moverse entre pasos, en vez de una sola pantalla larga: así entra cómodo aunque el '
        'plantel habilitado tenga los 16 jugadores.',
      ),
      _numbered([
        [_t('Elegí a qué equipo sancionó el árbitro: el propio o el rival.')],
        [
          _b('Elegí a quién: '),
          _t('un jugador del plantel propio, o "Banco / Cuerpo técnico" si la sanción no fue a un '
              'jugador en particular. Como la app no lleva el plantel rival jugador por jugador, para el '
              'equipo rival se escribe el número de camiseta en vez de elegir de una lista.')
        ],
        [
          _b('Elegí la categoría '),
          _t('de la conducta que sancionó el árbitro: Conducta grosera, Conducta ofensiva, Agresión o '
              'Demora/Advertencia (ver la escala completa en 9.2).')
        ],
        [
          _t('La app calcula sola qué sanción corresponde, según cuántas veces ya se sancionó a esa '
              'misma persona por esa misma categoría en lo que va del partido, y muestra la tarjeta y la '
              'consecuencia antes de confirmar.')
        ],
        [_t('Tocá Registrar sanción para aplicarla.')],
      ]),
      _p(
        'Si la sanción obliga a la persona a abandonar la cancha y estaba jugando, el mismo panel pide a '
        'continuación elegir el reemplazo: primero ofrece el suplente regular de ese puesto si todavía '
        'tenía cupo de cambio; si no, cualquier otro jugador del banco (salvo los líberos declarados), '
        'sin que ese reemplazo cuente contra el límite de cambios del set. Si no hay ningún suplente '
        'disponible, la app avisa que el equipo queda incompleto en esa posición: es una situación '
        'excepcional que hay que resolver a criterio del cuerpo técnico y el árbitro, no algo que la app '
        'pueda decidir sola.',
      ),
      _infoBox(
        'La app respeta automáticamente el alcance de cada sanción al armar las listas de banco '
        'disponible (para este reemplazo y para cualquier cambio posterior): un jugador Expulsado no '
        'aparece como opción durante el resto de ese set, y uno Descalificado no vuelve a aparecer en '
        'ningún set restante del partido.',
      ),
      _infoBox(
        'Una sanción se puede deshacer igual que cualquier otra acción, con el botón Deshacer del '
        'encabezado (sección 10): revierte el punto o la salida de cancha que haya generado, junto con el '
        'reemplazo obligatorio si lo hubo.',
      ),
      _subHeading('9.2 Escala de sanciones (Regla 21 de la FIVB)'),
      _p(
        'La sanción depende de la categoría de la conducta y de cuántas veces ya se sancionó a esa misma '
        'persona por esa misma categoría en el partido (no se reinicia entre sets):',
      ),
      _table(
        headers: ['Categoría', 'Ocurrencia', 'Sanción', 'Tarjetas', 'Consecuencia'],
        flex: [3, 2, 3, 4, 5],
        rows: [
          ['Conducta grosera', '1ª', 'Castigo', 'Roja', '1 punto y saque para el equipo rival.'],
          [
            'Conducta grosera',
            '2ª',
            'Expulsión',
            'Roja + Amarilla juntas',
            'Debe abandonar la cancha por el resto del set.'
          ],
          [
            'Conducta grosera',
            '3ª',
            'Descalificación',
            'Roja + Amarilla separadas',
            'Debe abandonar por el resto del partido.'
          ],
          [
            'Conducta ofensiva',
            '1ª',
            'Expulsión',
            'Roja + Amarilla juntas',
            'Debe abandonar la cancha por el resto del set.'
          ],
          [
            'Conducta ofensiva',
            '2ª',
            'Descalificación',
            'Roja + Amarilla separadas',
            'Debe abandonar por el resto del partido.'
          ],
          [
            'Agresión',
            '1ª',
            'Descalificación directa',
            'Roja + Amarilla separadas',
            'Debe abandonar por el resto del partido.'
          ],
          ['Demora/Advertencia', '1ª', 'Amonestación', 'Amarilla', 'Solo prevención, sin efecto en el marcador.'],
          ['Demora/Advertencia', '2ª en adelante', 'Castigo por demora', 'Roja', '1 punto y saque para el equipo rival.'],
        ],
      ),
      pw.SizedBox(height: 10),
      _p(
        'Las tarjetas mostradas y la cantidad de amarillas/rojas recibidas por cada jugador quedan '
        'reflejadas en la tabla de estadísticas (sección 13) y en el reporte en PDF (sección 14).',
      ),
    ];

// ---------------------------------------------------------------------------
// 10. Herramientas durante el partido
// ---------------------------------------------------------------------------

List<pw.Widget> _section10Herramientas() => [
      _sectionTitle(10, 'Herramientas durante el partido'),
      _p('En el encabezado de la pantalla en vivo hay accesos rápidos adicionales:'),
      _table(
        headers: ['Ícono', 'Función'],
        flex: [3, 7],
        pillFirstColumn: true,
        rows: [
          ['Deshacer', 'Anula la última acción cargada (toque, punto, cambio de jugador o sanción/tarjeta) y revierte el marcador y la etapa del punto si hacía falta. Útil para corregir una carga hecha por error. Deja de estar disponible una vez que se confirma el fin de un set (ver sección 11).'],
          ['Ver estadísticas', 'Abre el resumen de estadísticas del partido en curso (ver sección 13).'],
          ['Cambio de jugador', 'Abre el panel de cambios (ver sección 8), que también permite deshacer el último cambio (sección 8.3).'],
          ['Confirmar fin de set', 'Solo aparece cuando el set en curso llegó a su puntaje de cierre y todavía no fue confirmado. Ver sección 11.'],
          ['Más opciones (⋮)', 'Agrupa Simular resto del set, Abandonar partido y el interruptor de modo claro/oscuro, para no ocupar tanto lugar en el encabezado en pantallas angostas.'],
        ],
      ),
      _bullets([
        [
          _b('Simular resto del set: '),
          _t('carga puntos al azar (jugador, calificación y resultado) hasta terminar el set actual. Cada '
              'acción simulada se puede deshacer igual que una cargada a mano. Pensado para probar la app o '
              'mostrar cómo funciona sin cargar todo el set manualmente.')
        ],
        [
          _b('Abandonar partido: '),
          _t('borra por completo el partido en curso (no se puede deshacer). La app pide confirmación antes '
              'de eliminarlo.')
        ],
      ]),
    ];

// ---------------------------------------------------------------------------
// 11. Fin de set y fin de partido
// ---------------------------------------------------------------------------

List<pw.Widget> _section11FinSet() => [
      _sectionTitle(11, 'Fin de set y fin de partido'),
      _p(
        'Cuando un equipo llega a los puntos necesarios con la diferencia mínima configurada, el set '
        'termina y aparece un aviso con el resultado del set y el resultado en sets del partido, con dos '
        'opciones: Ver estadísticas del set (abre el resumen de ese set en particular, sección 13) o Cerrar '
        '(vuelve a la pantalla en vivo sin decidir nada todavía).',
        bottom: 6,
      ),
      _infoBox(
        'A propósito, ese aviso NO obliga a seguir de largo: el set queda "pendiente de confirmar" y se '
        'puede seguir usando el botón Deshacer con normalidad mientras tanto, por si el árbitro termina '
        'revirtiendo el último punto. Recién al tocar el botón Confirmar fin de set del encabezado (que '
        'aparece únicamente mientras el set está en este estado pendiente, ver sección 10) el set queda '
        'bloqueado en firme y deja de poder deshacerse.',
      ),
      _p(
        'Al confirmar, la app avanza según corresponda:',
        bottom: 6,
      ),
      _bullets([
        [_t('Si todavía no está definido el partido, se vuelve a la pantalla de formación (sección 6) para armar el próximo set.')],
        [
          _t('Si el partido queda definido con ese set (un equipo alcanza los sets necesarios para ganar), la '
              'app guarda el partido automáticamente en el archivo y pasa directo a la pantalla de resumen '
              '(sección 13), donde aparece un botón Volver al inicio para salir directo a la pantalla '
              'principal sin tener que retroceder pantalla por pantalla. El mismo botón Confirmar fin de set '
              'del encabezado se usa también para este último set: el partido no se da por terminado en '
              'forma automática, para dejarle al árbitro la misma posibilidad de revertir el punto final.')
        ],
      ]),
    ];

// ---------------------------------------------------------------------------
// 12. Archivo de partidos
// ---------------------------------------------------------------------------

List<pw.Widget> _section12Archivo() => [
      _sectionTitle(12, 'Archivo de partidos'),
      _p(
        'Desde la pantalla principal, Archivo de Partidos lista todos los partidos guardados, con fecha, '
        'torneo, resultado en sets y un ícono que indica si están terminados (tilde, en verde) o todavía en '
        'curso (flecha de reproducir, en naranja).',
        bottom: 6,
      ),
      _bullets([
        [_t('Tocar un partido terminado abre directamente su resumen de estadísticas (sección 13).')],
        [_t('Tocar un partido en curso retoma la carga en vivo exactamente donde había quedado, reconstruyendo el marcador, la rotación y los cambios ya realizados.')],
        [_t('Desde el menú de tres puntos de cada partido se lo puede exportar (ver 12.1) o eliminar del archivo.')],
      ]),
      _subHeading('12.1 Exportar un partido'),
      _p(
        'La opción Exportar del menú de tres puntos de un partido genera un archivo con todos sus datos '
        '(equipos, marcador, jugada por jugada y cambios de jugador). A diferencia del reporte en PDF '
        '(sección 14), que es solo para leer o imprimir, este archivo se puede volver a importar en '
        'RallyStats en otro dispositivo (sección 12.2) para seguir teniéndolo disponible ahí, incluso si '
        'todavía estaba en curso.',
      ),
      _p(
        'En Android se abre la hoja para compartir de siempre (WhatsApp, correo, Drive, etc.); en la '
        'versión de Windows, en cambio, se abre un cuadro para elegir en qué carpeta de la computadora '
        'guardar el archivo.',
      ),
      _subHeading('12.2 Importar un partido'),
      _p(
        'El ícono de subir archivo, en el encabezado de "Archivo de Partidos", abre un selector para elegir '
        'un archivo de partido exportado antes (sección 12.1) y agregarlo al archivo de este dispositivo. '
        'Si ya hay ahí un partido con el mismo identificador (por ejemplo, si el mismo archivo se importa '
        'dos veces), se guarda como una copia nueva y aparte, sin pisar el que ya estaba.',
      ),
    ];

// ---------------------------------------------------------------------------
// 13. Resumen del partido y estadísticas
// ---------------------------------------------------------------------------

List<pw.Widget> _section13Resumen() => [
      _sectionTitle(13, 'Resumen del partido y estadísticas'),
      _p(
        'Esta pantalla se abre automáticamente al terminar un partido, o desde el ícono de estadísticas '
        'durante la carga en vivo, o tocando un partido terminado en el archivo. Muestra:',
        bottom: 6,
      ),
      _bullets([
        [_t('Los datos generales del partido (fecha, torneo, instancia, categoría, cancha) y el resultado final.')],
        [_t('Si acabás de terminar el partido, un aviso y un botón Volver al inicio para ir directo a la pantalla principal.')],
        [_t('El resultado punto a punto de cada set jugado.')],
        [_t('Una tabla de estadísticas por jugador, con una fila de TOTAL EQUIPO al final.')],
        [
          _t('Una sección aparte, "Estadística del rival", con sus errores por tipo (saque, ataque, contra, '
              'genérico) y los puntos que ganó con su propio toque (ataque o contra).')
        ],
      ]),
      _p(
        'El selector Estadística permite elegir entre el partido completo o un set en particular (afecta '
        'también a la sección "Estadística del rival"); al abrirse justo después de terminar un set desde '
        'el aviso de fin de set (sección 11), arranca directamente con ese set seleccionado. La tabla por '
        'jugador incluye: puntos totales, errores totales, el desglose de saque, ataque y contraataque por '
        'calificación (PP/P/N/Bl/NN) junto con el porcentaje de efectividad de cada uno, puntos de bloqueo, '
        'errores genéricos, y el desglose de recepción (total, PP, P, !, N, V/, NN) junto con el porcentaje '
        'de efectividad de recepción. Los tres porcentajes de efectividad se calculan así:',
        bottom: 6,
      ),
      _bullets([
        [_b('Saque: '), _t('(PP + P) sobre el total de saques.')],
        [_b('Ataque y Contraataque: '), _t('PP sobre el total de toques (PP + P + N + Bl + NN).')],
        [_b('Recepción: '), _t('(PP + P) sobre el total de recepciones.')],
      ]),
    ];

// ---------------------------------------------------------------------------
// 14. Exportar el reporte en PDF
// ---------------------------------------------------------------------------

List<pw.Widget> _section14ExportarPdf() => [
      _sectionTitle(14, 'Exportar el reporte en PDF'),
      _p(
        'Desde la pantalla de resumen del partido (sección 13), el ícono de PDF del encabezado genera y '
        'abre el diálogo para compartir o guardar un reporte completo en PDF, listo para enviar por '
        'WhatsApp o correo, o para imprimir.',
        bottom: 6,
      ),
      _p('El reporte incluye:', bottom: 6),
      _numbered([
        [_t('Encabezado con equipos, fecha, torneo, instancia, categoría y cancha.')],
        [_t('Resultado de cada set y el equipo ganador del partido.')],
        [_t('La tabla de estadística completa por jugador (la misma información que en la sección 13), con una referencia al pie que explica cada abreviatura.')],
        [_t('Una tabla con los errores del rival por tipo (saque, ataque, contra, genérico) y los puntos que ganó con su propio toque (ataque o contra).')],
        [_t('Si se registraron zonas de destino durante el partido: un desglose de saque, ataque y contraataque por separado, por zona de cancha (1 a 6), tanto a nivel equipo como por jugador.')],
        [_t('Si el partido tuvo más de un set: el detalle de estadística de cada set por separado.')],
      ]),
      _infoBox(
        'Nota: el reporte en PDF es, hoy, la única forma de sacar los datos de un partido fuera del '
        'dispositivo. Conviene exportarlo y guardarlo (o enviarlo al cuerpo técnico) apenas termina cada '
        'partido importante.',
      ),
    ];

// ---------------------------------------------------------------------------
// 15. Glosario
// ---------------------------------------------------------------------------

List<pw.Widget> _section15Glosario() => [
      _sectionTitle(15, 'Glosario de calificaciones y abreviaturas'),
      _subHeading('Calificaciones de saque, ataque y contraataque'),
      _table(
        headers: ['', 'Significado'],
        flex: [2, 8],
        pillFirstColumn: true,
        rows: [
          ['PP', 'Punto (Doble Positiva): punto directo, el toque termina el punto a favor propio.'],
          ['P', 'Positiva: toque bueno, el punto sigue en juego.'],
          ['N', 'Negativa: toque que dificulta la jugada propia pero no termina el punto.'],
          ['BLOQ', 'Bloqueado: solo en ataque/contra, el toque fue bloqueado por el rival (termina el punto en contra).'],
          ['NN', 'Error (Doble Negativa): el toque termina el punto a favor del rival.'],
        ],
      ),
      pw.SizedBox(height: 14),
      _subHeading('Calificaciones de recepción'),
      _table(
        headers: ['', 'Significado'],
        flex: [2, 8],
        pillFirstColumn: true,
        rows: [
          ['PP', 'Perfecta (Doble Positiva): recepción perfecta.'],
          ['P', 'Positiva: recepción buena.'],
          ['!', 'Exclamativa: recepción efectiva.'],
          ['N', 'Negativa: recepción negativa.'],
          ['V/', 'Vendida: recepción muy negativa, prácticamente regalada al rival.'],
          ['NN', 'Error (Doble Negativa): error de recepción, termina el punto a favor del rival.'],
        ],
      ),
      pw.SizedBox(height: 14),
      _subHeading('Abreviaturas de la tabla de estadísticas'),
      _table(
        headers: ['', 'Significado'],
        flex: [3, 7],
        rows: [
          ['Pts', 'Puntos totales convertidos por el jugador (o por el equipo).'],
          ['Err', 'Errores totales cometidos.'],
          ['Saq / Atq / Ctr', 'Saque / Ataque / Contraataque.'],
          ['Saq %', 'Efectividad de saque: (PP + P) / total de saques.'],
          ['Atq % / Ctr %', 'Efectividad de ataque / contraataque: PP / total de toques (PP + P + N + Bl + NN).'],
          ['Blq', 'Puntos de bloqueo.'],
          ['E. Gen', 'Errores genéricos (rotación, cuatro toques, etc.).'],
          ['Rec Tot', 'Total de recepciones registradas.'],
          ['Rec %', 'Efectividad de recepción: (PP + P) / total de recepciones.'],
          [
            'ARM · OP · CEN · P/R · LIB · UNI',
            'Posiciones: Armador · Opuesto · Central · Punta/Receptor · Líbero · Universal.'
          ],
          ['Z1 a Z6', 'Zonas de destino de la cancha rival, numeradas de frente para quien anota.'],
        ],
      ),
    ];

// ---------------------------------------------------------------------------
// 16. Preguntas frecuentes
// ---------------------------------------------------------------------------

List<pw.Widget> _section16Faq() => [
      _sectionTitle(16, 'Preguntas frecuentes'),
      _faqCard(
        '¿Dónde se guardan los datos de la app?',
        'Todo se guarda de forma local en el dispositivo (equipos, jugadores y partidos). Desinstalar la '
            'app o borrar sus datos elimina también esa información, así que conviene exportar en PDF los '
            'partidos que se quieran conservar.',
      ),
      _faqCard(
        '¿Cuántos partidos puedo cargar en el Archivo de Partidos?',
        'No hay un límite fijo: la app no pone ningún tope a la cantidad de partidos guardados. En la '
            'práctica, el único límite es el espacio libre en el dispositivo, y como cada partido ocupa muy '
            'poco, se pueden acumular miles de partidos sin problema.',
      ),
      _faqCard(
        '¿Qué versión de Android necesito para usar RallyStats?',
        'RallyStats necesita Android 7.0 (API 24) o superior. Se recomienda mantener el sistema operativo '
            'del celular o la tablet actualizado para un mejor funcionamiento.',
      ),
      _faqCard(
        '¿Qué necesito para usar RallyStats en Windows (PC o notebook)?',
        'Hace falta Windows 10 de 64 bits o superior (Windows 11 incluido); no funciona en Windows 7, 8 / '
            '8.1 ni en versiones de 32 bits. La versión de Windows es un ejecutable (volley_stats_app.exe) '
            'que no requiere instalación, pero viene acompañado de varios archivos .dll necesarios para que '
            'funcione: hay que conservar todos los archivos de la carpeta juntos (no alcanza con copiar '
            'solo el .exe a otro lado) y ejecutarlo desde ahí. Tiene las mismas funciones que la versión de '
            'Android.',
      ),
      _faqCard(
        '¿Necesito conexión a internet para poder tomar la estadística?',
        'No. RallyStats funciona completamente sin conexión: la carga en vivo, las planillas de equipo y el '
            'cálculo de estadísticas se hacen en el dispositivo. Solo hace falta conexión para acciones '
            'puntuales que dependen del sistema operativo, como enviar el reporte en PDF por WhatsApp o '
            'correo (sección 14).',
      ),
      _faqCard(
        '¿Qué pasa si la aplicación deja de funcionar mientras estoy anotando? ¿Pierdo el progreso?',
        'No debería perderse: cada toque, punto, cambio de jugador o sanción se guarda en el dispositivo apenas se '
            'carga, sin esperar a que termine el set ni el partido. Si la app se cierra sola, se traba o el '
            'celular se apaga, al volver a abrirla el partido va a aparecer "en curso" en Archivo de '
            'Partidos (sección 12) y se puede retomar exactamente donde había quedado. Como mucho se puede '
            'llegar a perder la última acción que se estaba por confirmar justo en el momento del cierre.',
      ),
      _faqCard(
        '¿Puedo pasar un partido de un celular a otro, o verlo en dos dispositivos a la vez?',
        'Se puede pasar un partido a otro dispositivo exportándolo (sección 12.1) e importándolo ahí '
            '(sección 12.2); a diferencia del reporte en PDF (sección 14), que es solo para leer, ese '
            'archivo se puede volver a abrir en la app, incluso si el partido todavía estaba en curso. Lo '
            'que no se puede hacer es cargar el mismo partido en vivo desde dos dispositivos a la vez: una '
            'vez importada, cada copia queda independiente y no se sincroniza sola con el original.',
      ),
      _faqCard(
        '¿Puedo cambiar los datos de un equipo ya creado?',
        'Sí. Desde "Equipos", tocá el equipo que querés modificar para entrar a "Editar equipo": ahí se '
            'puede cambiar el nombre, agregar o quitar jugadores, y editar los datos de cada uno (nombre, '
            'número, posición, edad o fecha de nacimiento, altura, peso, alcances y mano de ataque). Los '
            'cambios se guardan automáticamente, igual que al crear el equipo (sección 3.1).',
      ),
      _faqCard(
        '¿Hace falta cargar el equipo rival como equipo propio antes de jugar?',
        'No. En "Datos del rival y del partido" (sección 4.1) alcanza con escribir el nombre del rival a '
            'mano. Precargarlo como equipo propio en "Equipos" es opcional, y solo sirve para autocompletar '
            'el nombre más rápido si se enfrenta seguido al mismo rival.',
      ),
      _faqCard(
        'Me equivoqué al cargar un toque, ¿cómo lo corrijo?',
        'Usá el botón de Deshacer en el encabezado de la pantalla en vivo, tantas veces como haga falta; '
            'deshace de a una acción por vez, empezando por la última (sea un toque, un cambio de jugador '
            'manual o una sanción/tarjeta), respetando siempre el orden en que se cargaron.',
      ),
      _faqCard(
        'Me equivoqué en un cambio de jugador, ¿cómo lo corrijo?',
        'Desde el panel de Cambio de jugador, tocá Deshacer último cambio (sección 8.3). Solo funciona '
            'para el cambio más reciente del set y, si era un cambio regular, no queda contado contra el '
            'cupo de cambios.',
      ),
      _faqCard(
        '¿Para qué sirve "Simular resto del set"?',
        'Carga automáticamente puntos al azar hasta terminar el set. Sirve para probar rápidamente la app o '
            'demostrar su funcionamiento sin tener que cargar cada toque a mano; no está pensado para usarse '
            'durante un partido real.',
      ),
      _faqCard(
        '¿Puedo cambiar la configuración de sets o de cambios una vez arrancado el partido?',
        'No: la configuración se define al crear el partido (sección 4.2) y se mantiene durante todos sus '
            'sets.',
      ),
      _faqCard(
        '¿Qué pasa si abandono un partido por error?',
        '"Abandonar partido" borra el partido por completo y no se puede deshacer. Si el partido ya tenía '
            'un set terminado o estaba definido, se recomienda exportar el PDF (sección 14) antes de '
            'abandonarlo, por si se necesitan esos datos más adelante.',
      ),
      _faqCard(
        '¿Puedo corregir las estadísticas de un partido que ya terminó?',
        'No directamente. Sí hay margen para corregir un punto justo al final de un set (por ejemplo, si el '
            'árbitro revierte el último punto): mientras un set no se haya confirmado con el botón Confirmar '
            'fin de set del encabezado (sección 10 y sección 11), Deshacer sigue funcionando con normalidad, '
            'aunque el marcador ya haya llegado al puntaje que cierra el set. Una vez confirmado ese botón, '
            'el set queda bloqueado y ya no se puede deshacer nada de ahí; lo mismo pasa con el partido '
            'entero al confirmar el set decisivo. Si un partido ya confirmado tiene un error importante, se '
            'puede eliminar desde el menú de tres puntos en Archivo de Partidos (sección 12) y cargarlo de '
            'nuevo desde cero.',
      ),
      _faqCard(
        '¿El líbero puede sacar?',
        'No. Por eso la app no permite que un líbero entre en el puesto que está a punto de sacar (posición '
            '1 cuando saca el equipo propio); ver la sección 8.2.',
      ),
      _faqCard(
        '¿Cómo cambio entre modo claro y modo oscuro?',
        'Con el interruptor de modo claro / modo oscuro (ícono de sol / luna) que aparece en la esquina '
            'superior derecha de casi cualquier pantalla de la app (ver sección 2); en la pantalla de '
            'partido en vivo está dentro del menú "Más opciones" del encabezado (sección 10). La elección '
            'queda guardada en el dispositivo.',
      ),
      _faqCard(
        '¿RallyStats está disponible en iOS (iPhone/iPad)?',
        'Todavía no. El proyecto está hecho en Flutter, que sí permite compilar para iOS, pero esa parte '
            'todavía no se armó ni se probó: para hacerlo hace falta una Mac con Xcode, algo que hoy no '
            'forma parte del flujo de trabajo del proyecto. Por ahora, RallyStats está disponible para '
            'Android y, como versión de escritorio, para Windows (ver la pregunta anterior); para iOS y '
            'para Mac todavía no.',
      ),
    ];

// ---------------------------------------------------------------------------
// 17. Contacto
// ---------------------------------------------------------------------------

List<pw.Widget> _section17Contacto() => [
      _sectionTitle(17, 'Contacto'),
      _p(
        'Para consultas, reportar un problema o sugerir una mejora para RallyStats, podés escribir a:',
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(color: _surfaceAlt, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text('ezecastiglione18@gmail.com',
            style: pw.TextStyle(color: _navy, fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 24),
      pw.Container(height: 0.75, color: _border),
      pw.SizedBox(height: 16),
      pw.Center(
        child: pw.Text(
          'Fin del manual. Ante cualquier duda adicional, este documento puede actualizarse a medida que '
          'la app incorpore nuevas funciones.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _textGrey, fontSize: 9.5),
        ),
      ),
    ];
