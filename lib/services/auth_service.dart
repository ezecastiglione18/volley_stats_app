import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Mensaje del último `DeviceConflictException` que forzó un `signOut()`
  /// dentro de [_withPendingClaim], para que sobreviva a la carrera con
  /// `authStateChanges`: el sign-in de Firebase Auth se completa (dispara el
  /// stream con el usuario) *antes* de que el reclamo del lugar de
  /// dispositivo termine de fallar acá, así que `_AuthGate` ya reemplazó
  /// (desmontó) el `LoginScreen` que originó el intento por el momento en
  /// que este `catch` se resuelve — un `setState` ahí se perdería en
  /// silencio. `LoginScreen` (la instancia nueva que aparece tras el
  /// `signOut` forzado) lo lee en `initState` y lo limpia.
  final ValueNotifier<String?> lastLoginError = ValueNotifier<String?>(null);

  /// Suscripción en vivo a `account_devices/{uid}` mientras hay sesión en
  /// este dispositivo (ver [_watchDeviceSlot]): permite detectar, sin
  /// esperar al próximo arranque, que la cuenta se borró desde otro
  /// dispositivo o que este dispositivo perdió su lugar, y cerrar la sesión
  /// local al toque. [_watchedUid] evita reabrirla si ya está escuchando
  /// al mismo uid (p. ej. `_claimDeviceSlot` y `revalidateThisDevice`
  /// pueden llamarla para el mismo login).
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _deviceDocSub;
  String? _watchedUid;

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
    } on DeviceConflictException catch (e) {
      lastLoginError.value = e.toString();
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
    _watchDeviceSlot(uid);
  }

  /// Empieza (o reutiliza) una escucha en vivo de `account_devices/{uid}`
  /// para este login: si el documento desaparece (cuenta eliminada desde
  /// otro dispositivo) o el mapa `devices` deja de incluir a
  /// [_thisDeviceId] (este dispositivo perdió su lugar), cierra la sesión
  /// local de inmediato, sin esperar a que la app se reabra. Se arranca
  /// tanto después de reclamar el lugar ([_claimDeviceSlot], login/registro
  /// nuevo) como después de revalidarlo ([revalidateThisDevice], sesión ya
  /// persistida al abrir la app), para cubrir ambos puntos de entrada.
  void _watchDeviceSlot(String uid) {
    if (_watchedUid == uid && _deviceDocSub != null) return;
    _stopWatchingDeviceSlot();
    _watchedUid = uid;
    _deviceDocSub = _devices.doc(uid).snapshots().listen((snap) {
      if (!snap.exists) {
        _forceSignOutLocally();
        return;
      }
      final devices = Map<String, dynamic>.from(snap.data()?['devices'] as Map? ?? {});
      if (!devices.containsKey(_thisDeviceId)) {
        _forceSignOutLocally();
      }
    });
  }

  void _stopWatchingDeviceSlot() {
    _deviceDocSub?.cancel();
    _deviceDocSub = null;
    _watchedUid = null;
  }

  /// Cierra la sesión local (Firebase Auth + RevenueCat) sin tocar el
  /// documento de Firestore: usado cuando ya no tiene sentido tocarlo,
  /// porque o bien se borró entero (cuenta eliminada desde otro
  /// dispositivo) o bien este dispositivo ya no figura ahí (lo sacó otro
  /// login). Idempotente: no falla si ya no hay sesión activa.
  Future<void> _forceSignOutLocally() async {
    _stopWatchingDeviceSlot();
    if (_auth.currentUser == null) return;
    if (isRevenueCatSupported) {
      try {
        await Purchases.logOut();
      } catch (_) {
        // Defensivo: no bloquear el signOut si RevenueCat no responde.
      }
    }
    await _auth.signOut();
  }

  /// Cantidad de dispositivos que permite el plan activo de esta cuenta.
  /// Cualquier error (offline, RevenueCat inalcanzable) o Windows cae en 1
  /// — nunca confía en un número más alto sin poder verificarlo. Usado para
  /// *bloquear* un reclamo nuevo ([_claimDeviceSlot]): ahí caer a 1 por las
  /// dudas es lo seguro.
  Future<int> _computeDeviceLimit() async => await _computeConfirmedDeviceLimit() ?? 1;

  /// Como [_computeDeviceLimit], pero devuelve `null` en vez de 1 cuando no
  /// se puede confirmar el límite real (offline, RevenueCat inalcanzable, o
  /// esta build no consulta RevenueCat en absoluto porque no es Android).
  /// Se usa sólo para decidir si *autoexpulsar* un dispositivo por sobrar
  /// respecto del límite ([_evictSelfIfOverLimit]): ahí sí importa no
  /// actuar sobre una duda, al revés que al bloquear un login nuevo. Por
  /// eso, a diferencia de [_computeDeviceLimit], esto NO cae a 1 en
  /// Windows: como ese valor ahí nunca refleja los complementos reales de
  /// la cuenta (Windows no consulta RevenueCat), usarlo para autoexpulsar
  /// podría sacar dispositivos que en realidad sí tienen lugar.
  Future<int?> _computeConfirmedDeviceLimit() async {
    if (!isRevenueCatSupported) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return deviceLimitFromActiveSubscriptions(info.activeSubscriptions);
    } catch (_) {
      return null;
    }
  }

  /// Libera el dispositivo (para que otro pueda loguearse con esta cuenta)
  /// y cierra la sesión local.
  Future<void> signOut() async {
    // Se corta la escucha antes de tocar el documento: si no, el propio
    // listener de este dispositivo reacciona a que se saca a sí mismo del
    // mapa y dispara un `_forceSignOutLocally` innecesario en paralelo.
    _stopWatchingDeviceSlot();
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
  /// si se liberó desde otro lado, o se borró la cuenta entera, mientras
  /// esta app estaba cerrada). Si ya no está, cierra la sesión local sin
  /// tocar el documento (no es "este" dispositivo el que hay que sacar).
  /// Tampoco expulsa a nadie *en el momento* de un cambio de plan que baje
  /// el límite —sigue sin haber ningún mecanismo instantáneo para eso—,
  /// pero si sigue vigente, además de dejar arrancada la escucha en vivo
  /// ([_watchDeviceSlot]) para el resto de la sesión, chequea si la cuenta
  /// quedó con más dispositivos conectados de los que su límite actual
  /// permite y, si a este dispositivo le toca quedar afuera, se
  /// autoexpulsa acá mismo (ver [_evictSelfIfOverLimit]) — así el ajuste se
  /// termina de aplicar la próxima vez que cada dispositivo sobrante abra
  /// la app, en vez de quedar "sobregirado" para siempre.
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
      await _forceSignOutLocally();
      return false;
    }
    if (await _evictSelfIfOverLimit(uid, devices)) {
      return false;
    }
    _watchDeviceSlot(uid);
    return true;
  }

  /// Si la cuenta bajó de plan y hoy tiene más dispositivos con sesión
  /// abierta de los que su límite actual permite, decide si a *este*
  /// dispositivo le toca quedar afuera y, si es así, libera su lugar y
  /// cierra la sesión local. Criterio: sobreviven los [limit] dispositivos
  /// con `loggedInAt` más antiguo — el resto, los conectados más
  /// recientemente, pierden el lugar primero.
  ///
  /// Sólo actúa cuando puede confirmar el límite real contra RevenueCat
  /// ([_computeConfirmedDeviceLimit]): si no puede (offline, o esta build
  /// no usa RevenueCat), no expulsa a nadie por las dudas — se vuelve a
  /// intentar la próxima vez que este dispositivo abra la app. Es por eso
  /// "eventual" y no instantáneo: no hay forma de enterarse en el momento
  /// exacto en que se cancela algo en Play Store (no hay backend
  /// escuchando webhooks de RevenueCat), así que esto sólo se termina de
  /// aplicar cuando cada dispositivo de más vuelve a abrir la app.
  Future<bool> _evictSelfIfOverLimit(String uid, Map<String, dynamic> devices) async {
    final limit = await _computeConfirmedDeviceLimit();
    if (limit == null || devices.length <= limit) return false;

    final ranked = devices.entries.toList()
      ..sort((a, b) => _loggedInAtMillis(a.value).compareTo(_loggedInAtMillis(b.value)));
    final keptIds = ranked.take(limit).map((e) => e.key).toSet();
    if (keptIds.contains(_thisDeviceId)) return false;

    lastLoginError.value =
        'Tu cuenta bajó la cantidad de dispositivos habilitados y este ya no entra dentro del '
        'límite actual, así que se cerró la sesión acá. Volvé a iniciar sesión en un dispositivo '
        'con lugar disponible, o sumá un complemento de dispositivo adicional para recuperarlo.';
    await _devices.doc(uid).update({'devices.$_thisDeviceId': FieldValue.delete()});
    await _forceSignOutLocally();
    return true;
  }

  int _loggedInAtMillis(dynamic deviceEntry) {
    final value = (deviceEntry as Map?)?['loggedInAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
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
  /// cuenta para poder borrar su propio documento. Al desaparecer ese
  /// documento, cualquier otro dispositivo con la sesión abierta en esta
  /// misma cuenta lo nota en el momento por su propia escucha en vivo
  /// ([_watchDeviceSlot]) y cierra sesión ahí también, sin esperar a que se
  /// reabra la app — no hace falta avisarles por separado desde acá.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    // Se corta la escucha propia antes de borrar el documento: si no, este
    // mismo dispositivo reacciona a su propia escucha en vivo y compite con
    // el resto de este método por cerrar la sesión de un `user` que está a
    // punto de borrarse de todos modos.
    _stopWatchingDeviceSlot();
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
