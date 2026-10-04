import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/stat_line.dart';
import '../models/volley_match.dart';
import 'stats_engine.dart';

/// Exporta la tabla de estadística del resumen (mismas filas y columnas que
/// `StatsTable`) como CSV para abrir en Excel o Google Sheets. Mismo esquema
/// que [MatchExportService]: hoja de compartir nativa en Android/iOS y
/// "Guardar como" en desktop.
///
/// Formato pensado para Excel en español: separador `;`, BOM UTF-8 (sin él
/// Excel rompe los acentos), fin de línea `\r\n` y porcentajes como enteros
/// sin "%" (para no depender de la coma o el punto decimal).
class CsvExportService {
  static Future<void> exportMatchStats(VolleyMatch match, {int? setNumber}) async {
    final csv = buildCsv(StatsEngine.compute(match, setNumber: setNumber));
    final name = fileName(match, setNumber: setNumber);

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: 'Estadísticas: ${match.ownTeamName} vs ${match.rivalTeamName}'
              '${setNumber == null ? '' : ' (set $setNumber)'}',
        ),
      );
      return;
    }

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Guardar estadísticas',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    // En Windows/Linux, saveFile ya escribe el archivo con los bytes
    // provistos. En macOS solo devuelve la ruta elegida, hay que escribirlo.
    if (savedUri != null && savedUri.scheme == 'file') {
      final savedFile = File(savedUri.toFilePath());
      if (!await savedFile.exists()) {
        await savedFile.writeAsString(csv);
      }
    }
  }

  /// Texto completo del CSV: encabezados de [statsTableHeaders], una fila
  /// por cada fila de [MatchStats.orderedRows] y la de "TOTAL EQUIPO".
  static String buildCsv(MatchStats stats) {
    final lines = <List<String>>[
      statsTableHeaders,
      for (final r in stats.orderedRows)
        [r.playerId == unassignedId ? '' : '${r.number}', r.displayName, ..._values(r)],
      ['', 'TOTAL EQUIPO', ..._values(stats.team)],
    ];
    return '﻿${lines.map((l) => l.map(_escape).join(';')).join('\r\n')}\r\n';
  }

  /// Conteos tal cual; porcentajes como entero sin "%" y vacíos si no hubo
  /// toques (en la tabla de la app se ven como "-").
  static List<String> _values(PlayerStatLine r) => [
        for (final v in statLineValues(r))
          if (v is int) '$v' else if (v == null) '' else ((v as double) * 100).toStringAsFixed(0),
      ];

  static String _escape(String field) {
    if (!field.contains(RegExp('[;"\r\n]'))) return field;
    return '"${field.replaceAll('"', '""')}"';
  }

  /// estadisticas_yyyyMMdd_[rival](_setN).csv, con el mismo saneo del rival
  /// que el resto de las exportaciones.
  @visibleForTesting
  static String fileName(VolleyMatch match, {int? setNumber}) {
    final d = DateFormat('yyyyMMdd').format(match.date);
    final rival = match.rivalTeamName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'estadisticas_${d}_$rival${setNumber == null ? '' : '_set$setNumber'}.csv';
  }
}
