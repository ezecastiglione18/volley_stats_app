import 'package:flutter/foundation.dart';

import '../models/team.dart';
import '../models/volley_match.dart';
import '../services/storage_service.dart';

/// Estado global de la app: lista de equipos precargados y archivo de
/// partidos guardados. Se mantiene en memoria y se sincroniza con Hive.
class AppDataController extends ChangeNotifier {
  List<Team> teams = [];
  List<VolleyMatch> matches = [];

  Future<void> loadAll() async {
    await StorageService.instance.init();
    teams = StorageService.instance.loadTeams();
    matches = StorageService.instance.loadMatches();
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

  Future<void> saveMatch(VolleyMatch match) async {
    await StorageService.instance.saveMatch(match);
    final idx = matches.indexWhere((m) => m.id == match.id);
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
    notifyListeners();
  }
}
