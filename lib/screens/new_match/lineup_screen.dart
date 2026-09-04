import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../legal/legal_section.dart';
import '../../models/match_config.dart';
import '../../models/player.dart';
import '../../models/rally_event.dart';
import '../../models/volley_match.dart';
import '../../services/paywall_launcher.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../state/subscription_controller.dart';
import '../../utils/id_gen.dart';
import '../../utils/theme.dart';
import '../../widgets/legal_document_dialog.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../live/live_match_screen.dart';
import '../live/widgets/player_select_dialog.dart';
import '../whiteboard/whiteboard_screen.dart';
import 'widgets/position_picker_sheet.dart';

class LineupScreen extends StatefulWidget {
  final String ownTeamName;
  final String? ownTeamSourceId;
  final String rivalTeamName;
  final String? rivalTeamSourceId;
  final String tournament;
  final String round;
  final String court;
  final String category;
  final DateTime date;
  final MatchConfig config;
  final List<Player> roster;

  // Si se pasa un [existingController], esta pantalla configura el
  // siguiente set de un partido ya en curso en lugar de crear uno nuevo.
  final MatchController? existingController;

  const LineupScreen({
    super.key,
    required this.ownTeamName,
    required this.ownTeamSourceId,
    required this.rivalTeamName,
    required this.rivalTeamSourceId,
    required this.tournament,
    required this.round,
    required this.court,
    required this.category,
    required this.date,
    required this.config,
    required this.roster,
    this.existingController,
  });

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  // Orden visual de la cancha (fila delantera 4-3-2, fila trasera 5-6-1) y
  // también el orden en el que se resalta la próxima posición vacía a
  // completar (ver [_nextEmptyPos]).
  static const _frontRow = [4, 3, 2];
  static const _backRow = [5, 6, 1];
  static const _slotOrder = [4, 3, 2, 5, 6, 1];

  final Map<int, String?> _positions = {1: null, 2: null, 3: null, 4: null, 5: null, 6: null};
  TeamSide _startingServer = TeamSide.own;
  int? _rivalSetterPos;
  bool _trackHitZones = true;

  // Roles de líbero de este set (opcionales): se eligen de nuevo en cada
  // set porque el equipo puede usar líberos distintos set a set. Si hay un
  // set anterior en el mismo partido, arrancan precargados con lo elegido
  // ahí (se pueden cambiar); si es el primer set del partido, arrancan vacíos.
  late String? _defensiveLiberoId;
  late String? _receptionLiberoId;

  // Igual que los roles de líbero: se elige de nuevo en cada set (por
  // defecto activado). Si hay un set anterior, arranca con lo elegido ahí.
  bool _autoLiberoBackRowSwap = true;

  bool get _isNextSet => widget.existingController != null;

  @override
  void initState() {
    super.initState();
    final previousSet = widget.existingController?.match.sets.isNotEmpty == true
        ? widget.existingController!.match.sets.last
        : null;
    _defensiveLiberoId = previousSet?.defensiveLiberoId;
    _receptionLiberoId = previousSet?.receptionLiberoId;
    _autoLiberoBackRowSwap = previousSet?.autoLiberoBackRowSwap ?? true;

    // El saque inicial se alterna set a set (regla FIVB), excepto en el
    // set decisivo (tie-break), donde se vuelve a sortear: ahí no se
    // sugiere nada y queda la elección manual del usuario.
    if (previousSet != null) {
      final nextSetNumber = widget.existingController!.match.sets.length + 1;
      if (!widget.config.isTieBreakSet(nextSetNumber)) {
        _startingServer =
            previousSet.startingServer == TeamSide.own ? TeamSide.rival : TeamSide.own;
      }
    }

    // El sexteto titular suele repetirse set a set, así que si hay un set
    // anterior en este mismo partido precargamos su formación inicial acá
    // (se puede cambiar libremente); si es el primer set del partido, los
    // 6 puestos arrancan vacíos.
    final previousOrder = previousSet?.startingOrderOwn;
    if (previousOrder != null) {
      for (var i = 0; i < 6 && i < previousOrder.length; i++) {
        _positions[i + 1] = previousOrder[i];
      }
    }
  }

  List<Player> get _liberos =>
      widget.roster.where((p) => p.position == PlayerPosition.libero).toList();

  List<Player> _availableFor(int pos) {
    final used = _positions.entries
        .where((e) => e.key != pos && e.value != null)
        .map((e) => e.value)
        .toSet();
    // El líbero nunca arranca en el sexteto inicial: solo entra en cancha
    // durante el set a través del cambio de líbero (fila trasera).
    return widget.roster
        .where((p) => p.position != PlayerPosition.libero && !used.contains(p.id))
        .toList();
  }

  bool get _complete => _positions.values.every((v) => v != null);

  int get _filledCount => _positions.values.where((v) => v != null).length;

  /// Primera posición vacía siguiendo el orden visual de la cancha, para
  /// resaltarla como "próxima a completar" (ver `_slotCard`).
  int? get _nextEmptyPos {
    for (final p in _slotOrder) {
      if (_positions[p] == null) return p;
    }
    return null;
  }

  Player? _playerById(String? id) {
    if (id == null) return null;
    for (final p in widget.roster) {
      if (p.id == id) return p;
    }
    return null;
  }

  Player? _playerAt(int pos) => _playerById(_positions[pos]);

  String _zoneLabel(int pos) {
    switch (pos) {
      case 4:
        return 'Delantera izquierda';
      case 3:
        return 'Delantera centro';
      case 2:
        return 'Delantera derecha';
      case 5:
        return 'Zaguera izquierda';
      case 6:
        return 'Zaguera centro';
      case 1:
        return 'Zaguera derecha · saca';
      default:
        return '';
    }
  }

  /// Asigna [playerId] a [pos]. Si ese jugador ya estaba en otra posición,
  /// la intercambia (evita tener que vaciar una posición antes de poder
  /// mover a alguien a otra).
  void _assignToPosition(int pos, String playerId) {
    setState(() {
      int? existingPos;
      for (final entry in _positions.entries) {
        if (entry.value == playerId) {
          existingPos = entry.key;
          break;
        }
      }
      if (existingPos != null && existingPos != pos) {
        _positions[existingPos] = _positions[pos];
      }
      _positions[pos] = playerId;
    });
  }

  Future<void> _openPositionPicker(int pos) {
    return showPositionPickerSheet(
      context: context,
      pos: pos,
      zoneLabel: _zoneLabel(pos),
      roster: widget.roster,
      positions: _positions,
      onAssign: (playerId) => _assignToPosition(pos, playerId),
    );
  }

  /// Gira todo el equipo un puesto, como una rotación real de vóley
  /// (2→1, 1→6, 6→5, 5→4, 4→3, 3→2).
  void _rotateLineup() {
    setState(() {
      final rotated = <int, String?>{
        for (final p in [1, 2, 3, 4, 5, 6]) p: _positions[p == 6 ? 1 : p + 1],
      };
      _positions
        ..clear()
        ..addAll(rotated);
    });
  }

  /// Completa las posiciones vacías con jugadores del plantel todavía sin
  /// asignar, priorizando el rol más habitual para cada puesto. Es solo un
  /// punto de partida: cualquier posición se puede volver a tocar después
  /// para ajustarla a mano.
  void _autocompleteByRole() {
    const roleForPos = {
      4: PlayerPosition.opuesto,
      3: PlayerPosition.central,
      2: PlayerPosition.puntaReceptor,
      5: PlayerPosition.puntaReceptor,
      6: PlayerPosition.central,
      1: PlayerPosition.armador,
    };
    setState(() {
      for (final pos in _slotOrder) {
        if (_positions[pos] != null) continue;
        final available = _availableFor(pos);
        if (available.isEmpty) continue;
        Player? match;
        for (final p in available) {
          if (p.position == roleForPos[pos]) {
            match = p;
            break;
          }
        }
        match ??= available.first;
        _positions[pos] = match.id;
      }
    });
  }

  Future<void> _pickDefensiveLibero() {
    return showSinglePlayerDialog(
      context: context,
      title: 'Líbero defensor (cuando sacamos)',
      players: _liberos,
      onConfirm: (id) => setState(() => _defensiveLiberoId = id),
    );
  }

  Future<void> _pickReceptionLibero() {
    return showSinglePlayerDialog(
      context: context,
      title: 'Líbero receptor (cuando saca el rival)',
      players: _liberos,
      onConfirm: (id) => setState(() => _receptionLiberoId = id),
    );
  }

  Future<void> _pickRivalSetterPos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        // Título + 7 filas puede no entrar en pantallas chicas (sobre todo
        // con teclado/gestos del sistema restando alto): sin este límite +
        // scroll, el contenido desborda por abajo en vez de scrollear.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Posición del armador rival',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                ListTile(
                  title: const Text('Sin especificar'),
                  trailing: _rivalSetterPos == null ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _rivalSetterPos = null);
                  },
                ),
                for (final p in [1, 2, 3, 4, 5, 6])
                  ListTile(
                    title: Text('Posición $p'),
                    trailing: _rivalSetterPos == p ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _rivalSetterPos = p);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirma y, si se acepta, deja la posición [pos] libre otra vez. El
  /// jugador que estaba ahí no se toca en ningún otro lado: sigue en el
  /// plantel y disponible para asignarlo a cualquier otra posición.
  Future<void> _confirmClearPosition(int pos) async {
    final player = _playerAt(pos);
    if (player == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar jugador'),
        content: Text(
          '¿Quitar a ${player.lastName} de la Pos $pos?\n\n'
          'La posición queda libre; el jugador sigue en el plantel, disponible para asignarlo a '
          'otra posición.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _positions[pos] = null);
    }
  }

  void _showHelp() {
    showLegalDocumentDialog(
      context: context,
      title: 'Ayuda — Formación inicial',
      subtitle: '${widget.ownTeamName} vs. ${widget.rivalTeamName}',
      showAcceptButton: false,
      sections: const [
        LegalSection(
          '¿Quién saca primero?',
          'Por regla FIVB, el saque inicial se alterna set a set respecto al anterior — la app ya '
              'lo sugiere marcado, pero se puede cambiar si hace falta. En el set decisivo '
              '(tie-break) se vuelve a sortear, así que ahí no se sugiere nada: hay que elegirlo a '
              'mano.',
        ),
        LegalSection(
          'Sexteto en cancha',
          'Tocá una posición para elegir qué jugador arranca ahí. Si elegís a alguien que ya está '
              'asignado a otra posición, se intercambian los dos (no hace falta vaciar una '
              'primero). Mantené presionada una posición ya asignada para quitar a ese jugador de '
              'ahí (queda libre; el jugador sigue en el plantel, no se borra de ningún lado). '
              '"Rotar" gira todo el equipo un puesto, como una rotación real de vóley. El líbero '
              'no puede arrancar en el sexteto titular: solo entra en cancha durante el set a '
              'través del cambio de líbero, en un puesto de fila trasera.',
        ),
        LegalSection(
          'Roles de líbero',
          'Podés asignar un líbero para la defensa cuando saca tu equipo y otro para la recepción '
              'cuando saca el rival (también puede ser el mismo). Se elige para este set en '
              'particular: en el próximo set lo vas a poder volver a definir.',
        ),
        LegalSection(
          'Cambio automático por central',
          'Si está activado, entra solo el líbero que corresponda por el central que rota al '
              'fondo: el defensor cuando saca nuestro equipo (salvo que sea ese central quien va a '
              'sacar), o el receptor cuando saca el rival. Desactivado, esos cambios hay que '
              'hacerlos a mano desde el panel de cambios durante el set.',
        ),
        LegalSection(
          'Armador rival',
          'Solo a modo informativo: en qué posición arranca el armador del equipo rival.',
        ),
        LegalSection(
          'Opciones de registro',
          'Con "Zonas activadas", al calificar un saque o un ataque vas a poder marcar (opcional) '
              'a qué zona de la cancha fue dirigido. Es una función premium.',
        ),
      ],
    );
  }

  Future<void> _start() async {
    if (!_complete) return;
    final order = List.generate(6, (i) => _positions[i + 1]!);

    final isPremium = context.read<SubscriptionController>().isPremium;

    if (_isNextSet) {
      final controller = widget.existingController!;
      final setNumber = controller.match.sets.length + 1;
      controller.startSet(
        setNumber: setNumber,
        startingOrderOwn: order,
        startingServer: _startingServer,
        trackHitZones: isPremium && _trackHitZones,
        defensiveLiberoId: _defensiveLiberoId,
        receptionLiberoId: _receptionLiberoId,
        autoLiberoBackRowSwap: _autoLiberoBackRowSwap,
      );
      controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
      await context.read<AppDataController>().saveMatch(controller.match, isPremium: isPremium);
      if (!mounted) return;
      Navigator.pop(context); // vuelve a la pantalla en vivo, que ya observa este mismo controller
      return;
    }

    final match = VolleyMatch(
      id: generateId('match_'),
      date: widget.date,
      tournament: widget.tournament,
      round: widget.round,
      court: widget.court,
      category: widget.category,
      ownTeamName: widget.ownTeamName,
      ownTeamSourceId: widget.ownTeamSourceId,
      ownRoster: widget.roster,
      rivalTeamName: widget.rivalTeamName,
      rivalTeamSourceId: widget.rivalTeamSourceId,
      config: widget.config,
    );
    final controller = MatchController(match);
    controller.startSet(
      setNumber: 1,
      startingOrderOwn: order,
      startingServer: _startingServer,
      trackHitZones: isPremium && _trackHitZones,
      defensiveLiberoId: _defensiveLiberoId,
      receptionLiberoId: _receptionLiberoId,
      autoLiberoBackRowSwap: _autoLiberoBackRowSwap,
    );
    controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
    try {
      await context.read<AppDataController>().saveMatch(match, isPremium: isPremium);
    } on MatchArchiveLimitException {
      if (!mounted) return;
      await showRallyStatsPaywall(context);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LiveMatchScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionController>().isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNextSet ? 'Formación — set siguiente' : 'Formación inicial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ayuda',
            onPressed: _showHelp,
          ),
          IconButton(
            icon: const Icon(Icons.draw_outlined),
            tooltip: 'Pizarra',
            onPressed: () => runIfPremium(
              context,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WhiteboardScreen()),
              ),
            ),
          ),
          const ThemeToggleSwitch(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCaption('SAQUE INICIAL', trailing: _serveHint()),
            const SizedBox(height: 6),
            SegmentedButton<TeamSide>(
              segments: [
                ButtonSegment(value: TeamSide.own, label: Text(widget.ownTeamName)),
                ButtonSegment(value: TeamSide.rival, label: Text(widget.rivalTeamName)),
              ],
              selected: {_startingServer},
              onSelectionChanged: (s) => setState(() => _startingServer = s.first),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _sectionCaption('SEXTETO EN CANCHA')),
                if (_complete)
                  TextButton.icon(
                    onPressed: _rotateLineup,
                    icon: const Icon(Icons.rotate_right, size: 16),
                    label: const Text('Rotar'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _frontRow.map((p) => Expanded(child: _slotCard(p))).toList(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _backRow.map((p) => Expanded(child: _slotCard(p))).toList(),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _complete ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: _complete ? successColor(context) : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _complete ? '6 de 6 posiciones asignadas · sin repetidos' : '$_filledCount de 6 asignadas',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (!_complete)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: _autocompleteByRole,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_fix_high, size: 16, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Autocompletar por rol',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_liberos.isNotEmpty) ...[
              const Divider(height: 28),
              _sectionCaption('LÍBEROS'),
              const SizedBox(height: 4),
              _settingsRow(
                icon: Icons.shield_outlined,
                label: 'Defensor · sacamos nosotros',
                value: _playerById(_defensiveLiberoId),
                onTap: _pickDefensiveLibero,
              ),
              _settingsRow(
                icon: Icons.pan_tool_outlined,
                label: 'Receptor · saca el rival',
                value: _playerById(_receptionLiberoId),
                onTap: _pickReceptionLibero,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _autoLiberoBackRowSwap,
                title: const Text('Cambio automático por central',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Entra solo al fondo', style: TextStyle(fontSize: 11)),
                onChanged: (v) => setState(() => _autoLiberoBackRowSwap = v ?? true),
              ),
            ],
            const Divider(height: 28),
            _tapRow(
              label: 'Armador rival',
              value: _rivalSetterPos == null ? 'Sin especificar' : 'Posición $_rivalSetterPos',
              onTap: _pickRivalSetterPos,
            ),
            const Divider(height: 12),
            _registrationOptionsRow(isPremium),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _complete ? _start : null,
              child: Text(_isNextSet
                  ? 'Comenzar set ${(widget.existingController!.match.sets.length + 1)}'
                  : 'Comenzar partido'),
            ),
          ],
        ),
      ),
    );
  }

  String? _serveHint() {
    if (!_isNextSet) return null;
    final nextSetNumber = widget.existingController!.match.sets.length + 1;
    if (widget.config.isTieBreakSet(nextSetNumber)) return 'se vuelve a sortear';
    return 'alterna con el set $nextSetNumber';
  }

  Widget _sectionCaption(String text, {String? trailing}) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: color);
    if (trailing == null) return Text(text, style: style);
    return Row(
      children: [
        Text(text, style: style),
        const Spacer(),
        Text(trailing, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _slotCard(int pos) {
    final scheme = Theme.of(context).colorScheme;
    final player = _playerAt(pos);
    final filled = player != null;
    final isNext = !_complete && pos == _nextEmptyPos;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPositionPicker(pos),
        onLongPress: filled ? () => _confirmClearPosition(pos) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: filled
                ? surfaceAltColor(context)
                : (isNext ? scheme.secondary.withValues(alpha: 0.08) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNext ? scheme.secondary : (filled ? scheme.outline : scheme.outline.withValues(alpha: 0.5)),
              width: isNext ? 2 : 1,
            ),
          ),
          child: filled
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('POS $pos',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '#${player.number} ${player.lastName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      player.position.shortLabel,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20, color: isNext ? scheme.secondary : scheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(
                      'Asignar',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNext ? scheme.secondary : scheme.onSurfaceVariant,
                        fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text('POS $pos', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required Player? value,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  Text(
                    value != null ? '#${value.number} ${value.fullName}' : 'Sin asignar',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _tapRow({required String label, required String value, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text(value, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _registrationOptionsRow(bool isPremium) {
    final scheme = Theme.of(context).colorScheme;
    final active = isPremium && _trackHitZones;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (isPremium) {
          setState(() => _trackHitZones = !_trackHitZones);
        } else {
          showRallyStatsPaywall(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const Expanded(
              child: Text('Opciones de registro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? successColor(context).withValues(alpha: 0.15) : surfaceAltColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? successColor(context) : scheme.outline),
              ),
              child: Text(
                active ? 'Zonas activadas' : 'Zonas desactivadas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? successColor(context) : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
