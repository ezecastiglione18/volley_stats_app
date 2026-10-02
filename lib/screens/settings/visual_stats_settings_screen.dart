import 'package:flutter/material.dart';

import '../../models/visual_stats.dart';
import '../../services/storage_service.dart';

/// Dónde se aplica la selección: la pantalla de Estadísticas (pestañas
/// "Mapas" y "Gráficos") o el PDF del partido.
enum VisualStatsTarget { screen, pdf }

extension VisualStatsTargetInfo on VisualStatsTarget {
  String get title => this == VisualStatsTarget.screen ? 'Estadística visual en pantalla' : 'Estadística visual del PDF';

  String get intro => this == VisualStatsTarget.screen
      ? 'Elegí qué mapas y gráficos se ven en las pestañas "Mapas" y "Gráficos" de Estadísticas. La tabla '
          'de estadística se ve siempre.'
      : 'Elegí qué mapas y gráficos se agregan al final del PDF cuando compartís un partido. La tabla de '
          'estadística, los datos del rival y las tablas de zonas se incluyen siempre.';
}

/// Elige qué estadística visual se muestra (función premium: se llega acá
/// solo con premium, ver `AccountSettingsScreen`). Cada cambio se guarda en
/// el acto.
class VisualStatsSettingsScreen extends StatefulWidget {
  const VisualStatsSettingsScreen({super.key, required this.target});

  final VisualStatsTarget target;

  @override
  State<VisualStatsSettingsScreen> createState() => _VisualStatsSettingsScreenState();
}

class _VisualStatsSettingsScreenState extends State<VisualStatsSettingsScreen> {
  late Set<ShotKind> _maps;
  late Set<VisualChart> _charts;

  bool get _isScreen => widget.target == VisualStatsTarget.screen;
  int get _total => ShotKind.values.length + VisualChart.values.length;
  int get _selectedCount => _maps.length + _charts.length;

  @override
  void initState() {
    super.initState();
    final s = StorageService.instance;
    _maps = _isScreen ? s.loadScreenCourtMaps() : s.loadPdfCourtMaps();
    _charts = _isScreen ? s.loadScreenVisualCharts() : s.loadPdfVisualCharts();
  }

  Future<void> _setMaps(Set<ShotKind> v) async {
    setState(() => _maps = v);
    final s = StorageService.instance;
    await (_isScreen ? s.saveScreenCourtMaps(v) : s.savePdfCourtMaps(v));
  }

  Future<void> _setCharts(Set<VisualChart> v) async {
    setState(() => _charts = v);
    final s = StorageService.instance;
    await (_isScreen ? s.saveScreenVisualCharts(v) : s.savePdfVisualCharts(v));
  }

  Future<void> _setAll(bool on) async {
    await _setMaps(on ? ShotKind.values.toSet() : <ShotKind>{});
    await _setCharts(on ? VisualChart.values.toSet() : <VisualChart>{});
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget heading(String text, String sub) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sub, style: TextStyle(fontSize: 12, color: muted)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(widget.target.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.target.intro, style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('$_selectedCount de $_total seleccionados', style: TextStyle(fontSize: 13, color: muted)),
                ),
                TextButton(onPressed: _selectedCount == _total ? null : () => _setAll(true), child: const Text('Todos')),
                TextButton(onPressed: _selectedCount == 0 ? null : () => _setAll(false), child: const Text('Ninguno')),
              ],
            ),
            heading(
              'Mapas de dirección',
              _isScreen
                  ? 'Una flecha por toque, desde dónde salió hasta dónde cayó.'
                  : 'Planilla con una cancha por jugador y fundamento.',
            ),
            Card(
              child: Column(children: [
                for (final k in ShotKind.values) ...[
                  SwitchListTile(
                    title: Text(k.label),
                    subtitle: Text(k.description, style: const TextStyle(fontSize: 12)),
                    value: _maps.contains(k),
                    onChanged: (on) => _setMaps(on ? {..._maps, k} : _maps.difference({k})),
                  ),
                  if (k != ShotKind.values.last) const Divider(height: 1),
                ],
              ]),
            ),
            heading('Gráficos', 'Estadística del equipo.'),
            Card(
              child: Column(children: [
                for (final c in VisualChart.values) ...[
                  SwitchListTile(
                    title: Text(c.label),
                    subtitle: Text(c.description, style: const TextStyle(fontSize: 12)),
                    value: _charts.contains(c),
                    onChanged: (on) => _setCharts(on ? {..._charts, c} : _charts.difference({c})),
                  ),
                  if (c != VisualChart.values.last) const Divider(height: 1),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
