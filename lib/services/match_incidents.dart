import '../models/match_set.dart';
import '../models/player.dart';
import '../models/volley_match.dart';

/// Incidencias reglamentarias de un partido que no se ven en la tabla de
/// estadísticas: los cambios excepcionales (Regla 15.7) y los líberos
/// declarados sin poder jugar o redesignados (Regla 19.4), en orden. Las usa
/// el resumen (pestaña Tabla) y el PDF; vacía si no hubo ninguna.
List<String> matchIncidents(VolleyMatch match) {
  String name(String id) {
    for (final p in match.ownRoster) {
      if (p.id == id) return '#${p.number} ${p.lastName}';
    }
    return '?';
  }

  String position(String id) {
    for (final p in match.ownRoster) {
      if (p.id == id) return p.position.shortLabel;
    }
    return '';
  }

  final out = <(DateTime, String)>[];
  for (final set in match.sets) {
    for (final s in set.substitutions.where((s) => s.exceptional)) {
      out.add((
        s.timestamp,
        '${_when(set, s.rallyNumber)}: cambio excepcional, sale ${name(s.playerOutId)} '
            '(no vuelve a jugar) y entra ${name(s.playerInId)}.',
      ));
    }
    for (final e in set.liberoUnableEvents) {
      final parts = <String>[
        if (e.unableLiberoIds.isNotEmpty)
          '${e.unableLiberoIds.map(name).join(' y ')} sin poder jugar',
        if (e.newLiberoId != null)
          '${name(e.newLiberoId!)} (${position(e.newLiberoId!)}) redesignado como líbero',
      ];
      out.add((e.timestamp, '${_when(set, e.rallyNumber)}: ${parts.join('; ')}.'));
    }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final o in out) o.$2];
}

/// "Set N (a-b)": el marcador antes del rally [rallyNumber].
String _when(MatchSet set, int rallyNumber) {
  var own = 0, rival = 0;
  for (final ev in set.events) {
    if (ev.rallyNumber >= rallyNumber) break;
    own = ev.ownScoreAfter;
    rival = ev.rivalScoreAfter;
  }
  return 'Set ${set.setNumber} ($own-$rival)';
}
