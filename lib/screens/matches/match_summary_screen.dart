import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/rally_event.dart';
import '../../models/volley_match.dart';
import '../../services/csv_export_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/stats_engine.dart';
import '../../state/app_data_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/premium_required_screen.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../../services/visual_stats_preferences.dart';
import 'widgets/court_maps_tab.dart';
import 'widgets/stats_table.dart';
import 'widgets/visual_stats_tab.dart';

class MatchSummaryScreen extends StatefulWidget {
  final VolleyMatch match;
  final bool justFinished;
  final int? initialSet;
  const MatchSummaryScreen({
    super.key,
    required this.match,
    this.justFinished = false,
    this.initialSet,
  });

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  int? _selectedSet; // null = partido completo
  bool _loadingPdf = false;
  bool _loadingCsv = false;

  @override
  void initState() {
    super.initState();
    _selectedSet = widget.initialSet;
  }

  Future<void> _sharePdf() async {
    final isPremium = context.read<SubscriptionController>().isPremium;
    final charts = VisualStatsPreferences.pdfCharts(isPremium: isPremium);
    final maps = VisualStatsPreferences.pdfMaps(isPremium: isPremium);
    setState(() => _loadingPdf = true);
    try {
      await PdfReportService.shareMatchReport(widget.match, charts: charts, maps: maps);
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _loadingCsv = true);
    try {
      await CsvExportService.exportMatchStats(widget.match, setNumber: _selectedSet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingCsv = false);
    }
  }

  /// Notas de scouting: función gratuita (sin runIfPremium). Texto vacío o
  /// solo espacios se guarda como null.
  Future<void> _editNotes() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NotesDialog(initial: widget.match.notes ?? ''),
    );
    if (result == null || !mounted) return; // cancelado
    final trimmed = result.trim();
    final newNotes = trimmed.isEmpty ? null : trimmed;
    if (newNotes == widget.match.notes) return;
    final previous = widget.match.notes;
    final isPremium = context.read<SubscriptionController>().isPremium;
    setState(() => widget.match.notes = newNotes);
    try {
      await context.read<AppDataController>().saveMatch(widget.match, isPremium: isPremium);
    } catch (e) {
      if (!mounted) return;
      setState(() => widget.match.notes = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudieron guardar las notas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionController>().isPremium;
    final appData = context.watch<AppDataController>();
    final matchId = widget.match.id;

    if (!isPremium && appData.freeStatsMatchId != matchId) {
      if (appData.freeStatsMatchId != null) {
        // El cupo ya lo gastó otro partido: bloqueado hasta premium.
        return const PremiumRequiredScreen(
          feature: 'Estadísticas',
          message: 'Ya generaste la estadística gratuita de otro partido. Suscribite a premium '
              'para generar estadísticas en todos los partidos.',
        );
      }
      // Cupo libre: el usuario elige si lo gasta en este partido.
      return _FreeStatsConfirmScreen(
        matchLabel: '${widget.match.ownTeamName} vs ${widget.match.rivalTeamName}',
        onConfirm: () => appData.registerFreeStatsUsage(matchId),
      );
    }

    final match = widget.match;
    final df = DateFormat('dd/MM/yyyy');
    final stats = StatsEngine.compute(match, setNumber: _selectedSet);
    // Mismo selector (y mismo set elegido) en las dos pestañas.
    final setSelector = Row(
      children: [
        const Text('Estadística: ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Flexible(
          child: DropdownButton<int?>(
            value: _selectedSet,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Partido completo', overflow: TextOverflow.ellipsis)),
              for (final s in match.sets) DropdownMenuItem(value: s.setNumber, child: Text('Set ${s.setNumber}')),
            ],
            onChanged: (v) => setState(() => _selectedSet = v),
          ),
        ),
      ],
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: Text('${match.ownTeamName} vs ${match.rivalTeamName}'),
        actions: [
          const ThemeToggleSwitch(),
          IconButton(
            icon: _loadingCsv
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_chart_outlined),
            tooltip: 'Exportar a Excel (CSV)',
            // Premium por su cuenta: la pantalla también la ve un free en su
            // partido de estadística gratuita (freeStatsMatchId).
            onPressed: _loadingCsv ? null : () => runIfPremium(context, _exportCsv),
          ),
          IconButton(
            icon: _loadingPdf
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Compartir PDF',
            onPressed: _loadingPdf ? null : _sharePdf,
          ),
        ],
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          tabs: const [Tab(text: 'Tabla'), Tab(text: 'Mapas'), Tab(text: 'Gráficos')],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          children: [
            ListView(
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
          setSelector,
          const SizedBox(height: 8),
          StatsTable(rows: stats.orderedRows, total: stats.team),
          const SizedBox(height: 6),
          Text(
            'Referencias — Saque/Ataque/Contra: PP Punto (Doble Positiva) · P Positiva (en Ataque/Contra incluye R Rejuego) · '
            'N Negativa · '
            'Bl Bloqueado (solo Ataque/Contra) · NN Error (Doble Negativa). % Saque = (PP+P)/Total · '
            '% Ataque y % Contra = PP/Total. Recepción: PP Perfecta · P Positiva · ! Exclamativa · '
            'N Negativa · V/ Vendida · NN Error · % Rec = (PP+P)/Total. Pts puntos · Err errores '
            'totales · Blq puntos de bloqueo · E.Gen errores genéricos · Am amarillas · Ro rojas.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _NotesCard(notes: match.notes, onEdit: _editNotes),
          const SizedBox(height: 10),
          _RivalStatsCard(stats: stats),
          const SizedBox(height: 20),
        ],
        ),
              CourtMapsTab(
                match: match,
                setNumber: _selectedSet,
                setSelector: setSelector,
                visibleKinds: VisualStatsPreferences.screenMaps(isPremium: isPremium),
              ),
              VisualStatsTab(
                match: match,
                setNumber: _selectedSet,
                setSelector: setSelector,
                visibleCharts: VisualStatsPreferences.screenCharts(isPremium: isPremium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String? notes;
  final VoidCallback onEdit;
  const _NotesCard({required this.notes, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Notas de scouting', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar notas',
                  onPressed: onEdit,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: notes == null
                  ? Text('Sin notas · tocá ✎ para agregar', style: TextStyle(color: muted))
                  : Text(notes!),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de edición de las notas. Devuelve el texto escrito al guardar,
/// o null si se canceló.
class _NotesDialog extends StatefulWidget {
  final String initial;
  const _NotesDialog({required this.initial});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notas del partido'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          maxLength: 1000,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej.: saque flotado corto a zona 1, reforzar bloqueo en 4…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Guardar')),
      ],
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

/// Paso de confirmación antes de gastar el único cupo de estadística free en
/// un partido puntual. Se muestra en vez de la estadística mientras el cupo
/// siga libre, para que la elección de qué partido lo usa sea explícita del
/// usuario y no el resultado de haber entrado a mirar por curiosidad.
class _FreeStatsConfirmScreen extends StatefulWidget {
  final String matchLabel;
  final Future<void> Function() onConfirm;
  const _FreeStatsConfirmScreen({required this.matchLabel, required this.onConfirm});

  @override
  State<_FreeStatsConfirmScreen> createState() => _FreeStatsConfirmScreenState();
}

class _FreeStatsConfirmScreenState extends State<_FreeStatsConfirmScreen> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    await widget.onConfirm();
    if (mounted) setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.query_stats, size: 48, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 16),
                const Text(
                  'La versión free permite generar estadística en un único partido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vas a usar ese cupo en "${widget.matchLabel}". No vas a poder generar '
                  'estadística para ningún otro partido hasta que te suscribas a premium.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _confirming ? null : _confirm,
                  child: _confirming
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Usar acá mi estadística gratis'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _confirming ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
