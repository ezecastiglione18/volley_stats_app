import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// No se pudo leer o registrar el cupo free contra Firestore (sin conexión,
/// o el servidor no respondió a tiempo). Registrar el cupo necesita red.
class FreeStatsOfflineException implements Exception {
  final Object? cause;
  FreeStatsOfflineException([this.cause]);

  @override
  String toString() =>
      'Hace falta conexión a internet para usar la estadística gratis. Conectate y probá de nuevo.';
}

/// Fuente de verdad del cupo free de estadística: uno por cuenta, en todos
/// sus dispositivos (campo `freeStatsMatchId` de `account_devices/{uid}`).
/// Localmente queda solo una caché por cuenta (`StorageService`) para
/// leerlo sin red. Interfaz para poder probar `AppDataController` con un
/// fake, sin Firebase.
abstract class FreeStatsQuotaStore {
  /// El id registrado para [uid], o `null` si todavía no gastó el cupo.
  /// Lanza [FreeStatsOfflineException] si no puede consultar al servidor.
  Future<String?> read(String uid);

  /// Registra [matchId] solo si [uid] todavía no tenía uno ("solo si no
  /// existe"). Devuelve el id que quedó: [matchId], o el que ya estaba (gana
  /// el primero). Lanza [FreeStatsOfflineException] sin conexión.
  Future<String> claimIfAbsent(String uid, String matchId);
}

class FirestoreFreeStatsQuotaStore implements FreeStatsQuotaStore {
  static const _field = 'freeStatsMatchId';

  /// Las transacciones de Firestore no funcionan sin red y, según la
  /// plataforma, pueden tardar en fallar: pasado este tiempo se informa como
  /// sin conexión.
  static const _timeout = Duration(seconds: 15);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('account_devices').doc(uid);

  @override
  Future<String?> read(String uid) async {
    try {
      // Del servidor y no de la caché de Firestore: una caché vieja sin el
      // campo haría creer que el cupo está libre.
      final snap = await _doc(uid).get(const GetOptions(source: Source.server)).timeout(_timeout);
      final value = snap.data()?[_field];
      return value is String && value.isNotEmpty ? value : null;
    } catch (e) {
      throw FreeStatsOfflineException(e);
    }
  }

  @override
  Future<String> claimIfAbsent(String uid, String matchId) async {
    final ref = _doc(uid);
    try {
      return await FirebaseFirestore.instance.runTransaction<String>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          // La cuenta se borró: `update` (no `set`) para no recrear el
          // documento de una cuenta que ya no existe.
          throw StateError('account_devices/$uid no existe');
        }
        final existing = snap.data()?[_field];
        if (existing is String && existing.isNotEmpty) return existing;
        tx.update(ref, {_field: matchId});
        return matchId;
      }).timeout(_timeout);
    } catch (e) {
      throw FreeStatsOfflineException(e);
    }
  }
}
