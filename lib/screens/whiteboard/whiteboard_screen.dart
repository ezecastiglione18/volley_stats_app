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

/// Plantilla de un fichín disponible en la bandeja: un puesto de la
/// formación estándar (5-1 + líbero). Los ids son fijos para poder saber,
/// dado un [PlacedToken] guardado, a qué fichín de la bandeja corresponde.
class _TokenTemplate {
  final String id;
  final String label;
  final Color color;
  const _TokenTemplate(this.id, this.label, this.color);
}

/// Un fichín para cada puesto de una formación titular: 1 armador, 2
/// puntas/receptores, 2 centrales, 1 opuesto y 1 líbero. Todos del mismo
/// color (negro), sin relación con el color de trazo elegido para dibujar.
const _kTokenColor = Color(0xFF000000);
const _kTokenCatalog = [
  _TokenTemplate('A1', 'A', _kTokenColor),
  _TokenTemplate('P1', 'P', _kTokenColor),
  _TokenTemplate('P2', 'P', _kTokenColor),
  _TokenTemplate('C1', 'C', _kTokenColor),
  _TokenTemplate('C2', 'C', _kTokenColor),
  _TokenTemplate('O1', 'O', _kTokenColor),
  _TokenTemplate('L1', 'L', _kTokenColor),
];

const double _kTokenSize = 40;

/// Círculo con la letra del puesto, usado tanto en la bandeja de fichines
/// disponibles como ya apoyado sobre la cancha.
class _TokenCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool dragging;
  const _TokenCircle({required this.label, required this.color, this.dragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTokenSize,
      height: _kTokenSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: dragging
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3))]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

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
  final List<PlacedToken> _tokens = [];
  Color _color = _kPalette.first;
  bool _arrowMode = true;

  List<Offset>? _liveRawPoints;
  Size? _lastCanvasSize;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final existing = widget.initialPlay;
    _playId = existing?.id ?? generateId('play_');
    _name = existing?.name ?? 'Jugada ${_defaultSuffix()}';
    if (existing != null) {
      _strokes.addAll(existing.strokes);
      _tokens.addAll(existing.tokens);
    }
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
    if (_strokes.isEmpty && _tokens.isEmpty) return;
    setState(() {
      _strokes.clear();
      _tokens.clear();
    });
  }

  /// Apoya (o reubica) un fichín sobre la cancha a partir de su posición
  /// [globalPosition] (la del puntero al soltarlo), convertida a coordenadas
  /// normalizadas relativas a la cancha.
  void _onTokenDropped(String tokenId, Offset globalPosition) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    if (size.width == 0 || size.height == 0) return;
    final local = box.globalToLocal(globalPosition);
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      final idx = _tokens.indexWhere((t) => t.tokenId == tokenId);
      if (idx != -1) {
        _tokens[idx] = _tokens[idx].copyWith(x: nx, y: ny);
      } else {
        final template = _kTokenCatalog.firstWhere((t) => t.id == tokenId);
        _tokens.add(PlacedToken(
          tokenId: template.id,
          label: template.label,
          colorValue: template.color.toARGB32(),
          x: nx,
          y: ny,
        ));
      }
    });
  }

  void _removeToken(String tokenId) {
    setState(() => _tokens.removeWhere((t) => t.tokenId == tokenId));
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
    final play = Play(
      id: _playId,
      name: _name,
      date: DateTime.now(),
      strokes: List.of(_strokes),
      tokens: List.of(_tokens),
    );
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
      _tokens
        ..clear()
        ..addAll(selected.tokens);
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
            onPressed: (_strokes.isEmpty && _tokens.isEmpty) ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Guardar jugada',
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
            _buildTokenTray(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return DragTarget<String>(
                      onAcceptWithDetails: (details) => _onTokenDropped(details.data, details.offset),
                      builder: (context, candidateData, rejectedData) {
                        return Stack(
                          key: _canvasKey,
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
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
                            ),
                            for (final token in _tokens) _buildPlacedToken(token, size),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bandeja con los fichines todavía sin ubicar en la cancha (se arrastran
  /// hacia ella); los que ya están ubicados desaparecen de acá.
  Widget _buildTokenTray() {
    final available = _kTokenCatalog.where((t) => !_tokens.any((p) => p.tokenId == t.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Fichines',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(width: 10),
          Expanded(
            child: available.isEmpty
                ? Text('Todos ubicados en la cancha',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
                : Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final t in available)
                        Draggable<String>(
                          data: t.id,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: _TokenCircle(label: t.label, color: t.color, dragging: true),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _TokenCircle(label: t.label, color: t.color),
                          ),
                          child: _TokenCircle(label: t.label, color: t.color),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Fichín ya ubicado sobre la cancha: se puede arrastrar para reubicarlo
  /// (soltándolo fuera de la cancha no hace nada, queda donde estaba) o
  /// tocarlo para sacarlo (vuelve a la bandeja de disponibles).
  Widget _buildPlacedToken(PlacedToken token, Size canvasSize) {
    final left = (token.x * canvasSize.width - _kTokenSize / 2).clamp(0.0, canvasSize.width - _kTokenSize);
    final top = (token.y * canvasSize.height - _kTokenSize / 2).clamp(0.0, canvasSize.height - _kTokenSize);
    final color = Color(token.colorValue);
    return Positioned(
      left: left,
      top: top,
      child: Draggable<String>(
        data: token.tokenId,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _TokenCircle(label: token.label, color: color, dragging: true),
        childWhenDragging: const SizedBox(width: _kTokenSize, height: _kTokenSize),
        child: GestureDetector(
          onTap: () => _removeToken(token.tokenId),
          child: _TokenCircle(label: token.label, color: color),
        ),
      ),
    );
  }
}
