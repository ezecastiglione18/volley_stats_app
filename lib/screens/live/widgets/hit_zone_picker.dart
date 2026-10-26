import 'package:flutter/material.dart';

import '../../../utils/theme.dart';

/// Cuadrado dividido en 6 partes iguales (o 9, con [nineZones]) para elegir
/// la zona de cancha rival a la que fue dirigido un saque o un ataque.
/// Numeración pensada para verse "de frente" desde el punto de vista de
/// quien anota: fila cercana a la red = 2-3-4, fila de fondo = 1-6-5 y, con
/// 9 zonas, la franja media = 9-8-7 (el 7 queda entre el 4 y el 5 del rival,
/// el 9 entre su 2 y su 1, como en la numeración de DataVolley).
class HitZonePicker extends StatelessWidget {
  final int? selectedZone;
  final ValueChanged<int?> onChanged;
  final bool nineZones;

  const HitZonePicker({
    super.key,
    required this.selectedZone,
    required this.onChanged,
    this.nineZones = false,
  });

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
        if (nineZones) Row(children: [cell(9), cell(8), cell(7)]),
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

/// Fila de 6 botones (1 a 6) para indicar, de forma opcional, desde qué zona
/// de nuestra cancha se hizo un ataque o una contra (`RallyEvent.originZone`).
/// Tocar la zona elegida la quita.
class OriginZoneRow extends StatelessWidget {
  final int? selectedZone;
  final ValueChanged<int?> onChanged;

  const OriginZoneRow({super.key, required this.selectedZone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaceAlt = surfaceAltColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Desde qué zona? (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var zone = 1; zone <= 6; zone++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(selectedZone == zone ? null : zone),
                  child: Container(
                    key: ValueKey('origin-zone-$zone'),
                    margin: const EdgeInsets.all(2),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedZone == zone ? scheme.secondary : surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selectedZone == zone ? scheme.secondary : scheme.outline),
                    ),
                    child: Text(
                      '$zone',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: selectedZone == zone ? const Color(0xFF06222B) : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
