import 'package:flutter/foundation.dart';

import '../models/fixture_entry.dart';
import '../models/play.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../services/storage_service.dart';

/// Se lanza al intentar guardar un partido nuevo (no una actualización de
/// uno ya guardado) cuando la cuenta no es premium y el archivo ya llegó al
/// tope de 3 partidos de la versión free.
class MatchArchiveLimitException implements Exception {
  @override
  String toString() =>
      'La versión free permite hasta 3 partidos en el archivo. Suscribite a premium '
      'para guardar partidos ilimitados.';
}

/// Estado global de la app: lista de equipos precargados, archivo de
/// partidos y archivo de jugadas de pizarra guardados. Se mantiene en
/// memoria y se sincroniza con Hive.
class AppDataController extends ChangeNotifier {
  List<Team> teams = [];
  List<VolleyMatch> matches = [];
  List<Play> plays = [];

  /// Fixture (partidos por jugar), por fecha ascendente.
  List<FixtureEntry> fixtureEntries = [];

  /// Id del partido que ya consumió el único cupo de estadística de la
  /// versión free (ver [registerFreeStatsUsage]). `null` si todavía no se
  /// generó ninguna.
  String? freeStatsMatchId;

  Future<void> loadAll() async {
    await StorageService.instance.init();
    teams = StorageService.instance.loadTeams();
    matches = StorageService.instance.loadMatches();
    plays = StorageService.instance.loadPlays();
    fixtureEntries = StorageService.instance.loadFixtureEntries();
    freeStatsMatchId = StorageService.instance.loadFreeStatsMatchId();
    notifyListeners();
  }

  Future<void> saveTeam(Team team) async {
    await StorageService.instance.saveTeam(team);
    final idx = teams.indexWhere((t) => t.id == team.id);
    if (idx == -1) {
      teams.add(team);
    } else {
      teams[idx] = team;
    }
    teams.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  Future<void> deleteTeam(String teamId) async {
    await StorageService.instance.deleteTeam(teamId);
    teams.removeWhere((t) => t.id == teamId);
    notifyListeners();
  }

  /// [isPremium] es obligatorio a propósito: fuerza a que cada lugar que
  /// crea/guarda un partido pase el estado de suscripción actual, para que
  /// el tope de 3 partidos de la versión free (sólo aplica a partidos
  /// *nuevos*, no a actualizar uno ya contado) no se pueda pisar por
  /// descuido.
  Future<void> saveMatch(VolleyMatch match, {required bool isPremium}) async {
    final idx = matches.indexWhere((m) => m.id == match.id);
    if (idx == -1 && !isPremium && matches.length >= 3) {
      throw MatchArchiveLimitException();
    }
    await StorageService.instance.saveMatch(match);
    if (idx == -1) {
      matches.add(match);
    } else {
      matches[idx] = match;
    }
    matches.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deleteMatch(String matchId) async {
    await StorageService.instance.deleteMatch(matchId);
    matches.removeWhere((m) => m.id == matchId);
    // Si el partido salía de una fila del fixture, esa fila vuelve a quedar
    // "sin jugar" (no se borra: el partido por jugar sigue existiendo).
    for (final entry in fixtureEntries.where((e) => e.linkedMatchId == matchId)) {
      entry.linkedMatchId = null;
      await StorageService.instance.saveFixtureEntry(entry);
    }
    notifyListeners();
  }

  // ---------------- Fixture ----------------

  Future<void> saveFixtureEntry(FixtureEntry entry) async {
    await StorageService.instance.saveFixtureEntry(entry);
    final idx = fixtureEntries.indexWhere((e) => e.id == entry.id);
    if (idx == -1) {
      fixtureEntries.add(entry);
    } else {
      fixtureEntries[idx] = entry;
    }
    fixtureEntries.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  Future<void> deleteFixtureEntry(String entryId) async {
    await StorageService.instance.deleteFixtureEntry(entryId);
    fixtureEntries.removeWhere((e) => e.id == entryId);
    notifyListeners();
  }

  /// Vincula la fila [entryId] del fixture con el partido [matchId] recién
  /// creado a partir de ella (queda como "jugada"). No-op si la fila ya no
  /// existe (se borró mientras se armaba el partido).
  Future<void> linkFixtureEntryToMatch(String entryId, String matchId) async {
    final idx = fixtureEntries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    fixtureEntries[idx].linkedMatchId = matchId;
    await StorageService.instance.saveFixtureEntry(fixtureEntries[idx]);
    notifyListeners();
  }

  /// El partido de la fila [entry], si todavía existe en el archivo. Una fila
  /// cuyo `linkedMatchId` apunta a un partido que ya no está cuenta como
  /// "sin jugar".
  VolleyMatch? linkedMatchOf(FixtureEntry entry) {
    final id = entry.linkedMatchId;
    if (id == null) return null;
    for (final m in matches) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Marca [matchId] como el partido que gastó el único cupo de estadística
  /// free, tras la confirmación explícita del usuario (ver
  /// `_FreeStatsConfirmScreen` en `MatchSummaryScreen` — no se llama por el
  /// solo hecho de entrar a mirar). No-op si el cupo ya estaba gastado (con
  /// este mismo partido o con otro). El registro persiste aunque el partido
  /// se borre del archivo después.
  Future<void> registerFreeStatsUsage(String matchId) async {
    if (freeStatsMatchId != null) return;
    freeStatsMatchId = matchId;
    await StorageService.instance.saveFreeStatsMatchId(matchId);
    notifyListeners();
  }

  Future<void> savePlay(Play play) async {
    await StorageService.instance.savePlay(play);
    final idx = plays.indexWhere((p) => p.id == play.id);
    if (idx == -1) {
      plays.add(play);
    } else {
      plays[idx] = play;
    }
    plays.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deletePlay(String playId) async {
    await StorageService.instance.deletePlay(playId);
    plays.removeWhere((p) => p.id == playId);
    notifyListeners();
  }
}
