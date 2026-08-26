import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/play.dart';
import '../../state/app_data_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/id_gen.dart';
import '../../widgets/premium_required_screen.dart';
import 'plays_archive_screen.dart';
import 'widgets/whiteboard_painter.dart';

/// Colores disponibles para dibujar (equipo propio, rival, genérico, etc.).
const _kPalette = [
  Color(0xFF1565C0), // azul
  Color(0xFFC62828), // rojo
  Color(0xFF2E7D32), // verde
  Color(0xFFF9A825), // amarillo
  Color(0xFF000000), // negro
];

/// Pizarra táctica: cancha dibujable a mano para armar formaciones y
/// jugadas (saque, ataque, rotaciones), con guardado en un archivo propio
/// (similar al archivo de partidos). Se puede abrir tanto desde la carga en
/// vivo (punto a punto) como desde la pantalla previa al set.
class WhiteboardScreen extends StatefulWidget {
  final Play? initialPlay;
  const WhiteboardScreen({super.key, this.initialPlay});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  late String _playId;
  late String _name;
  final List<PlayStroke> _strokes = [];
  Color _color = _kPalette.first;
  bool _arrowMode = true;

  List<Offset>? _liveRawPoints;
  Size? _lastCanvasSize;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialPlay;
    _playId = existing?.id ?? generateId('play_');
    _name = existing?.name ?? 'Jugada ${_defaultSuffix()}';
    if (existing != null) _strokes.addAll(existing.strokes);
  }

  String _defaultSuffix() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _lastCanvasSize = size;
    setState(() {
      _liveRawPoints = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_liveRawPoints == null) return;
    setState(() => _liveRawPoints!.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    final points = _liveRawPoints;
    final size = _lastCanvasSize;
    if (points == null || size == null || points.length < 2 || size.width == 0 || size.height == 0) {
      setState(() => _liveRawPoints = null);
      return;
    }
    setState(() {
      _strokes.add(PlayStroke(
        colorValue: _color.toARGB32(),
        arrow: _arrowMode,
        pointsX: points.map((p) => p.dx / size.width).toList(),
        pointsY: points.map((p) => p.dy / size.height).toList(),
      ));
      _liveRawPoints = null;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
  }

  Future<void> _save() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar jugada'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    _name = name.trim();
    final play = Play(id: _playId, name: _name, date: DateTime.now(), strokes: List.of(_strokes));
    await context.read<AppDataController>().savePlay(play);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Jugada "$_name" guardada')),
    );
  }

  Future<void> _openArchive() async {
    final selected = await Navigator.push<Play>(
      context,
      MaterialPageRoute(builder: (_) => const PlaysArchiveScreen(pickMode: true)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _playId = selected.id;
      _name = selected.name;
      _strokes
        ..clear()
        ..addAll(selected.strokes);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SubscriptionController>().isPremium) {
      return const PremiumRequiredScreen(feature: 'Pizarra');
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pizarra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Abrir jugada guardada',
            onPressed: _openArchive,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Deshacer último trazo',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar todo',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar jugada',
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final c in _kPalette)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: CircleAvatar(
                        radius: _color == c ? 15 : 12,
                        backgroundColor: c,
                        child: _color == c
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                const Spacer(),
                FilterChip(
                  label: const Text('Flecha'),
                  avatar: const Icon(Icons.arrow_right_alt, size: 18),
                  selected: _arrowMode,
                  onSelected: (v) => setState(() => _arrowMode = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onPanStart: (d) => _onPanStart(d, size),
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomPaint(
                        size: size,
                        painter: WhiteboardPainter(
                          strokes: _strokes,
                          livePoints: _liveRawPoints,
                          liveColor: _color,
                          liveArrow: _arrowMode,
                          courtColor: scheme.surfaceContainerHighest,
                          lineColor: scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
