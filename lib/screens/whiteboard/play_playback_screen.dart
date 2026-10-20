import 'package:flutter/material.dart';

import '../../models/play.dart';
import 'widgets/playback.dart';
import 'widgets/token_circle.dart';
import 'widgets/whiteboard_painter.dart';

/// Reproduce una jugada guardada: los trazos se van dibujando en el orden en
/// que se hicieron (las flechas aparecen al completarse cada trazo) y los
/// fichines se ven siempre completos. Duración a 1×: 8 ms por punto, entre 2
/// y 12 s (ver [playbackDuration]). Arranca reproduciendo.
class PlayPlaybackScreen extends StatefulWidget {
  final Play play;
  const PlayPlaybackScreen({super.key, required this.play});

  @override
  State<PlayPlaybackScreen> createState() => _PlayPlaybackScreenState();
}

class _PlayPlaybackScreenState extends State<PlayPlaybackScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Duration _baseDuration;
  int _speed = 1; // 1× o 2×

  @override
  void initState() {
    super.initState();
    _baseDuration = playbackDuration(totalPoints(widget.play.strokes));
    _controller = AnimationController(vsync: this, duration: _baseDuration)
      ..addStatusListener((status) {
        // Al llegar al final hay que redibujar el botón (pasa a "repetir").
        if (status == AnimationStatus.completed && mounted) setState(() {});
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _controller.forward(from: 0);
    setState(() {});
  }

  void _togglePlay() {
    if (_controller.isAnimating) {
      _controller.stop();
    } else if (_controller.value >= 1) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
    setState(() {});
  }

  void _setSpeed(int speed) {
    final wasPlaying = _controller.isAnimating;
    _speed = speed;
    _controller.duration = _baseDuration ~/ speed;
    // La duración nueva solo se aplica al volver a arrancar desde donde está.
    if (wasPlaying) _controller.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final play = widget.play;

    return Scaffold(
      appBar: AppBar(title: Text(play.name)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => CustomPaint(
                              size: size,
                              painter: WhiteboardPainter(
                                strokes: play.strokes,
                                progress: _controller.value,
                                courtColor: scheme.surfaceContainerHighest,
                                lineColor: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        // Los fichines no se animan: están desde el primer cuadro.
                        for (final token in play.tokens)
                          Positioned(
                            left: (token.x * size.width - kTokenSize / 2)
                                .clamp(0.0, size.width - kTokenSize),
                            top: (token.y * size.height - kTokenSize / 2)
                                .clamp(0.0, size.height - kTokenSize),
                            child: TokenCircle(label: token.label, color: Color(token.colorValue)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final atEnd = _controller.value >= 1 && !_controller.isAnimating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Reiniciar',
            icon: const Icon(Icons.restart_alt),
            onPressed: _restart,
          ),
          IconButton(
            tooltip: _controller.isAnimating ? 'Pausar' : (atEnd ? 'Repetir' : 'Reproducir'),
            icon: Icon(_controller.isAnimating ? Icons.pause : (atEnd ? Icons.replay : Icons.play_arrow)),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Slider(
                value: _controller.value.clamp(0.0, 1.0),
                // Arrastrar pausa; al soltar queda pausado, desde ahí se
                // puede retomar con Reproducir.
                onChangeStart: (_) {
                  _controller.stop();
                  setState(() {});
                },
                onChanged: (v) => _controller.value = v,
              ),
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1×')),
              ButtonSegment(value: 2, label: Text('2×')),
            ],
            selected: {_speed},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setSpeed(s.first),
          ),
        ],
      ),
    );
  }
}
