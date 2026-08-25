import 'package:flutter/foundation.dart';

import '../models/play.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../services/storage_service.dart';

/// Estado global de la app: lista de equipos precargados, archivo de
/// partidos y archivo de jugadas de pizarra guardados. Se mantiene en
/// memoria y se sincroniza con Hive.
class AppDataController extends ChangeNotifier {
  List<Team> teams = [];
  List<VolleyMatch> matches = [];
  List<Play> plays = [];

  Future<void> loadAll() async {
    await StorageService.instance.init();
    teams = StorageService.instance.loadTeams();
    matches = StorageService.instance.loadMatches();
    plays = StorageService.instance.loadPlays();
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
