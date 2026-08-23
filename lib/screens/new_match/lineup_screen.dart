import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_config.dart';
import '../../models/player.dart';
import '../../models/rally_event.dart';
import '../../models/volley_match.dart';
import '../../state/app_data_controller.dart';
import '../../state/match_controller.dart';
import '../../utils/id_gen.dart';
import '../../widgets/theme_toggle_switch.dart';
import '../live/live_match_screen.dart';

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

  Future<void> _start() async {
    if (!_complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asigná un jugador a cada una de las 6 posiciones')),
      );
      return;
    }
    final order = List.generate(6, (i) => _positions[i + 1]!);

    if (_isNextSet) {
      final controller = widget.existingController!;
      final setNumber = controller.match.sets.length + 1;
      controller.startSet(
        setNumber: setNumber,
        startingOrderOwn: order,
        startingServer: _startingServer,
        trackHitZones: _trackHitZones,
        defensiveLiberoId: _defensiveLiberoId,
        receptionLiberoId: _receptionLiberoId,
        autoLiberoBackRowSwap: _autoLiberoBackRowSwap,
      );
      controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
      await context.read<AppDataController>().saveMatch(controller.match);
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
      trackHitZones: _trackHitZones,
      defensiveLiberoId: _defensiveLiberoId,
      receptionLiberoId: _receptionLiberoId,
      autoLiberoBackRowSwap: _autoLiberoBackRowSwap,
    );
    controller.currentSet.rivalSetterStartPosition = _rivalSetterPos;
    await context.read<AppDataController>().saveMatch(match);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LiveMatchScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Orden visual de la cancha (fila delantera 4-3-2, fila trasera 5-6-1).
    const frontRow = [4, 3, 2];
    const backRow = [5, 6, 1];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNextSet ? 'Formación — set siguiente' : 'Formación inicial'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('¿Quién saca primero?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<TeamSide>(
            segments: [
              ButtonSegment(value: TeamSide.own, label: Text(widget.ownTeamName)),
              ButtonSegment(value: TeamSide.rival, label: Text(widget.rivalTeamName)),
            ],
            selected: {_startingServer},
            onSelectionChanged: (s) => setState(() => _startingServer = s.first),
          ),
          if (_isNextSet)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.config.isTieBreakSet(widget.existingController!.match.sets.length + 1)
                    ? 'Tie-break: se vuelve a sortear el saque, elegilo a mano.'
                    : 'Sugerido alternando respecto al set anterior; podés cambiarlo si hace falta.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 20),
          Text('Formación de ${widget.ownTeamName}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Fila delantera (4 - 3 - 2)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: frontRow.map((p) => Expanded(child: _posDropdown(p))).toList(),
          ),
          const SizedBox(height: 8),
          const Text('Fila trasera (5 - 6 - 1, el 1 saca)',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: backRow.map((p) => Expanded(child: _posDropdown(p))).toList(),
          ),
          if (_liberos.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Roles de líbero (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Podés asignar un líbero para la defensa cuando saca tu equipo y otro para la '
              'recepción cuando saca el rival (también puede ser el mismo). Se elige para este '
              'set en particular: en el próximo set lo vas a poder volver a definir.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _liberos.any((p) => p.id == _defensiveLiberoId) ? _defensiveLiberoId : null,
              decoration: const InputDecoration(labelText: 'Líbero defensor (cuando sacamos)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguno')),
                for (final p in _liberos)
                  DropdownMenuItem(value: p.id, child: Text('#${p.number} ${p.fullName}')),
              ],
              onChanged: (v) => setState(() => _defensiveLiberoId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _liberos.any((p) => p.id == _receptionLiberoId) ? _receptionLiberoId : null,
              decoration: const InputDecoration(labelText: 'Líbero receptor (cuando saca el rival)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguno')),
                for (final p in _liberos)
                  DropdownMenuItem(value: p.id, child: Text('#${p.number} ${p.fullName}')),
              ],
              onChanged: (v) => setState(() => _receptionLiberoId = v),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _autoLiberoBackRowSwap,
              title: const Text('Líbero defensor automático'),
              subtitle: const Text(
                'Si está tildado, el líbero defensor entra solo por el central que rota al fondo '
                'cuando saca nuestro equipo (salvo que sea ese central quien va a sacar). '
                'Destildado, ese cambio hay que hacerlo a mano desde el panel de cambios.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (v) => setState(() => _autoLiberoBackRowSwap = v ?? true),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Armador rival (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Solo a modo informativo: en qué posición arranca.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int?>(
            initialValue: _rivalSetterPos,
            decoration: const InputDecoration(labelText: 'Posición del armador rival'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin especificar')),
              for (final p in [1, 2, 3, 4, 5, 6])
                DropdownMenuItem(value: p, child: Text('Posición $p')),
            ],
            onChanged: (v) => setState(() => _rivalSetterPos = v),
          ),
          const SizedBox(height: 24),
          const Text('Opciones', style: TextStyle(fontWeight: FontWeight.w600)),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _trackHitZones,
            title: const Text('Registrar zona de destino en saque y ataque'),
            subtitle: const Text(
              'Al calificar un saque o un ataque, vas a poder marcar (opcional) a qué '
              'zona de la cancha fue dirigido.',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: (v) => setState(() => _trackHitZones = v ?? true),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: _start,
            child: Text(_isNextSet
                ? 'Comenzar set ${(widget.existingController!.match.sets.length + 1)}'
                : 'Comenzar partido'),
          ),
        ],
        ),
      ),
    );
  }

  Player? _playerAt(int pos) {
    final id = _positions[pos];
    if (id == null) return null;
    for (final p in widget.roster) {
      if (p.id == id) return p;
    }
    return null;
  }

  Widget _posDropdown(int pos) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final selectedPlayer = _playerAt(pos);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _positions[pos],
            decoration: InputDecoration(labelText: 'Pos. $pos'),
            isExpanded: true,
            items: _availableFor(pos)
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: isPortrait
                          ? _playerItem(p, p.fullName)
                          : Text(
                              '#${p.number} ${p.fullName} · ${p.position.shortLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                    ))
                .toList(),
            // El área del campo cerrado tiene una altura fija que el sistema
            // de decoración del form field no deja agrandar, así que en
            // vertical se muestra solo el nombre acá y la posición aparte,
            // debajo (ver el Text condicional más abajo).
            selectedItemBuilder: (context) => _availableFor(pos)
                .map((p) => Text(
                      isPortrait
                          ? '#${p.number} ${p.lastName}'
                          : '#${p.number} ${p.lastName} · ${p.position.shortLabel}',
                      overflow: TextOverflow.ellipsis,
                    ))
                .toList(),
            onChanged: (v) => setState(() => _positions[pos] = v),
          ),
          if (isPortrait && selectedPlayer != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                selectedPlayer.position.shortLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  // En vertical no hay ancho suficiente para "#N Nombre · POS" en una sola
  // línea sin cortar la posición del jugador, así que en la lista desplegada
  // se muestra como subtítulo debajo del nombre.
  Widget _playerItem(Player p, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#${p.number} $name',
          style: const TextStyle(fontSize: 14, height: 1.15),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          p.position.shortLabel,
          style: TextStyle(fontSize: 11, height: 1.15, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
