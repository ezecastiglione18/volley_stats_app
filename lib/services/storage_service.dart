import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const _legacyDeviceIdKey = 'legacy_device_id';
  static const _subscriptionCacheKey = 'subscription_cache';

  late Box _teams;
  late Box _matches;
  late Box _plays;
  late Box _settings;
  late String _deviceId;

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
    _deviceId = await _resolveDeviceId();
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

  /// Identificador de este dispositivo para `AuthService` (distinguir "el
  /// mismo dispositivo volviendo a entrar" de "otro dispositivo tratando de
  /// usar la misma cuenta"). Resuelto una vez en [init] y cacheado en
  /// memoria; ver [_resolveDeviceId] para de dónde sale.
  String loadOrCreateDeviceId() => _deviceId;

  /// Id de dispositivo anterior a la migración a `ANDROID_ID` (ver
  /// [_resolveDeviceId]), si esta cuenta venía de esa versión. Puede seguir
  /// registrado en `account_devices` en Firestore a nombre de este mismo
  /// dispositivo, así que `AuthService` lo usa para reconocerse y migrar el
  /// lugar ya reclamado en vez de perderlo contra el límite del plan.
  String? loadLegacyDeviceId() => _settings.get(_legacyDeviceIdKey) as String?;

  /// Limpia el id legacy una vez que ya cumplió su función (se usó para
  /// migrar o liberar el lugar que tenía reclamado).
  Future<void> clearLegacyDeviceId() async => await _settings.delete(_legacyDeviceIdKey);

  /// En Android usa `Settings.Secure.ANDROID_ID` (vía el plugin `android_id`):
  /// a diferencia de un id guardado solo en Hive, sobrevive a desinstalar y
  /// reinstalar la app en el mismo equipo (aunque no a un reset de fábrica),
  /// que es justo el caso que antes generaba un "dispositivo fantasma" en
  /// `account_devices` — la reinstalación creaba un id nuevo sin liberar el
  /// lugar del anterior, y con el límite de 1 dispositivo del plan gratis
  /// eso dejaba al usuario sin poder volver a entrar a su propia cuenta. Se
  /// sigue cacheando en `_settings` para no depender del plugin en cada
  /// arranque y como respaldo si `getId()` no devuelve nada (algunos ROMs) o
  /// tira excepción; ahí, y en cualquier plataforma que no sea Android
  /// (donde no existe un equivalente a ANDROID_ID), se mantiene el esquema
  /// anterior: un id random generado una sola vez y persistido en Hive (por
  /// lo tanto sí se pierde si se desinstala, como antes).
  ///
  /// Cuentas que ya estaban logueadas con el esquema anterior (id random en
  /// Hive) migran acá mismo: si el `ANDROID_ID` difiere del cacheado, el
  /// cacheado viejo se guarda como [_legacyDeviceIdKey] *antes* de pisarlo
  /// con el nuevo, para que `AuthService` pueda reconocer que este
  /// dispositivo es el mismo que ya tenía un lugar reclamado con ese id
  /// viejo — si no quedara persistido acá (solo en memoria), se perdería en
  /// el primer arranque tras la migración y esa cuenta quedaría trabada
  /// afuera contra el límite de dispositivos.
  Future<String> _resolveDeviceId() async {
    final cached = _settings.get(_deviceIdKey) as String?;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidId = await const AndroidId().getId();
        if (androidId != null && androidId.isNotEmpty) {
          if (androidId != cached) {
            if (cached != null && cached.isNotEmpty) {
              await _settings.put(_legacyDeviceIdKey, cached);
            }
            await _settings.put(_deviceIdKey, androidId);
          }
          return androidId;
        }
      } catch (_) {
        // Defensivo: si el plugin falla, cae al esquema de respaldo abajo.
      }
    }
    if (cached != null && cached.isNotEmpty) return cached;
    final generated = generateId('device_');
    await _settings.put(_deviceIdKey, generated);
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
