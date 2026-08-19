import 'package:hive_flutter/hive_flutter.dart';

import '../models/team.dart';
import '../models/volley_match.dart';

/// Guarda Equipos y Partidos como Map<String,dynamic> planos dentro de Hive,
/// sin necesidad de generar TypeAdapters (evita build_runner).
class StorageService {
  static const _teamsBox = 'teams_box';
  static const _matchesBox = 'matches_box';

  late Box _teams;
  late Box _matches;

  static final StorageService instance = StorageService._();
  StorageService._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _teams = await Hive.openBox(_teamsBox);
    _matches = await Hive.openBox(_matchesBox);
    _ready = true;
  }

  // ---------------- Teams ----------------

  List<Team> loadTeams() {
    return _teams.values
        .map((v) => Team.fromJson(Map<dynamic, dynamic>.from(v as Map)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveTeam(Team team) async {
    await _teams.put(team.id, team.toJson());
  }

  Future<void> deleteTeam(String teamId) async {
    await _teams.delete(teamId);
  }

  // ---------------- Matches ----------------

  List<VolleyMatch> loadMatches() {
    final list = _matches.values
        .map((v) => VolleyMatch.fromJson(Map<dynamic, dynamic>.from(v as Map)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> saveMatch(VolleyMatch match) async {
    await _matches.put(match.id, match.toJson());
  }

  Future<void> deleteMatch(String matchId) async {
    await _matches.delete(matchId);
  }
}
