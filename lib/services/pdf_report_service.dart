import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/stat_line.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

class PdfReportService {
  /// Fondo suave para resaltar la fila del líbero en la tabla de
  /// estadísticas (el resto de las filas queda en blanco).
  static const _liberoRowColor = PdfColor.fromInt(0xFFDCEFFA);

  static Future<void> shareMatchReport(VolleyMatch match) async {
    final bytes = await _buildPdf(match);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(match));
  }

  static Future<void> printMatchReport(VolleyMatch match) async {
    final bytes = await _buildPdf(match);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static String _fileName(VolleyMatch match) {
    final d = DateFormat('yyyyMMdd').format(match.date);
    final rival = match.rivalTeamName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'partido_${d}_$rival.pdf';
  }

  static Future<Uint8List> _buildPdf(VolleyMatch match) async {
    final doc = pw.Document();
    final stats = StatsEngine.compute(match);
    final zones = StatsEngine.computeZones(match);
    final dateStr = DateFormat('dd/MM/yyyy').format(match.date);
    final winnerText = _matchWinnerText(match);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => _header(match, dateStr),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          // Inseparable: si no entra en lo que queda de la hoja pero sí en una
          // hoja completa, pasa entero a la siguiente en lugar de partirse.
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _setScoreTable(match),
                if (winnerText != null) ...[
                  pw.SizedBox(height: 6),
                  winnerText,
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Estadística del partido - ${match.ownTeamName}',
                    style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _statsTable(stats),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Errores y puntos del rival',
                    style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _rivalStatsTable(stats),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          if (zones.hasAnyData) ...[
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Zonas de destino de saque, ataque y contraataque',
                      style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Zonas 1 a 6 de la cancha rival (numeración estándar). '
                    'Solo se cuentan los toques con zona registrada.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _zoneTable('Saque por zona', zones.serveByZone)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _zoneTable('Ataque por zona', zones.attackByZone)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _zoneTable('Contraataque por zona', zones.counterByZone)),
                    ],
                  ),
                ],
              ),
            ),
            if (zones.serveByZoneByPlayer.isNotEmpty ||
                zones.attackByZoneByPlayer.isNotEmpty ||
                zones.counterByZoneByPlayer.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              if (zones.serveByZoneByPlayer.isNotEmpty) ...[
                pw.Inseparable(
                  child: _zonePlayerTable('Saque por zona y jugador', zones.serveByZoneByPlayer, stats),
                ),
                pw.SizedBox(height: 10),
              ],
              if (zones.attackByZoneByPlayer.isNotEmpty) ...[
                pw.Inseparable(
                  child: _zonePlayerTable('Ataque por zona y jugador', zones.attackByZoneByPlayer, stats),
                ),
                pw.SizedBox(height: 10),
              ],
              if (zones.counterByZoneByPlayer.isNotEmpty) ...[
                pw.Inseparable(
                  child: _zonePlayerTable(
                      'Contraataque por zona y jugador', zones.counterByZoneByPlayer, stats),
                ),
              ],
            ],
            pw.SizedBox(height: 16),
          ],
          if (match.sets.length > 1) ...[
            pw.Text('Detalle por set', style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final set in match.sets) ...[
              pw.Inseparable(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Set ${set.setNumber} (${set.ownScore}-${set.rivalScore})',
                        style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    _statsTable(StatsEngine.compute(match, setNumber: set.setNumber), compact: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// Línea con el equipo ganador del partido (en sets), o null si todavía
  /// está empatado en sets (partido sin definir).
  static pw.Widget? _matchWinnerText(VolleyMatch match) {
    final ownWon = match.ownSetsWon;
    final rivalWon = match.rivalSetsWon;
    if (ownWon == rivalWon) return null;
    final winnerName = ownWon > rivalWon ? match.ownTeamName : match.rivalTeamName;
    return pw.Text(
      'Equipo ganador: $winnerName ($ownWon-$rivalWon)',
      style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _header(VolleyMatch match, String dateStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Estadísticas de Vóley', style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${match.ownTeamName}  vs  ${match.rivalTeamName}',
            style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 2),
        pw.Text(
          [
            'Fecha: $dateStr',
            if (match.tournament.isNotEmpty) 'Torneo: ${match.tournament}',
            if (match.round.isNotEmpty) 'Instancia: ${match.round}',
            if (match.category.isNotEmpty) 'Categoría: ${match.category}',
            if (match.court.isNotEmpty) 'Cancha: ${match.court}',
          ].join('   |   '),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _setScoreTable(VolleyMatch match) {
    final headers = ['Set', match.ownTeamName, match.rivalTeamName, 'Ganador'];
    final rows = match.sets.map((s) {
      final winnerLabel = s.winner == null
          ? '-'
          : (s.winner == TeamSide.own ? match.ownTeamName : match.rivalTeamName);
      return ['${s.setNumber}', '${s.ownScore}', '${s.rivalScore}', winnerLabel];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Widget _statsTable(MatchStats stats, {bool compact = false}) {
    final rows = stats.orderedRows.map((r) {
      final effPct = r.recepcion.efficiency;
      return [
        r.playerId == unassignedId ? '-' : '${r.number}',
        _playerLabel(r),
        '${r.totalPts}',
        '${r.totalErr}',
        '${r.saque.pp}',
        '${r.saque.p}',
        '${r.saque.n}',
        '${r.saque.nn}',
        '${r.ataque.pp}',
        '${r.ataque.p}',
        '${r.ataque.n}',
        '${r.ataque.bloq}',
        '${r.ataque.nn}',
        '${r.contra.pp}',
        '${r.contra.p}',
        '${r.contra.n}',
        '${r.contra.bloq}',
        '${r.contra.nn}',
        '${r.bloqueoPts}',
        '${r.errGen}',
        '${r.recepcion.total}',
        '${r.recepcion.pp}',
        '${r.recepcion.p}',
        '${r.recepcion.excl}',
        '${r.recepcion.n}',
        '${r.recepcion.vNeg}',
        '${r.recepcion.nn}',
        effPct == null ? '-' : '${(effPct * 100).toStringAsFixed(0)}%',
      ];
    }).toList();

    // Marca qué filas son de un líbero, para resaltarlas con un color de
    // fondo suave (la fila de TOTAL EQUIPO, al final, nunca lo es).
    final isLiberoRow = [
      for (final r in stats.orderedRows) r.position == PlayerPosition.libero,
      false,
    ];

    // Fila de totales del equipo.
    final t = stats.team;
    rows.add([
      '',
      'TOTAL EQUIPO',
      '${t.totalPts}',
      '${t.totalErr}',
      '${t.saque.pp}',
      '${t.saque.p}',
      '${t.saque.n}',
      '${t.saque.nn}',
      '${t.ataque.pp}',
      '${t.ataque.p}',
      '${t.ataque.n}',
      '${t.ataque.bloq}',
      '${t.ataque.nn}',
      '${t.contra.pp}',
      '${t.contra.p}',
      '${t.contra.n}',
      '${t.contra.bloq}',
      '${t.contra.nn}',
      '${t.bloqueoPts}',
      '${t.errGen}',
      '${t.recepcion.total}',
      '${t.recepcion.pp}',
      '${t.recepcion.p}',
      '${t.recepcion.excl}',
      '${t.recepcion.n}',
      '${t.recepcion.vNeg}',
      '${t.recepcion.nn}',
      t.recepcion.efficiency == null
          ? '-'
          : '${(t.recepcion.efficiency! * 100).toStringAsFixed(0)}%',
    ]);

    final columnWidths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < _statCols.length; i++) i: pw.FlexColumnWidth(_statCols[i].flex.toDouble()),
    };
    final fontSize = compact ? 6.5 : 7.5;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _statsGroupBand(compact),
        pw.TableHelper.fromTextArray(
          headers: [for (final c in _statCols) c.label],
          data: rows,
          columnWidths: columnWidths,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
          cellStyle: pw.TextStyle(fontSize: fontSize),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          // Filas blancas para el resto del equipo; solo se resalta con un
          // celeste suave la fila del líbero, para diferenciarla a simple
          // vista sin depender de alternar colores par/impar.
          cellDecoration: (index, data, rowNum) {
            final dataRow = rowNum - 1;
            final isLibero = dataRow >= 0 && dataRow < isLiberoRow.length && isLiberoRow[dataRow];
            return pw.BoxDecoration(color: isLibero ? _liberoRowColor : PdfColors.white);
          },
          cellAlignment: pw.Alignment.center,
          cellAlignments: {
            for (var i = 0; i < _statCols.length; i++)
              if (_statCols[i].alignLeft) i: pw.Alignment.centerLeft,
          },
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Referencias - Saque/Ataque/Contra: PP Punto (Doble Positiva) · P Positiva · N Negativa · '
          'Bl Bloqueado · NN Error (Doble Negativa).  Recepción: PP Perfecta (Doble Positiva) · P Positiva · '
          '! Exclamativa · N Negativa · V/ Vendida · NN Error (Doble Negativa).  Pts puntos · Err errores totales · Blq Pts puntos de bloqueo · '
          'Err Gen errores generales · Tot toques totales · % efectividad de recepción.  $_positionLegend',
          style: pw.TextStyle(fontSize: compact ? 5.5 : 6.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// Nombre del jugador para mostrar en las tablas, con la posición
  /// abreviada entre paréntesis (ver [_positionLegend]).
  static String _playerLabel(PlayerStatLine r) {
    final pos = r.position;
    return pos == null ? r.displayName : '${r.displayName} (${pos.shortLabel})';
  }

  static const String _positionLegend =
      'Posición: ARM Armador · OP Opuesto · CEN Central · P/R Punta/Receptor · LIB Líbero.';

  /// Especificación de columnas de la tabla de estadística por jugador:
  /// [flex] define el ancho relativo (misma unidad usada en la banda de
  /// categorías y en la tabla de datos, para que ambas queden alineadas).
  static const List<_StatCol> _statCols = [
    _StatCol('N°', 8),
    _StatCol('Jugador', 48, alignLeft: true),
    _StatCol('Pts', 9),
    _StatCol('Err', 9),
    _StatCol('PP', 9, group: 'Saque'),
    _StatCol('P', 9, group: 'Saque'),
    _StatCol('N', 9, group: 'Saque'),
    _StatCol('NN', 9, group: 'Saque'),
    _StatCol('PP', 9, group: 'Ataque'),
    _StatCol('P', 9, group: 'Ataque'),
    _StatCol('N', 9, group: 'Ataque'),
    _StatCol('Bl', 9, group: 'Ataque'),
    _StatCol('NN', 9, group: 'Ataque'),
    _StatCol('PP', 9, group: 'Contraataque'),
    _StatCol('P', 9, group: 'Contraataque'),
    _StatCol('N', 9, group: 'Contraataque'),
    _StatCol('Bl', 9, group: 'Contraataque'),
    _StatCol('NN', 9, group: 'Contraataque'),
    _StatCol('Blq Pts', 13),
    _StatCol('Err Gen', 13),
    _StatCol('Tot', 9, group: 'Recepción'),
    _StatCol('PP', 9, group: 'Recepción'),
    _StatCol('P', 9, group: 'Recepción'),
    _StatCol('!', 8, group: 'Recepción'),
    _StatCol('N', 9, group: 'Recepción'),
    _StatCol('V/', 9, group: 'Recepción'),
    _StatCol('NN', 9, group: 'Recepción'),
    _StatCol('%', 10, group: 'Recepción'),
  ];

  /// Banda superior con los títulos de categoría (Saque, Ataque, etc.),
  /// agrupando visualmente las columnas de [_statCols] que comparten
  /// [_StatCol.group]. Usa los mismos anchos relativos (flex) que las
  /// columnas de la tabla de datos para que ambas filas queden alineadas.
  static pw.Widget _statsGroupBand(bool compact) {
    final children = <pw.Widget>[];
    var i = 0;
    while (i < _statCols.length) {
      final group = _statCols[i].group;
      var flexSum = _statCols[i].flex;
      var j = i + 1;
      while (j < _statCols.length && _statCols[j].group == group) {
        flexSum += _statCols[j].flex;
        j++;
      }
      final bandHeight = compact ? 11.0 : 13.0;
      children.add(
        pw.Expanded(
          flex: flexSum,
          // Las columnas sin grupo (N°, Jugador, Pts, Err, Blq Pts, Err Gen)
          // no tienen un título que mostrar acá arriba, así que en vez de
          // dibujar el recuadro con color y borde vacío, dejamos el espacio
          // en blanco y sin decoración.
          child: group == null
              ? pw.SizedBox(height: bandHeight)
              : pw.Container(
                  height: bandHeight,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey100,
                    border: pw.Border(
                      left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                      right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                      top: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                    ),
                  ),
                  child: pw.Text(
                    group,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: compact ? 6.5 : 7.5,
                    ),
                  ),
                ),
        ),
      );
      i = j;
    }
    return pw.Row(children: children);
  }

  /// Desglose de saque o ataque por zona de destino, con una fila por
  /// jugador (solo los que registraron al menos un toque con zona).
  static pw.Widget _zonePlayerTable(
    String title,
    Map<String, Map<int, TouchStats>> byPlayerZone,
    MatchStats stats,
  ) {
    final rows = <List<String>>[];
    for (final r in stats.orderedRows) {
      final zoneMap = byPlayerZone[r.playerId];
      if (zoneMap == null) continue;
      final totals = zoneMap.values.fold<TouchStats>(TouchStats(), (acc, s) {
        acc.pp += s.pp;
        acc.p += s.p;
        acc.n += s.n;
        acc.nn += s.nn;
        acc.bloq += s.bloq;
        return acc;
      });
      if (totals.total == 0) continue;
      final effPct = (totals.pp + totals.p) / totals.total;
      rows.add([
        r.playerId == unassignedId ? '-' : '${r.number}',
        _playerLabel(r),
        for (var z = 1; z <= 6; z++) '${zoneMap[z]!.total}',
        '${totals.total}',
        '${(effPct * 100).toStringAsFixed(0)}%',
      ]);
    }

    if (rows.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          headers: const ['N°', 'Jugador', 'Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Total', '% Efec'],
          data: rows,
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(4.6),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1),
            5: pw.FlexColumnWidth(1),
            6: pw.FlexColumnWidth(1),
            7: pw.FlexColumnWidth(1),
            8: pw.FlexColumnWidth(1.2),
            9: pw.FlexColumnWidth(1.4),
          },
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellAlignment: pw.Alignment.center,
          cellAlignments: const {1: pw.Alignment.centerLeft},
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Referencias: Z1-Z6 zona de destino de cada toque (numeración estándar) · '
          'Total toques con zona registrada · % Efec = (PP+P) / Total.  $_positionLegend',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// Tabla con los errores del rival por tipo de toque (a favor del equipo
  /// propio) y los puntos que ganó el rival con su propio toque, a nivel de
  /// partido completo.
  static pw.Widget _rivalStatsTable(MatchStats stats) {
    final err = stats.rivalErrors;
    final pts = stats.rivalPoints;
    final showUnclassified = pts.unclassified > 0;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Table.fromTextArray(
            headers: const ['Error Saque', 'Error Ataque', 'Error Contra', 'Error Genérico', 'Total'],
            data: [
              ['${err.serve}', '${err.attack}', '${err.counter}', '${err.generic}', '${err.total}'],
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellAlignment: pw.Alignment.center,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Table.fromTextArray(
            headers: [
              'Punto Ataque',
              'Punto Contra',
              if (showUnclassified) 'Sin clasificar',
              'Total',
            ],
            data: [
              [
                '${pts.attack}',
                '${pts.counter}',
                if (showUnclassified) '${pts.unclassified}',
                '${pts.total}',
              ],
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellAlignment: pw.Alignment.center,
          ),
        ),
      ],
    );
  }

  static pw.Widget _zoneTable(String title, Map<int, TouchStats> byZone) {
    final includeBloq = byZone.values.any((s) => s.bloq > 0);
    final headers = ['Zona', 'Total', 'PP', 'P', 'N', if (includeBloq) 'BLOQ', 'NN'];

    final rows = [
      for (var zone = 1; zone <= 6; zone++)
        [
          '$zone',
          '${byZone[zone]!.total}',
          '${byZone[zone]!.pp}',
          '${byZone[zone]!.p}',
          '${byZone[zone]!.n}',
          if (includeBloq) '${byZone[zone]!.bloq}',
          '${byZone[zone]!.nn}',
        ],
    ];

    final totalAll = byZone.values.fold<TouchStats>(TouchStats(), (acc, s) {
      acc.pp += s.pp;
      acc.p += s.p;
      acc.n += s.n;
      acc.nn += s.nn;
      acc.bloq += s.bloq;
      return acc;
    });
    rows.add([
      'Total',
      '${totalAll.total}',
      '${totalAll.pp}',
      '${totalAll.p}',
      '${totalAll.n}',
      if (includeBloq) '${totalAll.bloq}',
      '${totalAll.nn}',
    ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellAlignment: pw.Alignment.center,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Referencias: PP Punto (Doble Positiva) · P Positiva · N Negativa'
          '${includeBloq ? ' · BLOQ Bloqueado' : ''} · NN Error (Doble Negativa).',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
      ],
    );
  }
}

/// Columna de la tabla de estadística por jugador ([PdfReportService._statsTable]).
/// [flex] es el ancho relativo de la columna; [group] agrupa columnas
/// contiguas bajo un mismo título en la banda de categorías (null = sin
/// grupo, la columna solo se ve en la fila de sub-encabezados).
class _StatCol {
  const _StatCol(this.label, this.flex, {this.group, this.alignLeft = false});

  final String label;
  final int flex;
  final String? group;
  final bool alignLeft;
}
