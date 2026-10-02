import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/player.dart';
import '../models/rally_event.dart';
import '../models/sanction_event.dart';
import '../models/stat_line.dart';
import '../models/visual_stats.dart';
import '../models/volley_match.dart';
import 'pdf_charts.dart';
import 'stats_engine.dart';
import '../utils/court_geometry.dart';

class PdfReportService {
  /// Fondo suave para resaltar la fila del líbero en la tabla de
  /// estadísticas (el resto de las filas queda en blanco).
  static const _liberoRowColor = PdfColor.fromInt(0xFFDCEFFA);

  /// [charts] son los gráficos de la estadística visual a agregar al final y
  /// [maps] las columnas de la planilla de mapas por jugador (ver
  /// `VisualStatsPreferences.pdfCharts` / `pdfMaps`); vacíos = sin esa sección.
  static Future<void> shareMatchReport(VolleyMatch match,
      {Set<VisualChart> charts = const {}, Set<ShotKind> maps = const {}}) async {
    final bytes = await buildPdf(match, charts: charts, maps: maps);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(match));
  }

  static Future<void> printMatchReport(VolleyMatch match,
      {Set<VisualChart> charts = const {}, Set<ShotKind> maps = const {}}) async {
    final bytes = await buildPdf(match, charts: charts, maps: maps);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static String _fileName(VolleyMatch match) {
    final d = DateFormat('yyyyMMdd').format(match.date);
    final rival = match.rivalTeamName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'partido_${d}_$rival.pdf';
  }

  @visibleForTesting
  static Future<Uint8List> buildPdf(VolleyMatch match,
      {Set<VisualChart> charts = const {}, Set<ShotKind> maps = const {}}) async {
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
          if (match.sets.any((s) => s.sanctions.isNotEmpty)) ...[
            pw.SizedBox(height: 12),
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Sanciones',
                      style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  _sanctionsTable(match),
                ],
              ),
            ),
          ],
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
                    'Zonas 1 a ${zones.displayZones.last} de la cancha rival (numeración estándar'
                    '${zones.hasMiddleZoneData ? '; 7-8-9 = franja media' : ''}). '
                    'Solo se cuentan los toques con zona registrada.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _zoneTable('Saque por zona', zones.serveByZone, zones.displayZones)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _zoneTable('Ataque por zona', zones.attackByZone, zones.displayZones)),
                      pw.SizedBox(width: 12),
                      pw.Expanded(child: _zoneTable('Contraataque por zona', zones.counterByZone, zones.displayZones)),
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
                  child: _zonePlayerTable('Saque por zona y jugador', zones.serveByZoneByPlayer, stats, zones.displayZones),
                ),
                pw.SizedBox(height: 10),
              ],
              if (zones.attackByZoneByPlayer.isNotEmpty) ...[
                pw.Inseparable(
                  child: _zonePlayerTable('Ataque por zona y jugador', zones.attackByZoneByPlayer, stats, zones.displayZones),
                ),
                pw.SizedBox(height: 10),
              ],
              if (zones.counterByZoneByPlayer.isNotEmpty) ...[
                pw.Inseparable(
                  child: _zonePlayerTable(
                      'Contraataque por zona y jugador', zones.counterByZoneByPlayer, stats, zones.displayZones),
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
          ..._visualSection(match, stats, zones, charts),
          ..._mapsSection(match, stats, maps),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- Estadística visual ----------------
  //
  // Mismos cálculos que la pestaña "Gráficos" (StatsEngine), siempre sobre el
  // partido completo. Ver documents/spec-estadistica-visual.md, sección 4.3.

  static const double _pageW = 794; // A4 apaisado menos los márgenes de 24

  static List<pw.Widget> _visualSection(
      VolleyMatch match, MatchStats stats, ZoneStats zones, Set<VisualChart> charts) {
    final rotations = StatsEngine.computeRotations(match);
    if (charts.isEmpty || !rotations.hasData) return [];

    final out = <pw.Widget>[
      pw.NewPage(),
      pw.Text('Estadística visual', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text('Partido completo. Calculada a partir de cada punto cargado.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ];
    for (final chart in VisualChart.values.where(charts.contains)) {
      out.add(pw.SizedBox(height: 12));
      switch (chart) {
        case VisualChart.dashboard:
          out.add(pw.Inseparable(child: _chartBlock(chart, null, _pdfDashboard(rotations, stats))));
          break;
        case VisualChart.rotations:
          out.add(pw.Inseparable(child: _chartBlock(chart, 'P1 = armador en zona 1. G-P = puntos ganados menos perdidos en cada rotación.', _pdfRotations(rotations))));
          break;
        case VisualChart.sideOutBreak:
          out.add(pw.Inseparable(child: _chartBlock(chart, null, _pdfSideOutBreak(rotations))));
          break;
        case VisualChart.timeline:
          out.addAll(_pdfTimelines(StatsEngine.computeTimelines(match)));
          break;
        case VisualChart.pointOrigin:
          out.add(pw.Inseparable(
              child: _chartBlock(chart, 'De qué salieron los puntos ganados y cómo se perdieron los perdidos.',
                  _pdfPointOrigin(StatsEngine.computePointOrigin(match)))));
          break;
        case VisualChart.attackEfficiency:
          out.add(pw.Inseparable(
              child: _chartBlock(chart, 'Ataque + contra. Eficiencia = (puntos - errores - bloqueados) / total.',
                  _pdfAttackEfficiency(stats))));
          break;
        case VisualChart.reception:
          out.add(pw.Inseparable(
              child: _chartBlock(chart, 'Cada barra suma el 100 % de las recepciones del jugador. A la derecha, '
                  '(PP + P) / total y la cantidad.', _pdfReception(stats))));
          break;
        case VisualChart.heatmap:
          if (zones.hasAnyData) {
            out.add(pw.Inseparable(
                child: _chartBlock(chart, 'Zonas de la cancha rival (fondo arriba, red abajo). Más oscuro = más '
                    'toques; debajo, el % que terminó en punto.', _pdfHeatmaps(zones))));
          }
          break;
      }
    }
    return out;
  }

  /// Planilla de mapas por jugador (Etapa 2 de la spec, sección 5.3): un
  /// bloque por jugador con toques, con una cancha por fundamento elegido y
  /// su resumen debajo. Los bloques se acomodan en filas (las que entran en
  /// el ancho de la hoja), para que el salto de página nunca corte una cancha.
  static List<pw.Widget> _mapsSection(VolleyMatch match, MatchStats stats, Set<ShotKind> maps) {
    final kinds = [for (final k in ShotKind.values) if (maps.contains(k)) k];
    if (kinds.isEmpty) return [];
    final data = StatsEngine.computeShots(match);
    final players = [
      for (final l in stats.orderedRows)
        if (l.playerId != unassignedId && kinds.any((k) => touchStatsOf(l, k).total > 0)) l,
    ];
    if (players.isEmpty || data.shots.isEmpty) return [];

    const courtW = 105.0, labelW = 46.0, gap = 6.0, blockGap = 16.0;
    final blockW = labelW + gap + kinds.length * (courtW + gap);
    final perRow = ((_pageW + blockGap) / (blockW + blockGap)).floor().clamp(1, 4);

    pw.Widget caption(PlayerStatLine l, ShotKind k) {
      final s = shotSummary(touchStatsOf(l, k));
      if (s.total == 0) return pw.Text('Sin toques', style: const pw.TextStyle(fontSize: 6.5, color: pdfMuted));
      final eff = s.efficiency!;
      final missing = data.missingZone(k, playerId: l.playerId);
      return pw.RichText(
        text: pw.TextSpan(style: const pw.TextStyle(fontSize: 6.5, color: pdfMuted), children: [
          pw.TextSpan(text: '${s.total} ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdfText)),
          const pw.TextSpan(text: 'tot · '),
          pw.TextSpan(text: '${s.points} pts', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdfPositive)),
          pw.TextSpan(text: ' · ${s.errors} err · Ef '),
          pw.TextSpan(
            text: '${eff > 0 ? '+' : ''}${(eff * 100).round()}%',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: eff >= 0 ? pdfPositive : pdfNegative),
          ),
          if (missing > 0) pw.TextSpan(text: ' · $missing sin zona'),
        ]),
      );
    }

    pw.Widget block(PlayerStatLine l) {
      final courtH = CourtGeometry.heightForWidth(courtW);
      return pw.SizedBox(
        width: blockW,
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: labelW,
            height: courtH + 22,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(color: pdfNavy, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Text('#${l.number}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              if (l.position != null)
                pw.Text(l.position!.shortLabel, style: const pw.TextStyle(color: pdfCyan, fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Text(l.displayName.split(',').first,
                    textAlign: pw.TextAlign.center, maxLines: 2, style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.5)),
              ),
            ]),
          ),
          pw.SizedBox(width: gap),
          for (final k in kinds) ...[
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(k.label, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: pdfNavy)),
              pw.SizedBox(height: 2),
              pdfCourtShots(courtW, data.where(k, playerId: l.playerId)),
              pw.SizedBox(height: 2),
              pw.SizedBox(width: courtW, child: caption(l, k)),
            ]),
            pw.SizedBox(width: gap),
          ],
        ]),
      );
    }

    final rows = <pw.Widget>[];
    for (var i = 0; i < players.length; i += perRow) {
      rows.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        for (var j = i; j < i + perRow && j < players.length; j++) ...[
          block(players[j]),
          if (j < i + perRow - 1) pw.SizedBox(width: blockGap),
        ],
      ]));
    }

    return [
      pw.NewPage(),
      pw.Inseparable(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Mapas de dirección por jugador', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Partido completo. Cada flecha es un toque: sale del lugar deducido por el puesto y la rotación del '
            'jugador y termina en la zona registrada. Los toques sin zona de destino no se dibujan.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pdfShotLegend([
            ShotResult.point,
            ShotResult.inPlay,
            for (final r in [ShotResult.out, ShotResult.net])
              if (data.shots.any((s) => s.result == r)) r,
            ShotResult.error,
            ShotResult.blocked,
          ]),
          pw.SizedBox(height: 8),
          rows.first,
        ]),
      ),
      for (final r in rows.skip(1)) ...[pw.SizedBox(height: 10), r],
    ];
  }

  static pw.Widget _chartBlock(VisualChart chart, String? help, pw.Widget body) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(chart.label, style: const pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: pdfNavy)),
          if (help != null) pw.Text(help, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          body,
        ],
      );

  static pw.Widget _pdfDashboard(RotationStats rotations, MatchStats stats) {
    final t = rotations.total;
    final attack = AttackSummary.of(stats.team);
    String pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';
    pw.Widget tile(String label, String value, String sub, PdfColor color) => pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: pdfGrid, width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: pdfMuted)),
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 6.5, color: pdfMuted)),
          ]),
        );
    final eff = attack.efficiency;
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      tile('Side-out', pct(t.sideOutPct), 'rallies ganados recibiendo (${t.sideOutWon}/${t.receivingRallies})', pdfNavy),
      tile('Break-point', pct(t.breakPct), 'rallies ganados sacando (${t.breakWon}/${t.servingRallies})', pdfCyan),
      tile('Eficiencia de ataque', eff == null ? '-' : (eff > 0 ? '+${(eff * 100).round()}%' : '${(eff * 100).round()}%'),
          '(pts - err) / total', eff == null || eff >= 0 ? pdfPositive : pdfNegative),
      tile('Errores no forzados', '${unforcedErrorsOf(stats.team)}', 'saque + ataque + genérico', pdfNegative),
    ]);
  }

  static pw.Widget _rotationTable(List<RotationRow> rows, RotationRow? total) {
    final data = [
      for (final r in rows) rotationTableCells(r),
      if (total != null) rotationTableCells(total),
    ];
    return pw.TableHelper.fromTextArray(
      headers: rotationTableHeaders,
      data: data,
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: pdfNavy),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: pdfGrid, width: 0.5),
        bottom: pw.BorderSide(color: pdfGrid, width: 0.5),
      ),
    );
  }

  static pw.Widget _pdfRotations(RotationStats rotations) {
    final rows = rotations.mainRows;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pdfDivergingBars(290, 165, [for (final r in rows) r.label], [for (final r in rows) r.diff]),
        pw.SizedBox(width: 14),
        pw.Expanded(child: _rotationTable(rows, rotations.total)),
      ]),
      if (rotations.hasSeparateFallback) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          'Sets ${rotations.fallbackSets.join(', ')} agrupados aparte por no tener un único armador en la formación '
          'inicial (R1 = como arrancó el set):',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        _rotationTable(rotations.fallbackRows, null),
      ] else if (!rotations.hasSetterData)
        pw.Text(
          'Sin un único armador en la formación inicial: rotaciones contadas desde la formación inicial '
          '(R1 = como arrancó el set).',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
    ]);
  }

  static pw.Widget _pdfSideOutBreak(RotationStats rotations) {
    final rows = rotations.mainRows;
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pdfGroupedPctBars(420, 150, [for (final r in rows) r.label], [for (final r in rows) r.sideOutPct],
          [for (final r in rows) r.breakPct]),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pdfLegend([('Side-out', pdfNavy), ('Break-point', pdfCyan)]),
          pw.SizedBox(height: 6),
          pw.Text('Side-out: % de rallies ganados cuando saca el rival (recepción + K1).',
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 3),
          pw.Text('Break-point: % de rallies ganados con saque propio.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 3),
          pw.Text('Separa si una rotación falla recibiendo o sacando.', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    ]);
  }

  /// Un gráfico por set, de a dos por fila; el título va pegado a la
  /// primera fila para que no quede solo al pie de una hoja.
  static List<pw.Widget> _pdfTimelines(List<SetTimeline> timelines) {
    if (timelines.isEmpty) return [];
    const gap = 14.0;
    const w = (_pageW - gap) / 2;
    pw.Widget one(SetTimeline t) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Set ${t.setNumber} · ${t.ownScore}-${t.rivalScore}',
              style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pdfTimeline(w, 115, t),
        ]);
    final rows = <pw.Widget>[];
    for (var i = 0; i < timelines.length; i += 2) {
      rows.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        one(timelines[i]),
        if (i + 1 < timelines.length) ...[pw.SizedBox(width: gap), one(timelines[i + 1])],
      ]));
    }
    return [
      pw.Inseparable(
        child: _chartBlock(
          VisualChart.timeline,
          'Cada columna es un rally: arriba de la línea el equipo va ganando, abajo perdiendo. Se marcan las '
          'rachas de 4 o más puntos y, con un triángulo, los cambios de jugador.',
          rows.first,
        ),
      ),
      for (final r in rows.skip(1)) ...[pw.SizedBox(height: 6), pw.Inseparable(child: r)],
    ];
  }

  static PdfColor _categoryColor(RallyCategory c) {
    switch (c) {
      case RallyCategory.attackPoint:
        return pdfPositive;
      case RallyCategory.counterPoint:
        return pdfPositiveLight;
      case RallyCategory.blockPoint:
        return pdfNavy;
      case RallyCategory.servePoint:
        return pdfCyan;
      case RallyCategory.rivalError:
      case RallyCategory.otherWon:
        return pdfNeutral;
      case RallyCategory.attackError:
        return pdfNegative;
      case RallyCategory.attackBlocked:
        return pdfNegativeDark;
      case RallyCategory.serveError:
        return pdfSold;
      case RallyCategory.receptionError:
        return pdfWarning;
      case RallyCategory.genericError:
      case RallyCategory.otherLost:
        return pdfBlock;
      case RallyCategory.rivalPoint:
        return pdfSlate;
    }
  }

  static const _wonCategories = [
    (RallyCategory.attackPoint, 'Ataque'),
    (RallyCategory.counterPoint, 'Contra'),
    (RallyCategory.blockPoint, 'Bloqueo'),
    (RallyCategory.servePoint, 'Saque'),
    (RallyCategory.rivalError, 'Error rival'),
    (RallyCategory.otherWon, 'Otros'),
  ];

  static const _lostCategories = [
    (RallyCategory.attackError, 'Err. ataque'),
    (RallyCategory.attackBlocked, 'Bloqueado'),
    (RallyCategory.serveError, 'Err. saque'),
    (RallyCategory.receptionError, 'Err. recepción'),
    (RallyCategory.genericError, 'Err. genérico'),
    (RallyCategory.rivalPoint, 'Punto rival'),
    (RallyCategory.otherLost, 'Otros'),
  ];

  static pw.Widget _pdfPointOrigin(PointOriginStats origin) {
    pw.Widget bar(String title, int total, List<(RallyCategory, String)> cats) => pw.Row(children: [
          pw.SizedBox(width: 80, child: pw.Text('$title ($total)', style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
          pdfStackedBar(600, 14, [for (final (c, l) in cats) PdfSegment(l, origin.count(c), _categoryColor(c))]),
        ]);
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      bar('Ganados', origin.won, _wonCategories),
      pw.SizedBox(height: 4),
      bar('Perdidos', origin.lost, _lostCategories),
      pw.SizedBox(height: 5),
      pdfLegend([
        for (final (c, l) in [..._wonCategories, ..._lostCategories])
          if (origin.count(c) > 0) (l, _categoryColor(c)),
      ]),
    ]);
  }

  static pw.Widget _pdfAttackEfficiency(MatchStats stats) {
    final ranking = StatsEngine.attackRanking(stats);
    if (ranking.isEmpty) {
      return pw.Text('No hay ataques cargados.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700));
    }
    return pdfEfficiencyBars(620, [
      for (final (l, a) in ranking)
        PdfEfficiencyRow('#${l.number} ${l.displayName}', a.efficiency!, '${a.points} pts · ${a.errors} err · ${a.total} tot'),
    ]);
  }

  static const _receptionColors = [pdfPositive, pdfPositiveLight, pdfExcl, pdfWarning, pdfSold, pdfNegative];
  static const _receptionLabels = ['PP', 'P', '!', 'N', 'V-', 'NN'];

  static pw.Widget _pdfReception(MatchStats stats) {
    final players = stats.orderedRows.where((l) => l.recepcion.total > 0).toList();
    if (players.isEmpty) {
      return pw.Text('No hay recepciones cargadas.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700));
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      for (final l in players)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(l.playerId == unassignedId ? l.displayName : '#${l.number} ${l.displayName}',
                  maxLines: 1, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pdfStackedBar(520, 12, [
              for (final (i, v) in [l.recepcion.pp, l.recepcion.p, l.recepcion.excl, l.recepcion.n, l.recepcion.vNeg, l.recepcion.nn].indexed)
                PdfSegment(_receptionLabels[i], v, _receptionColors[i]),
            ], showPercent: true),
            pw.SizedBox(width: 8),
            pw.Text('${(l.recepcion.efficiency! * 100).round()}%',
                style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: pdfPositive)),
            pw.Text('  (${l.recepcion.total})', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ]),
        ),
      pw.SizedBox(height: 3),
      pdfLegend([for (var i = 0; i < 6; i++) (_receptionLabels[i], _receptionColors[i])]),
    ]);
  }

  static pw.Widget _pdfHeatmaps(ZoneStats zones) {
    final nine = zones.hasMiddleZoneData;
    final width = nine ? 170.0 : 200.0;
    pw.Widget one(String title, Map<int, TouchStats> byZone) => pw.Column(children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pdfZoneHeatmap(width, byZone, nineZones: nine),
        ]);
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, children: [
      one('Saque', zones.serveByZone),
      one('Ataque', zones.attackByZone),
      one('Contraataque', zones.counterByZone),
    ]);
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

  static String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

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
        _pct(r.saque.pctServe),
        '${r.ataque.pp}',
        '${r.ataque.p}',
        '${r.ataque.n}',
        '${r.ataque.bloq}',
        '${r.ataque.nn}',
        _pct(r.ataque.pctPoint),
        '${r.contra.pp}',
        '${r.contra.p}',
        '${r.contra.n}',
        '${r.contra.bloq}',
        '${r.contra.nn}',
        _pct(r.contra.pctPoint),
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
        '${r.yellowCards}',
        '${r.redCards}',
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
      _pct(t.saque.pctServe),
      '${t.ataque.pp}',
      '${t.ataque.p}',
      '${t.ataque.n}',
      '${t.ataque.bloq}',
      '${t.ataque.nn}',
      _pct(t.ataque.pctPoint),
      '${t.contra.pp}',
      '${t.contra.p}',
      '${t.contra.n}',
      '${t.contra.bloq}',
      '${t.contra.nn}',
      _pct(t.contra.pctPoint),
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
      '${t.yellowCards}',
      '${t.redCards}',
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
          'Bl Bloqueado · NN Error (Doble Negativa). % Saque = (PP+P)/Total · % Ataque y % Contra = '
          'PP/Total.  Recepción: PP Perfecta (Doble Positiva) · P Positiva · '
          '! Exclamativa · N Negativa · V/ Vendida · NN Error (Doble Negativa). % Recepción = (PP+P)/Total. '
          'Pts puntos · Err errores totales · Blq Pts puntos de bloqueo · '
          'Err Gen errores generales · Tot toques totales · Am tarjetas amarillas · '
          'Ro tarjetas rojas.  $_positionLegend',
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
    _StatCol('%', 10, group: 'Saque'),
    _StatCol('PP', 9, group: 'Ataque'),
    _StatCol('P', 9, group: 'Ataque'),
    _StatCol('N', 9, group: 'Ataque'),
    _StatCol('Bl', 9, group: 'Ataque'),
    _StatCol('NN', 9, group: 'Ataque'),
    _StatCol('%', 10, group: 'Ataque'),
    _StatCol('PP', 9, group: 'Contraataque'),
    _StatCol('P', 9, group: 'Contraataque'),
    _StatCol('N', 9, group: 'Contraataque'),
    _StatCol('Bl', 9, group: 'Contraataque'),
    _StatCol('NN', 9, group: 'Contraataque'),
    _StatCol('%', 10, group: 'Contraataque'),
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
    _StatCol('Am', 8),
    _StatCol('Ro', 8),
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
    List<int> zones,
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
        for (final z in zones) '${zoneMap[z]!.total}',
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
          headers: ['N°', 'Jugador', for (final z in zones) 'Z$z', 'Total', '% Efec'],
          data: rows,
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(4.6),
            for (var i = 0; i < zones.length; i++) 2 + i: const pw.FlexColumnWidth(1),
            2 + zones.length: const pw.FlexColumnWidth(1.2),
            3 + zones.length: const pw.FlexColumnWidth(1.4),
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
          'Referencias: Z1-Z${zones.last} zona de destino de cada toque (numeración estándar) · '
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

  /// Lista cronológica de todas las sanciones/tarjetas del partido (los dos
  /// equipos, todos los sets).
  static pw.Widget _sanctionsTable(VolleyMatch match) {
    final rows = <List<String>>[];
    for (final set in match.sets) {
      for (final s in set.sanctions) {
        rows.add([
          '${s.setNumber}',
          s.team == TeamSide.own ? match.ownTeamName : match.rivalTeamName,
          _sanctionTargetLabel(match, s),
          s.category.label,
          s.outcome.title(s.category),
          s.outcome.cardsLabel,
        ]);
      }
    }
    if (rows.isEmpty) return pw.SizedBox();

    return pw.TableHelper.fromTextArray(
      headers: const ['Set', 'Equipo', 'Jugador / Banco', 'Categoría', 'Sanción', 'Tarjetas'],
      data: rows,
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FlexColumnWidth(2.6),
      },
      headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.center,
      cellAlignments: const {1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft},
    );
  }

  static String _sanctionTargetLabel(VolleyMatch match, SanctionEvent s) {
    if (s.targetKind == SanctionTargetKind.staff) {
      return 'Banco / Cuerpo técnico';
    }
    if (s.team == TeamSide.own) {
      final p = match.ownRoster.firstWhere(
        (pl) => pl.id == s.targetPlayerId,
        orElse: () =>
            Player(id: '', firstName: '', lastName: '?', number: 0, position: PlayerPosition.puntaReceptor),
      );
      return '#${p.number} ${p.fullName}';
    }
    return 'Jugador rival #${s.rivalNumber ?? '?'}';
  }

  static pw.Widget _zoneTable(String title, Map<int, TouchStats> byZone, List<int> zones) {
    final includeBloq = byZone.values.any((s) => s.bloq > 0);
    final headers = ['Zona', 'Total', 'PP', 'P', 'N', if (includeBloq) 'BLOQ', 'NN'];

    final rows = [
      for (final zone in zones)
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
