import 'package:flutter/material.dart';

/// Diámetro (en píxeles lógicos) de un fichín de la pizarra.
const double kTokenSize = 40;

/// Círculo con la letra del puesto, usado en la bandeja de fichines
/// disponibles, ya apoyado sobre la cancha y en la reproducción de una
/// jugada (`PlayPlaybackScreen`).
class TokenCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool dragging;
  const TokenCircle({super.key, required this.label, required this.color, this.dragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kTokenSize,
      height: kTokenSize,
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
