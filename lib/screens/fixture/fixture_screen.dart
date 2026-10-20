import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/fixture_entry.dart';
import '../../state/app_data_controller.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../matches/match_summary_screen.dart';
import 'fixture_entry_form_screen.dart';

/// Fixture del equipo: la lista, por fecha, de los partidos por jugar y ya
/// jugados. Cada fila muestra fecha, rival y "torneo · instancia", con un chip
/// "Jugado X-Y" si ya se armó el partido a partir de ella o "Próximo" en la
/// primera fila futura sin jugar.
///
/// Con [pickMode] solo lista las filas sin jugar y tocar una la devuelve con
/// `Navigator.pop(context, entry)` (lo usa "Elegir del fixture" en Nuevo
/// Partido), igual que `PlaysArchiveScreen`.
class FixtureScreen extends StatelessWidget {
  final bool pickMode;
  const FixtureScreen({super.key, this.pickMode = false});

  static final _df = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppDataController>();
    final all = appData.fixtureEntries;
    final entries = pickMode ? all.where((e) => appData.linkedMatchOf(e) == null).toList() : all;

    // "Próximo": la primera fila sin jugar desde hoy en adelante.
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final next = all
        .where((e) => appData.linkedMatchOf(e) == null && !e.date.isBefore(startOfToday))
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(pickMode ? 'Elegir del fixture' : 'Fixture'),
        actions: const [ThemeToggleSwitch()],
      ),
      floatingActionButton: pickMode
          ? null
          : FloatingActionButton(
              tooltip: 'Agregar partido',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: entries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    pickMode
                        ? 'No hay partidos sin jugar en el fixture. Cargalos desde "Fixture" en Inicio.'
                        : 'Todavía no cargaste partidos en el fixture.\nTocá el botón + para agregar el primero.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final match = appData.linkedMatchOf(e);
                  return _FixtureRow(
                    entry: e,
                    playedScore: match == null ? null : '${match.ownSetsWon}-${match.rivalSetsWon}',
                    isNext: identical(e, next),
                    onTap: () {
                      if (pickMode) {
                        Navigator.pop(context, e);
                      } else if (match != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MatchSummaryScreen(match: match)),
                        );
                      } else {
                        _openForm(context, e);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  void _openForm(BuildContext context, [FixtureEntry? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FixtureEntryFormScreen(entry: entry)),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  final FixtureEntry entry;

  /// "3-1" si ya se jugó (partido vinculado y todavía en el archivo).
  final String? playedScore;
  final bool isNext;
  final VoidCallback onTap;

  const _FixtureRow({
    required this.entry,
    required this.playedScore,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = [entry.tournament, entry.round].where((s) => s.isNotEmpty).join(' · ');

    Widget? chip;
    if (playedScore != null) {
      chip = _Chip('Jugado $playedScore', successColor(context));
    } else if (isNext) {
      chip = _Chip('Próximo', scheme.secondary);
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.event)),
        title: Text('vs ${entry.rivalTeamName}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [FixtureScreen._df.format(entry.date), if (detail.isNotEmpty) detail].join('\n'),
        ),
        isThreeLine: detail.isNotEmpty,
        trailing: chip,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
