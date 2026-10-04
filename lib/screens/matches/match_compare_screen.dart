import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/volley_match.dart';
import '../../services/match_compare.dart';
import '../../services/stats_engine.dart';
import '../../state/app_data_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'widgets/stats_table.dart';

/// Pone dos partidos terminados lado a lado (partido completo): vista de
/// equipo con la diferencia B − A coloreada según mejore o empeore, y vista
/// por jugador con la misma tabla del resumen, una fila por partido.
class MatchCompareScreen extends StatefulWidget {
  final VolleyMatch initialA;
  const MatchCompareScreen({super.key, required this.initialA});

  @override
  State<MatchCompareScreen> createState() => _MatchCompareScreenState();
}

class _MatchCompareScreenState extends State<MatchCompareScreen> {
  late String _aId = widget.initialA.id;
  String? _bId;
  bool _byPlayer = false;
  String? _playerId;

  static final _short = DateFormat('dd/MM');
  static final _long = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final finished =
        context.watch<AppDataController>().matches.where((m) => m.status == MatchStatus.finished).toList();
    final a = finished.firstWhere((m) => m.id == _aId, orElse: () => widget.initialA);
    final candidatesB = finished.where((m) => m.id != a.id).toList();
    final b = candidatesB.where((m) => m.id == _bId).firstOrNull ?? candidatesB.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar partidos'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MatchPicker(
                    label: 'A',
                    value: a,
                    options: [a, ...candidatesB],
                    onChanged: (m) => setState(() {
                      _aId = m.id;
                      if (_bId == m.id) _bId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: b == null
                      ? const Text('No hay otro partido terminado para comparar.')
                      : _MatchPicker(
                          label: 'B',
                          value: b,
                          options: candidatesB,
                          onChanged: (m) => setState(() => _bId = m.id),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Equipo'), icon: Icon(Icons.groups_outlined)),
                  ButtonSegment(value: true, label: Text('Jugador'), icon: Icon(Icons.person_outline)),
                ],
                selected: {_byPlayer},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _byPlayer = s.first),
              ),
            ),
            const SizedBox(height: 12),
            if (b != null) _byPlayer ? _playerView(a, b) : _TeamCompareTable(rows: MatchCompare.compareMatches(a, b)),
          ],
        ),
      ),
    );
  }

  Widget _playerView(VolleyMatch a, VolleyMatch b) {
    final players = MatchCompare.sharedPlayers(a, b);
    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Estos partidos no comparten jugadores (planteles cargados a mano)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    final player = players.firstWhere((p) => p.id == _playerId, orElse: () => players.first);
    final rowA = StatsEngine.compute(a).byPlayer[player.id]!;
    final rowB = StatsEngine.compute(b).byPlayer[player.id]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<String>(
          value: player.id,
          isExpanded: true,
          items: [
            for (final p in players)
              DropdownMenuItem(value: p.id, child: Text('#${p.number} ${p.fullName}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (id) => setState(() => _playerId = id),
        ),
        const SizedBox(height: 8),
        StatsTable(
          rows: [rowA, rowB],
          rowLabels: ['A · ${_short.format(a.date)}', 'B · ${_short.format(b.date)}'],
        ),
      ],
    );
  }
}

class _MatchPicker extends StatelessWidget {
  final String label;
  final VolleyMatch value;
  final List<VolleyMatch> options;
  final ValueChanged<VolleyMatch> onChanged;
  const _MatchPicker({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String text(VolleyMatch m) =>
        'vs ${m.rivalTeamName} · ${_MatchCompareScreenState._long.format(m.date)} (${m.ownSetsWon}-${m.rivalSetsWon})';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Partido $label',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.id,
          isExpanded: true,
          items: [
            for (final m in options)
              DropdownMenuItem(
                value: m.id,
                child: Text(text(m), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: (id) => onChanged(options.firstWhere((m) => m.id == id)),
        ),
      ),
    );
  }
}

class _TeamCompareTable extends StatelessWidget {
  final List<CompareRow> rows;
  const _TeamCompareTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String text, {bool bold = false, Color? color, TextAlign align = TextAlign.center}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Text(text,
              textAlign: align,
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : null, color: color)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: FixedColumnWidth(58),
            2: FixedColumnWidth(58),
            3: FixedColumnWidth(52),
          },
          border: TableBorder(horizontalInside: BorderSide(color: scheme.outline, width: 0.6)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: surfaceAltColor(context)),
              children: [
                cell('Métrica', bold: true, align: TextAlign.left),
                cell('A', bold: true),
                cell('B', bold: true),
                cell('Δ', bold: true),
              ],
            ),
            for (final r in rows)
              TableRow(children: [
                cell(r.metric, align: TextAlign.left),
                cell(r.a),
                cell(r.b),
                cell(
                  r.deltaLabel,
                  bold: true,
                  color: r.improved == null ? null : (r.improved! ? successColor(context) : errorColor(context)),
                ),
              ]),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Δ = B − A (en los porcentajes, en puntos porcentuales). Verde = mejora; en los errores propios, '
          'mejorar es que bajen. Partido completo. Puntos totales = saque + ataque + contra + bloqueo. '
          'Eficacia de ataque = PP/Total del ataque; de recepción = (PP+P)/Total.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
