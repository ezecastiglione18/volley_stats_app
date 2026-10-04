// Notas de scouting por partido (documents/RallyStats-Funcionalidades-
// Pendientes.pdf, sección 1): el campo opcional `VolleyMatch.notes` y su
// paso por toJson/fromJson, incluidos los partidos guardados antes del campo.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/models/match_config.dart';
import 'package:rally_stats/models/player.dart';
import 'package:rally_stats/models/volley_match.dart';
import 'package:rally_stats/services/pdf_report_service.dart';

VolleyMatch _match({String? notes}) => VolleyMatch(
      id: 'match_notas',
      date: DateTime(2026, 10, 4),
      ownTeamName: 'Propio',
      ownRoster: [
        Player(id: 'A1', firstName: 'Ana', lastName: 'Uno', number: 1, position: PlayerPosition.armador),
      ],
      rivalTeamName: 'Rival',
      config: MatchConfig(),
      status: MatchStatus.finished,
      notes: notes,
    );

/// Mismo camino que un partido guardado: a JSON (texto) y de vuelta.
VolleyMatch _roundTrip(VolleyMatch m) =>
    VolleyMatch.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);

void main() {
  group('Notas de scouting', () {
    test('round-trip con notas conserva el texto (multilínea y acentos)', () {
      const text = 'Saque flotado corto a zona 1.\nEl opuesto ataca diagonal; reforzar bloqueo en 4 — ñandú.';
      final back = _roundTrip(_match(notes: text));
      expect(back.notes, text);
    });

    test('round-trip sin notas da null', () {
      final m = _match();
      expect(m.toJson().containsKey('notes'), isTrue);
      expect(_roundTrip(m).notes, isNull);
    });

    test('un JSON viejo, sin la clave "notes", da null', () {
      final json = _match(notes: 'algo').toJson()..remove('notes');
      final back = VolleyMatch.fromJson(json);
      expect(back.notes, isNull);
      expect(back.id, 'match_notas');
      expect(back.status, MatchStatus.finished);
    });

    test('PDF: las notas se pasan a Latin-1 sin perder lo que se puede dibujar', () async {
      expect(PdfReportService.latin1Safe('“Ojo” con el 4 — saca… ñ → 😀'), '"Ojo" con el 4 - saca... ñ -> ');
      // El reporte se arma con y sin notas sin romper.
      expect(await PdfReportService.buildPdf(_match(notes: 'Nota “con” emoji 😀')), isNotEmpty);
      expect(await PdfReportService.buildPdf(_match()), isNotEmpty);
    });
  });
}
