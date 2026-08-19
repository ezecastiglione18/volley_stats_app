import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/rally_event.dart';
import '../models/stat_line.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

class PdfReportService {
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
    final dateStr = DateFormat('dd/MM/yyyy').format(match.date);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => _header(match, dateStr),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _setScoreTable(match),
          pw.SizedBox(height: 16),
          pw.Text('Estadística del partido — ${match.ownTeamName}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _statsTable(stats),
          pw.SizedBox(height: 16),
          if (match.sets.length > 1) ...[
            pw.Text('Detalle por set', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final set in match.sets) ...[
              pw.Text('Set ${set.setNumber} (${set.ownScore}-${set.rivalScore})',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _statsTable(StatsEngine.compute(match, setNumber: set.setNumber), compact: true),
              pw.SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(VolleyMatch match, String dateStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Estadísticas de Vóley', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${match.ownTeamName}  vs  ${match.rivalTeamName}',
            style: pw.TextStyle(fontSize: 14)),
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
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
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
    final headers = [
      'N°',
      'Jugador',
      'Pts',
      'Err',
      'Saq PP',
      'Saq P',
      'Saq N',
      'Saq NN',
      'Atq PP',
      'Atq P',
      'Atq N',
      'Atq Bl',
      'Atq NN',
      'Ctr PP',
      'Ctr P',
      'Ctr N',
      'Ctr Bl',
      'Ctr NN',
      'Blq Pts',
      'Err Gen',
      'Rec Tot',
      'Rec PP',
      'Rec P',
      'Rec !',
      'Rec N',
      'Rec V-',
      'Rec NN',
      'Rec %',
    ];

    final rows = stats.orderedRows.map((r) {
      final effPct = r.recepcion.efficiency;
      return [
        r.playerId == unassignedId ? '-' : '${r.number}',
        r.displayName,
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

    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: compact ? 7 : 8),
      cellStyle: pw.TextStyle(fontSize: compact ? 7 : 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellAlignments: const {1: pw.Alignment.centerLeft},
    );
  }
}
