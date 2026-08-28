import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'storage_service.dart';
import 'subscription_tiers.dart';
import '../utils/platform_support.dart';

/// Se lanza cuando la cuenta ya alcanzó el máximo de dispositivos que
/// permite su plan actual. El login para este dispositivo se rechaza (no
/// se desloguea a ninguno de los que ya estaban adentro).
class DeviceConflictException implements Exception {
  final int deviceLimit;
  DeviceConflictException(this.deviceLimit);

  @override
  String toString() =>
      'Esta cuenta ya alcanzó el máximo de $deviceLimit dispositivo${deviceLimit == 1 ? '' : 's'} '
      'para su plan actual. Cerrá sesión en alguno de los otros dispositivos, o sumá un '
      'complemento de dispositivo adicional, para poder entrar acá.';
}

/// Login por cuenta (un entrenador/comprador) + control de cuántos
/// dispositivos pueden tener la sesión activa a la vez por cuenta, para que
/// una sola suscripción no se comparta libremente sin límite. El límite
/// depende del plan de RevenueCat activo (ver `SubscriptionController`/
/// `subscription_tiers.dart`): 1 por defecto, hasta 4 sumando complementos.
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

  /// Future de todo el proceso de `signIn`/`register` en curso (si hay uno),
  /// compartido con `revalidateThisDevice`. Existe por una condición de
  /// carrera real: `authStateChanges` puede avisar la sesión nueva —y
  /// `_AuthGate` reaccionar llamando a `revalidateThisDevice`— en cualquier
  /// punto de `_auth.signInWithEmailAndPassword(...)`, incluso antes de que
  /// esa llamada termine de resolverse del lado de este mismo método; si
  /// `revalidateThisDevice` llega a leer Firestore antes de que el reclamo
  /// del lugar termine de guardarse, ve el dispositivo ausente y desloguea
  /// al toque (de ahí que hiciera falta un segundo intento de login para
  /// que ya lo encontrara guardado). Por eso este campo se instala *antes*
  /// de tocar Firebase Auth siquiera (ver `_withPendingClaim`), no después
  /// de que se resuelve: así no queda ninguna ventana, sea cual sea el
  /// orden real en que el plugin dispare el `Future` del login y el evento
  /// del stream.
  Future<void>? _pendingClaim;

  /// Colección con un documento por usuario (id = uid de Firebase Auth),
  /// con el mapa `devices` de los dispositivos que tienen la sesión activa
  /// (deviceId -> {label, loggedInAt}).
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

  /// Inicia sesión y reclama un lugar de dispositivo. Si la cuenta ya
  /// alcanzó el límite de su plan (y este dispositivo no es uno de los que
  /// ya lo tenían), deshace el login (`signOut`) y lanza
  /// [DeviceConflictException] — el llamador debe mostrar ese mensaje.
  Future<void> signIn({required String email, required String password}) async {
    await _withPendingClaim(() async {
      final credential =
          await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _claimDeviceSlot(credential.user!.uid);
    });
  }

  /// Registra una cuenta nueva (mismo control de dispositivo que [signIn]:
  /// como el mapa `devices` empieza vacío, siempre entra sin conflicto).
  /// [firstName]/[lastName] se guardan en el mismo documento de
  /// `account_devices` (no en una colección aparte, para no necesitar una
  /// regla de seguridad nueva en Firestore). [privacyPolicyVersion]/
  /// [termsVersion] (ver `lib/legal/`) quedan guardados como prueba de qué
  /// versión de cada documento aceptó la cuenta al registrarse — el
  /// checkbox correspondiente ya se validó en la pantalla de login antes de
  /// llegar acá.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String privacyPolicyVersion,
    required String termsVersion,
  }) async {
    await _withPendingClaim(() async {
      final credential =
          await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _claimDeviceSlot(credential.user!.uid);
      await _devices.doc(credential.user!.uid).set(
        {
          'firstName': firstName,
          'lastName': lastName,
          'consent': {
            'privacyPolicyVersion': privacyPolicyVersion,
            'termsVersion': termsVersion,
            'acceptedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Corre [action] (el `signIn`/`register` de Firebase Auth completo, más
  /// el reclamo del lugar de dispositivo) con [_pendingClaim] ya instalado
  /// *antes* de arrancar — ver el comentario de ese campo sobre por qué el
  /// orden importa. Maneja [DeviceConflictException] igual para ambos
  /// llamadores: deshace el login y relanza.
  Future<void> _withPendingClaim(Future<void> Function() action) async {
    final completer = Completer<void>();
    _pendingClaim = completer.future;
    try {
      await action();
    } on DeviceConflictException {
      await _auth.signOut();
      rethrow;
    } finally {
      completer.complete();
      if (identical(_pendingClaim, completer.future)) _pendingClaim = null;
    }
  }

  Future<void> _claimDeviceSlot(String uid) async {
    if (isRevenueCatSupported) {
      try {
        await Purchases.logIn(uid);
      } catch (_) {
        // Defensivo: no bloquear el login si RevenueCat no responde.
      }
    }
    final deviceLimit = await _computeDeviceLimit();
    final docRef = _devices.doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final devices = Map<String, dynamic>.from(snap.data()?['devices'] as Map? ?? {});
      // Volver a entrar desde el mismo dispositivo no debe contar contra
      // el límite: se saca (si estaba) y se vuelve a agregar más abajo.
      devices.remove(_thisDeviceId);
      if (devices.length >= deviceLimit) {
        throw DeviceConflictException(deviceLimit);
      }
      tx.set(
        docRef,
        {
          'devices': {
            ...devices,
            _thisDeviceId: {
              'label': _thisDeviceLabel,
              'loggedInAt': FieldValue.serverTimestamp(),
            },
          },
        },
      );
    });
  }

  /// Cantidad de dispositivos que permite el plan activo de esta cuenta.
  /// Cualquier error (offline, RevenueCat inalcanzable) o Windows cae en 1
  /// — nunca confía en un número más alto sin poder verificarlo.
  Future<int> _computeDeviceLimit() async {
    if (!isRevenueCatSupported) return 1;
    try {
      final info = await Purchases.getCustomerInfo();
      return deviceLimitFromActiveSubscriptions(info.activeSubscriptions);
    } catch (_) {
      return 1;
    }
  }

  /// Libera el dispositivo (para que otro pueda loguearse con esta cuenta)
  /// y cierra la sesión local.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _devices.doc(uid).update({'devices.$_thisDeviceId': FieldValue.delete()});
    }
    if (isRevenueCatSupported) {
      try {
        await Purchases.logOut();
      } catch (_) {
        // Defensivo: no bloquear el signOut si RevenueCat no responde.
      }
    }
    await _auth.signOut();
  }

  /// Envía el email de Firebase Auth para restablecer la contraseña de
  /// [email]. No hace falta estar logueado. Si el proyecto de Firebase tiene
  /// activa la protección contra enumeración de emails, esto no falla aunque
  /// el email no esté registrado (comportamiento normal de Firebase, no un
  /// bug); si no la tiene activa, puede lanzar `user-not-found`.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Revalida que este dispositivo siga teniendo un lugar reservado (por
  /// si se liberó desde otro lado mientras esta app estaba abierta). Si ya
  /// no está, cierra la sesión local sin tocar el documento (no es "este"
  /// dispositivo el que hay que sacar). No expulsa a nadie por un cambio
  /// de plan que baje el límite — sólo bloquea reclamos *nuevos*.
  Future<bool> revalidateThisDevice() async {
    final pending = _pendingClaim;
    if (pending != null) {
      // Siempre se resuelve sin error (ver `_withPendingClaim`), incluso si
      // el intento de `signIn`/`register` terminó fallando: esta espera es
      // sólo para no leer Firestore mientras ese intento todavía está en
      // curso, no para conocer su resultado.
      await pending;
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) return true;
    final snap = await _devices.doc(uid).get();
    final devices = Map<String, dynamic>.from(snap.data()?['devices'] as Map? ?? {});
    if (!devices.containsKey(_thisDeviceId)) {
      await _auth.signOut();
      return false;
    }
    return true;
  }

  /// Elimina la cuenta actual de forma permanente: el usuario de Firebase
  /// Auth y el documento `account_devices/{uid}` (dispositivos, nombre y
  /// consentimiento). No toca los datos locales de equipos/partidos/pizarra
  /// en Hive: no están asociados a la cuenta (ver `StorageService`), así que
  /// siguen disponibles en este dispositivo aunque la cuenta se borre.
  ///
  /// Firebase exige una sesión reciente para operaciones sensibles como
  /// borrar el usuario, así que primero se reautentica con [password]; eso
  /// puede lanzar `FirebaseAuthException` (`wrong-password`,
  /// `invalid-credential`) si la contraseña no es correcta.
  ///
  /// El documento de Firestore se borra *antes* que el usuario de Auth (no
  /// después): las reglas de seguridad exigen seguir autenticado como esa
  /// cuenta para poder borrar su propio documento.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await _devices.doc(user.uid).delete();
    if (isRevenueCatSupported) {
      try {
        await Purchases.logOut();
      } catch (_) {
        // Defensivo: no bloquear el borrado de cuenta si RevenueCat no responde.
      }
    }
    await user.delete();
  }
}
