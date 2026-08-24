import 'package:flutter/material.dart';

import '../../../utils/theme.dart';

/// Cuadrado dividido en 6 partes iguales para elegir la zona de cancha
/// (1-6) a la que fue dirigido un saque o un ataque. Numeración pensada para
/// verse "de frente" desde el punto de vista de quien anota: fila cercana a
/// la red = 2-3-4, fila de fondo = 1-6-5.
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
        SizedBox(
          width: double.infinity,
          child: Text('Fondo',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ),
        Row(children: [cell(1), cell(6), cell(5)]),
        Row(children: [cell(2), cell(3), cell(4)]),
        SizedBox(
          width: double.infinity,
          child: Text('Red',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ),
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
