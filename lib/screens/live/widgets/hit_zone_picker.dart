import 'package:flutter/material.dart';

import '../../../utils/theme.dart';

/// Cuadrado dividido en 6 partes iguales para elegir la zona de cancha
/// (1-6) a la que fue dirigido un saque o un ataque. Usa la misma
/// numeración que el resto de la app: fila cercana a la red = 4-3-2, fila de
/// fondo = 5-6-1.
class HitZonePicker extends StatelessWidget {
  final int? selectedZone;
  final ValueChanged<int?> onChanged;

  const HitZonePicker({super.key, required this.selectedZone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaceAlt = surfaceAltColor(context);

    Widget cell(int zone) {
      final isSel = selectedZone == zone;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isSel ? null : zone),
          child: Container(
            margin: const EdgeInsets.all(2),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel ? scheme.secondary : surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isSel ? scheme.secondary : scheme.outline),
            ),
            child: Text(
              '$zone',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSel ? const Color(0xFF06222B) : scheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zona de destino (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('Red', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        Row(children: [cell(4), cell(3), cell(2)]),
        Row(children: [cell(5), cell(6), cell(1)]),
        Text('Fondo', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        if (selectedZone != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onChanged(null),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: const Text('Quitar zona', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}
