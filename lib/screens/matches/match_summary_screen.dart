import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/rally_event.dart';
import '../../models/stat_line.dart';
import '../../models/volley_match.dart';
import '../../services/pdf_report_service.dart';
import '../../services/stats_engine.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';

class MatchSummaryScreen extends StatefulWidget {
  final VolleyMatch match;
  final bool justFinished;
  const MatchSummaryScreen({super.key, required this.match, this.justFinished = false});

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  int? _selectedSet; // null = partido completo
  bool _loadingPdf = false;

  Future<void> _sharePdf() async {
    setState(() => _loadingPdf = true);
    try {
      await PdfReportService.shareMatchReport(widget.match);
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final df = DateFormat('dd/MM/yyyy');
    final stats = StatsEngine.compute(match, setNumber: _selectedSet);

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.ownTeamName} vs ${match.rivalTeamName}'),
        actions: [
          const ThemeToggleSwitch(),
          IconButton(
            icon: _loadingPdf
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Compartir PDF',
            onPressed: _loadingPdf ? null : _sharePdf,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.justFinished)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: successColor(context).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('¡Partido finalizado! Los datos quedaron guardados en el archivo.',
                      style: TextStyle(color: successColor(context), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Volver al inicio'),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                ],
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fecha: ${df.format(match.date)}'),
                  if (match.tournament.isNotEmpty) Text('Torneo: ${match.tournament}'),
                  if (match.round.isNotEmpty) Text('Instancia: ${match.round}'),
                  if (match.category.isNotEmpty) Text('Categoría: ${match.category}'),
                  if (match.court.isNotEmpty) Text('Cancha: ${match.court}'),
                  const SizedBox(height: 10),
                  Text('Resultado final: ${match.ownSetsWon} - ${match.rivalSetsWon}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sets', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...match.sets.map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Set ${s.setNumber}: ${s.ownScore} - ${s.rivalScore}'
                          '${s.winner != null ? '  (${s.winner == TeamSide.own ? match.ownTeamName : match.rivalTeamName})' : ''}',
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Estadística: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<int?>(
                value: _selectedSet,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Partido completo')),
                  for (final s in match.sets)
                    DropdownMenuItem(value: s.setNumber, child: Text('Set ${s.setNumber}')),
                ],
                onChanged: (v) => setState(() => _selectedSet = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatsTable(stats: stats),
          const SizedBox(height: 14),
          _RivalStatsCard(stats: stats),
          const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }
}

class _RivalStatsCard extends StatelessWidget {
  final MatchStats stats;
  const _RivalStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final err = stats.rivalErrors;
    final pts = stats.rivalPoints;
    final san = stats.rivalSanctions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estadística del rival', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Errores rival — Saque: ${err.serve} · Ataque: ${err.attack} · '
                'Contra: ${err.counter} · Genérico: ${err.generic} · Total: ${err.total}'),
            const SizedBox(height: 4),
            Text('Puntos rival — Ataque: ${pts.attack} · Contra: ${pts.counter}'
                '${pts.unclassified > 0 ? ' · Sin clasificar: ${pts.unclassified}' : ''} · Total: ${pts.total}'),
            if (san.yellowCards > 0 || san.redCards > 0) ...[
              const SizedBox(height: 4),
              Text('Sanciones rival — Amarillas: ${san.yellowCards} · Rojas: ${san.redCards}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final MatchStats stats;
  const _StatsTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = stats.orderedRows;

    TableRow header() => TableRow(
          decoration: BoxDecoration(color: surfaceAltColor(context)),
          children: const [
            _H('N°'),
            _H('Jugador'),
            _H('Pts'),
            _H('Err'),
            _H('Saq PP'),
            _H('Saq P'),
            _H('Saq N'),
            _H('Saq NN'),
            _H('Atq PP'),
            _H('Atq P'),
            _H('Atq N'),
            _H('Atq Bl'),
            _H('Atq NN'),
            _H('Ctr PP'),
            _H('Ctr P'),
            _H('Ctr N'),
            _H('Ctr Bl'),
            _H('Ctr NN'),
            _H('Blq'),
            _H('E.Gen'),
            _H('Rec Tot'),
            _H('Rec PP'),
            _H('Rec P'),
            _H('Rec !'),
            _H('Rec N'),
            _H('Rec V/'),
            _H('Rec NN'),
            _H('Rec %'),
            _H('Am'),
            _H('Ro'),
          ],
        );

    TableRow row(PlayerStatLine r) {
      final eff = r.recepcion.efficiency;
      Widget c(String v) => _C(v);
      return TableRow(children: [
        c(r.playerId == unassignedId ? '-' : '${r.number}'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(r.displayName, style: const TextStyle(fontSize: 12)),
        ),
        c('${r.totalPts}'),
        c('${r.totalErr}'),
        c('${r.saque.pp}'),
        c('${r.saque.p}'),
        c('${r.saque.n}'),
        c('${r.saque.nn}'),
        c('${r.ataque.pp}'),
        c('${r.ataque.p}'),
        c('${r.ataque.n}'),
        c('${r.ataque.bloq}'),
        c('${r.ataque.nn}'),
        c('${r.contra.pp}'),
        c('${r.contra.p}'),
        c('${r.contra.n}'),
        c('${r.contra.bloq}'),
        c('${r.contra.nn}'),
        c('${r.bloqueoPts}'),
        c('${r.errGen}'),
        c('${r.recepcion.total}'),
        c('${r.recepcion.pp}'),
        c('${r.recepcion.p}'),
        c('${r.recepcion.excl}'),
        c('${r.recepcion.n}'),
        c('${r.recepcion.vNeg}'),
        c('${r.recepcion.nn}'),
        c(eff == null ? '-' : '${(eff * 100).toStringAsFixed(0)}%'),
        c('${r.yellowCards}'),
        c('${r.redCards}'),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(56),
        columnWidths: const {1: FixedColumnWidth(140)},
        border: TableBorder.all(color: scheme.outline),
        children: [
          header(),
          for (final r in rows) row(r),
          TableRow(
            decoration: BoxDecoration(color: scheme.secondary.withValues(alpha: 0.16)),
            children: [
              const _C(''),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text('TOTAL EQUIPO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              _C('${stats.team.totalPts}'),
              _C('${stats.team.totalErr}'),
              _C('${stats.team.saque.pp}'),
              _C('${stats.team.saque.p}'),
              _C('${stats.team.saque.n}'),
              _C('${stats.team.saque.nn}'),
              _C('${stats.team.ataque.pp}'),
              _C('${stats.team.ataque.p}'),
              _C('${stats.team.ataque.n}'),
              _C('${stats.team.ataque.bloq}'),
              _C('${stats.team.ataque.nn}'),
              _C('${stats.team.contra.pp}'),
              _C('${stats.team.contra.p}'),
              _C('${stats.team.contra.n}'),
              _C('${stats.team.contra.bloq}'),
              _C('${stats.team.contra.nn}'),
              _C('${stats.team.bloqueoPts}'),
              _C('${stats.team.errGen}'),
              _C('${stats.team.recepcion.total}'),
              _C('${stats.team.recepcion.pp}'),
              _C('${stats.team.recepcion.p}'),
              _C('${stats.team.recepcion.excl}'),
              _C('${stats.team.recepcion.n}'),
              _C('${stats.team.recepcion.vNeg}'),
              _C('${stats.team.recepcion.nn}'),
              _C(stats.team.recepcion.efficiency == null
                  ? '-'
                  : '${(stats.team.recepcion.efficiency! * 100).toStringAsFixed(0)}%'),
              _C('${stats.team.yellowCards}'),
              _C('${stats.team.redCards}'),
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
