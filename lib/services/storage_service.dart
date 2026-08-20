import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/team.dart';
import '../models/volley_match.dart';

/// Guarda Equipos y Partidos como Map<String,dynamic> planos dentro de Hive,
/// sin necesidad de generar TypeAdapters (evita build_runner).
class StorageService {
  static const _teamsBox = 'teams_box';
  static const _matchesBox = 'matches_box';
  static const _settingsBox = 'settings_box';
  static const _themeModeKey = 'theme_mode';

  late Box _teams;
  late Box _matches;
  late Box _settings;

  static final StorageService instance = StorageService._();
  StorageService._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _teams = await Hive.openBox(_teamsBox);
    _matches = await Hive.openBox(_matchesBox);
    _settings = await Hive.openBox(_settingsBox);
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

  // ---------------- Settings (preferencias de la app) ----------------

  /// Modo de tema elegido manualmente por el usuario. Por defecto, claro.
  ThemeMode loadThemeMode() {
    final v = _settings.get(_themeModeKey, defaultValue: 'light') as String;
    return v == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _settings.put(_themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
