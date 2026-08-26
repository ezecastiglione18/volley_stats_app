import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/play.dart';
import '../models/team.dart';
import '../models/volley_match.dart';
import '../utils/id_gen.dart';

/// Guarda Equipos y Partidos como Map<String,dynamic> planos dentro de Hive,
/// sin necesidad de generar TypeAdapters (evita build_runner).
class StorageService {
  static const _teamsBox = 'teams_box';
  static const _matchesBox = 'matches_box';
  static const _playsBox = 'plays_box';
  static const _settingsBox = 'settings_box';
  static const _themeModeKey = 'theme_mode';
  static const _deviceIdKey = 'device_id';
  static const _subscriptionCacheKey = 'subscription_cache';

  late Box _teams;
  late Box _matches;
  late Box _plays;
  late Box _settings;

  static final StorageService instance = StorageService._();
  StorageService._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _teams = await Hive.openBox(_teamsBox);
    _matches = await Hive.openBox(_matchesBox);
    _plays = await Hive.openBox(_playsBox);
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

  // ---------------- Plays (jugadas de la pizarra táctica) ----------------

  List<Play> loadPlays() {
    final list = _plays.values
        .map((v) => Play.fromJson(Map<dynamic, dynamic>.from(v as Map)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> savePlay(Play play) async {
    await _plays.put(play.id, play.toJson());
  }

  Future<void> deletePlay(String playId) async {
    await _plays.delete(playId);
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

  /// Identificador de esta instalación (no del hardware): se genera una
  /// sola vez y se guarda local. Sirve para que el backend de cuentas
  /// (ver `AuthService`) sepa distinguir "el mismo dispositivo volviendo a
  /// entrar" de "otro dispositivo tratando de usar la misma cuenta". Se
  /// pierde si se desinstala la app o se borran los datos, igual que el
  /// resto de lo guardado en Hive.
  String loadOrCreateDeviceId() {
    final existing = _settings.get(_deviceIdKey) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = generateId('device_');
    _settings.put(_deviceIdKey, generated);
    return generated;
  }

  /// Última caché conocida del estado de la suscripción (ver
  /// `SubscriptionController`), para poder resolver algo razonable al abrir
  /// la app sin depender de una llamada de red a RevenueCat. `null` si
  /// todavía no se guardó nunca (primera vez que se abre la app).
  Map<String, dynamic>? loadSubscriptionCache() {
    final raw = _settings.get(_subscriptionCacheKey) as String?;
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSubscriptionCache(Map<String, dynamic> json) async {
    await _settings.put(_subscriptionCacheKey, jsonEncode(json));
  }
}
