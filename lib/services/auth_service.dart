import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'storage_service.dart';

/// Se lanza cuando la cuenta ya está en uso en OTRO dispositivo (distinto
/// [StorageService.loadOrCreateDeviceId]). El login para este dispositivo
/// se rechaza (no se desloguea al que ya estaba adentro).
class DeviceConflictException implements Exception {
  final String otherDeviceLabel;
  DeviceConflictException(this.otherDeviceLabel);

  @override
  String toString() =>
      'Esta cuenta ya está en uso en otro dispositivo${otherDeviceLabel.isEmpty ? '' : ' ($otherDeviceLabel)'}. '
      'Cerrá sesión ahí primero para poder entrar acá.';
}

/// Login por cuenta (un entrenador/comprador) + control de "un solo
/// dispositivo a la vez" por cuenta, para que una sola licencia comprada
/// no se comparta libremente entre varios dispositivos.
///
/// Requiere un proyecto de Firebase (Authentication con Email/Password +
/// Firestore) ya configurado — ver `SETUP_FIREBASE.md` en la raíz del
/// repo para los pasos manuales (crear el proyecto, activar los productos,
/// generar `lib/firebase_options.dart` con `flutterfire configure`). Sin
/// esa configuración, `FirebaseAuth`/`Firestore` van a fallar al usarse.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Colección con un documento por usuario (id = uid de Firebase Auth),
  /// con el `deviceId` que tiene la sesión activa (o null si nadie la
  /// tiene tomada).
  CollectionReference<Map<String, dynamic>> get _devices =>
      _db.collection('account_devices');

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String get _thisDeviceId => StorageService.instance.loadOrCreateDeviceId();

  String get _thisDeviceLabel {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return '';
    }
  }

  /// Inicia sesión y valida el dispositivo. Si la cuenta ya está tomada
  /// por otro dispositivo, deshace el login (`signOut`) y lanza
  /// [DeviceConflictException] — el llamador debe mostrar ese mensaje.
  Future<void> signIn({required String email, required String password}) async {
    final credential =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;
    final docRef = _devices.doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final takenBy = snap.data()?['deviceId'] as String?;
        if (takenBy != null && takenBy.isNotEmpty && takenBy != _thisDeviceId) {
          throw DeviceConflictException(snap.data()?['deviceLabel'] as String? ?? '');
        }
        tx.set(docRef, {
          'deviceId': _thisDeviceId,
          'deviceLabel': _thisDeviceLabel,
          'loggedInAt': FieldValue.serverTimestamp(),
        });
      });
    } on DeviceConflictException {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Registra una cuenta nueva (mismo control de dispositivo que [signIn]:
  /// como es la primera vez, siempre toma la sesión para este dispositivo).
  Future<void> register({required String email, required String password}) async {
    final credential =
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _devices.doc(credential.user!.uid).set({
      'deviceId': _thisDeviceId,
      'deviceLabel': _thisDeviceLabel,
      'loggedInAt': FieldValue.serverTimestamp(),
    });
  }

  /// Libera el dispositivo (para que otro pueda loguearse con esta cuenta)
  /// y cierra la sesión local.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _devices.doc(uid).set({'deviceId': null, 'deviceLabel': null}, SetOptions(merge: true));
    }
    await _auth.signOut();
  }

  /// Revalida que este dispositivo siga siendo el que tiene la sesión
  /// tomada (por si se liberó/tomó desde otro lado mientras esta app
  /// estaba abierta). Si no coincide, cierra la sesión local sin tocar el
  /// documento (no es "este" dispositivo el que la tiene reservada).
  Future<bool> revalidateThisDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return true;
    final snap = await _devices.doc(uid).get();
    final takenBy = snap.data()?['deviceId'] as String?;
    if (takenBy != null && takenBy != _thisDeviceId) {
      await _auth.signOut();
      return false;
    }
    return true;
  }
}
