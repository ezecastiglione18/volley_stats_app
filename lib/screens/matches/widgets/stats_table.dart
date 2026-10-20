import 'package:flutter/material.dart';

import '../../../models/stat_line.dart';
import '../../../services/stats_engine.dart';
import '../../../utils/theme.dart';

/// Tabla de estadística por jugador (las 33 columnas de [statsTableHeaders]).
/// La usan el resumen del partido (con la fila [total] de equipo) y el
/// comparador de partidos (una fila por partido, con [rowLabels]).
class StatsTable extends StatelessWidget {
  final List<PlayerStatLine> rows;

  /// Si viene, reemplaza el texto de la columna "Jugador" de cada fila de
  /// [rows] (mismo largo que [rows]).
  final List<String>? rowLabels;

  /// Fila "TOTAL EQUIPO" al final, resaltada. Null = sin fila de total.
  final PlayerStatLine? total;

  /// Partidos jugados por cada jugador (clave = playerId). Si viene, se agrega
  /// la columna "PJ" justo después de "Jugador" (la usa el panel de
  /// temporada, donde las filas suman varios partidos).
  final Map<String, int>? matchesPlayed;

  const StatsTable({
    super.key,
    required this.rows,
    this.rowLabels,
    this.total,
    this.matchesPlayed,
  }) : assert(rowLabels == null || rowLabels.length == rows.length);

  static String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  static List<Widget> _valueCells(PlayerStatLine r) => [
        for (final v in statLineValues(r)) _C(v is int ? '$v' : _pct(v as double?)),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final showPj = matchesPlayed != null;

    // "N°" y "Jugador" van primero; "PJ" (si corresponde) justo después.
    TableRow header() => TableRow(
          decoration: BoxDecoration(color: surfaceAltColor(context)),
          children: [
            for (var i = 0; i < statsTableHeaders.length; i++) ...[
              _H(statsTableHeaders[i]),
              if (showPj && i == 1) const _H('PJ'),
            ],
          ],
        );

    TableRow row(PlayerStatLine r, String label) => TableRow(children: [
          _C(r.playerId == unassignedId ? '-' : '${r.number}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          if (showPj) _C('${matchesPlayed![r.playerId] ?? 0}'),
          ..._valueCells(r),
        ]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(56),
        columnWidths: const {1: FixedColumnWidth(140)},
        border: TableBorder.all(color: scheme.outline),
        children: [
          header(),
          for (var i = 0; i < rows.length; i++) row(rows[i], rowLabels?[i] ?? rows[i].displayName),
          if (total != null)
            TableRow(
              decoration: BoxDecoration(color: scheme.secondary.withValues(alpha: 0.16)),
              children: [
                const _C(''),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('TOTAL EQUIPO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (showPj) const _C(''),
                ..._valueCells(total!),
              ],
            ),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(text,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
}

class _C extends StatelessWidget {
  final String text;
  const _C(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      );
}
