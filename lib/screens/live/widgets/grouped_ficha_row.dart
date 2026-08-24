import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../utils/theme.dart';

/// Recuadro de tamaño fijo para elegir un jugador (mismo lenguaje visual que
/// las celdas de [HitZonePicker]): a diferencia de un Chip, no cambia de
/// ancho/alto según el texto, así el total de filas apiladas por columna en
/// [groupedFichaRow] queda predecible y compacto — evita que el panel haga
/// overflow vertical con varios jugadores agrupados en varias columnas.
class FichaBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const FichaBox({super.key, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaceAlt = surfaceAltColor(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: !enabled ? surfaceAlt.withValues(alpha: 0.5) : (selected ? scheme.secondary : surfaceAlt),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? scheme.secondary : scheme.outline),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selected
                ? const Color(0xFF06222B)
                : (enabled ? scheme.onSurface : scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Arma las fichas para elegir jugador agrupadas por línea de juego, en vez
/// de un simple Wrap en el orden de la lista: una columna con armador y
/// opuesto (armador arriba), otra con el/los central/es, otra con la(s)
/// punta(s) (y universales), y el líbero al lado de esa última columna.
/// Si algún grupo queda vacío (por ejemplo, no hay líbero en cancha) esa
/// columna simplemente no se dibuja.
Widget groupedFichaRow(
  List<Player> players, {
  required bool Function(Player player) isSelected,
  required void Function(Player player) onSelect,
  String Function(Player player)? label,
}) {
  List<Player> byNumber(Iterable<Player> ps) => ps.toList()..sort((a, b) => a.number.compareTo(b.number));

  final armadorOpuesto = byNumber(players.where(
      (p) => p.position == PlayerPosition.armador || p.position == PlayerPosition.opuesto))
    ..sort((a, b) {
      int rank(PlayerPosition p) => p == PlayerPosition.armador ? 0 : 1;
      final r = rank(a.position).compareTo(rank(b.position));
      return r != 0 ? r : a.number.compareTo(b.number);
    });
  final centrales = byNumber(players.where((p) => p.position == PlayerPosition.central));
  final puntas = byNumber(players.where(
      (p) => p.position == PlayerPosition.puntaReceptor || p.position == PlayerPosition.universal));
  final liberos = byNumber(players.where((p) => p.position == PlayerPosition.libero));

  Widget box(Player p) => FichaBox(
        label: label?.call(p) ?? '#${p.number} ${p.lastName}',
        selected: isSelected(p),
        onTap: () => onSelect(p),
      );

  Widget column(List<Player> ps) {
    if (ps.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in ps) Padding(padding: const EdgeInsets.only(bottom: 6), child: box(p)),
      ],
    );
  }

  return Wrap(
    spacing: 10,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: [
      column(armadorOpuesto),
      column(centrales),
      column(puntas),
      column(liberos),
    ],
  );
}
