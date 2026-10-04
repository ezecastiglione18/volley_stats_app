// Exportar estadísticas a CSV (documents/RallyStats-Funcionalidades-
// Pendientes.pdf, sección 2): formato para Excel en español y mismas
// columnas que la tabla del resumen.

import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/stat_line.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/services/csv_export_service.dart';
import 'package:rally_stats/services/stats_engine.dart';

MatchStats _stats() {
  final a = PlayerStatLine(playerId: 'A', displayName: 'Martina Gómez', number: 4);
  a.saque
    ..pp = 2
    ..p = 1
    ..n = 0
    ..nn = 1; // (2+1)/4 = 75 %
  a.ataque
    ..pp = 1
    ..nn = 2; // 1/3 = 33 %
  a.recepcion
    ..pp = 1
    ..p = 1
    ..n = 1; // 2/3 = 67 %
  // Nombre con separador y comillas: tiene que ir entre comillas.
  final b = PlayerStatLine(playerId: 'B', displayName: 'Lu "La Flaca"; Pérez', number: 10);
  final unassigned = PlayerStatLine(playerId: unassignedId, displayName: 'No Asignado', number: 9999)..errGen = 1;
  final team = PlayerStatLine(playerId: 'team', displayName: 'Total Equipo', number: -1);
  team.saque
    ..pp = 2
    ..p = 1
    ..nn = 1;
  team.errGen = 1;
  return MatchStats(
    byPlayer: {'B': b, 'A': a, unassignedId: unassigned},
    team: team,
    rivalErrors: RivalErrorStats(),
    rivalPoints: RivalPointStats(),
    rivalSanctions: RivalSanctionStats(),
  );
}

/// Separa el CSV en celdas respetando las comillas.
List<List<String>> _parse(String csv) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < csv.length; i++) {
    final ch = csv[i];
    if (quoted) {
      if (ch == '"' && i + 1 < csv.length && csv[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ';') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\r' && csv[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      cell.write(ch);
    }
  }
  return rows;
}

void main() {
  group('CSV de estadísticas', () {
    final csv = CsvExportService.buildCsv(_stats());
    final rows = _parse(csv.substring(1));

    test('empieza con BOM UTF-8 y usa \\r\\n', () {
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(csv.endsWith('\r\n'), isTrue);
      expect(csv.replaceAll('\r\n', '').contains('\n'), isFalse);
    });

    test('encabezados: las 33 columnas de la tabla, separadas por ";"', () {
      expect(statsTableHeaders, hasLength(33));
      expect(csv.substring(1).split('\r\n').first, statsTableHeaders.join(';'));
      for (final r in rows) {
        expect(r, hasLength(33), reason: r.join('|'));
      }
    });

    test('mismas filas que la tabla: jugadores por número, No Asignado y total', () {
      expect([for (final r in rows.skip(1)) r[1]],
          ['Martina Gómez', 'Lu "La Flaca"; Pérez', 'No Asignado', 'TOTAL EQUIPO']);
      expect(rows[1][0], '4');
      expect(rows[3][0], '', reason: 'No Asignado sin número');
      expect(rows[4][0], '');
    });

    test('escapa los campos con ";" o comillas duplicando las internas', () {
      expect(csv, contains(';"Lu ""La Flaca""; Pérez";'));
      expect(csv, contains(';Martina Gómez;'), reason: 'sin comillas si no hace falta');
    });

    test('porcentajes como enteros sin "%" y vacíos si no hubo toques', () {
      const h = statsTableHeaders;
      final martina = rows[1];
      expect(martina[h.indexOf('Saq %')], '75');
      expect(martina[h.indexOf('Atq %')], '33');
      expect(martina[h.indexOf('Rec %')], '67');
      expect(martina[h.indexOf('Ctr %')], '');
      expect(martina[h.indexOf('Saq PP')], '2');
      expect(rows[2][h.indexOf('Saq %')], '');
      for (final r in rows.skip(1)) {
        expect(r.any((c) => c.contains('%') || c == '-'), isFalse, reason: r.join(';'));
      }
      expect(rows[4][h.indexOf('Saq %')], '75');
      expect(rows[4][h.indexOf('E.Gen')], '1');
    });

    test('nombre de archivo con el rival saneado y el set opcional', () {
      final m = VolleyMatch(
        id: 'm',
        date: DateTime(2026, 9, 20),
        ownTeamName: 'Propio',
        ownRoster: [],
        rivalTeamName: 'Los Andes/B',
        config: MatchConfig(),
      );
      expect(CsvExportService.fileName(m), 'estadisticas_20260920_Los_Andes_B.csv');
      expect(CsvExportService.fileName(m, setNumber: 3), 'estadisticas_20260920_Los_Andes_B_set3.csv');
    });
  });
}
