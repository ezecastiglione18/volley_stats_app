import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../utils/theme.dart';

/// Bottom sheet para asignar (o reasignar) un jugador a una posición de la
/// formación inicial. El toque sobre un jugador asigna directo y cierra la
/// hoja (sin paso de confirmación intermedio): con hasta 6 posiciones para
/// cargar, ahorra un toque por cada una. Los líberos se muestran siempre,
/// pero bloqueados (nunca arrancan en el sexteto titular), y un jugador que
/// ya está en otra posición se muestra marcado para poder intercambiarlo en
/// vez de tener que vaciar esa posición primero.
Future<void> showPositionPickerSheet({
  required BuildContext context,
  required int pos,
  required String zoneLabel,
  required List<Player> roster,
  required Map<int, String?> positions,
  required void Function(String playerId) onAssign,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _PositionPickerSheetBody(
      pos: pos,
      zoneLabel: zoneLabel,
      roster: roster,
      positions: positions,
      onAssign: onAssign,
    ),
  );
}

class _PositionPickerSheetBody extends StatefulWidget {
  final int pos;
  final String zoneLabel;
  final List<Player> roster;
  final Map<int, String?> positions;
  final void Function(String playerId) onAssign;

  const _PositionPickerSheetBody({
    required this.pos,
    required this.zoneLabel,
    required this.roster,
    required this.positions,
    required this.onAssign,
  });

  @override
  State<_PositionPickerSheetBody> createState() => _PositionPickerSheetBodyState();
}

class _PositionPickerSheetBodyState extends State<_PositionPickerSheetBody> {
  final _searchCtrl = TextEditingController();
  PlayerPosition? _filter;

  static const _filterRoles = [
    PlayerPosition.armador,
    PlayerPosition.opuesto,
    PlayerPosition.central,
    PlayerPosition.puntaReceptor,
    PlayerPosition.universal,
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _positionOf(String playerId) {
    for (final entry in widget.positions.entries) {
      if (entry.value == playerId) return entry.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim().toLowerCase();

    final nonLiberos = widget.roster.where((p) => p.position != PlayerPosition.libero);
    final availableRoles = nonLiberos.map((p) => p.position).toSet();

    var players = nonLiberos.toList();
    if (_filter != null) {
      players = players.where((p) => p.position == _filter).toList();
    }
    if (query.isNotEmpty) {
      players = players
          .where((p) => p.number.toString().contains(query) || p.lastName.toLowerCase().contains(query))
          .toList();
    }
    players.sort((a, b) => a.number.compareTo(b.number));

    final liberos = widget.roster.where((p) => p.position == PlayerPosition.libero).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Elegir jugador · Pos ${widget.pos}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.zoneLabel,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Buscar por número o apellido',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(null, 'Todos'),
                    for (final role in _filterRoles)
                      if (availableRoles.contains(role)) _filterChip(role, role.shortLabel),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in players) _playerRow(context, p),
                      if (players.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No hay jugadores que coincidan.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                      if (liberos.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1),
                        ),
                        for (final p in liberos) _liberoRow(context, p),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(PlayerPosition? role, String label) {
    final selected = _filter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = selected ? null : role),
      ),
    );
  }

  Widget _playerRow(BuildContext context, Player p) {
    final scheme = Theme.of(context).colorScheme;
    final existingPos = _positionOf(p.id);
    final isCurrent = existingPos == widget.pos;
    final movingFrom = existingPos != null && !isCurrent ? existingPos : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      tileColor: isCurrent ? scheme.secondary.withValues(alpha: 0.08) : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: surfaceAltColor(context),
        child: Text('${p.number}', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
      ),
      title: Text(p.fullName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        movingFrom != null ? 'Ya está en Pos $movingFrom · tocá para mover' : p.position.label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: movingFrom != null ? scheme.secondary : scheme.onSurfaceVariant,
          fontWeight: movingFrom != null ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: movingFrom != null
          ? Icon(Icons.swap_horiz, color: scheme.secondary)
          : (isCurrent ? Icon(Icons.check_circle, color: scheme.secondary) : null),
      onTap: () {
        Navigator.pop(context);
        widget.onAssign(p.id);
      },
    );
  }

  Widget _liberoRow(BuildContext context, Player p) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: surfaceAltColor(context),
        child: Text('${p.number}', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
      ),
      title: Text(p.fullName, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Líbero · no arranca en el sexteto titular', style: TextStyle(fontSize: 12)),
      trailing: Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
    );
  }
}
