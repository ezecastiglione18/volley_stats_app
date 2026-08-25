// GENERADO A MANO COMO PLACEHOLDER — reemplazar por el archivo real.
//
// Este archivo normalmente lo genera automáticamente la herramienta
// `flutterfire configure` (paquete `flutterfire_cli`) después de crear el
// proyecto en https://console.firebase.google.com y activar Authentication
// (Email/Password) + Firestore. Ver `SETUP_FIREBASE.md` en la raíz del
// repo para los pasos completos.
//
// Hasta que no se reemplace con los valores reales del proyecto de
// Firebase, `Firebase.initializeApp` en `main.dart` va a fallar (se
// captura ese error y se muestra una pantalla avisando que falta
// configurar, en vez de romper el resto de la app).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REEMPLAZAR',
    appId: 'REEMPLAZAR',
    messagingSenderId: 'REEMPLAZAR',
    projectId: 'REEMPLAZAR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REEMPLAZAR',
    appId: 'REEMPLAZAR',
    messagingSenderId: 'REEMPLAZAR',
    projectId: 'REEMPLAZAR',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR',
    appId: 'REEMPLAZAR',
    messagingSenderId: 'REEMPLAZAR',
    projectId: 'REEMPLAZAR',
    iosBundleId: 'REEMPLAZAR',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REEMPLAZAR',
    appId: 'REEMPLAZAR',
    messagingSenderId: 'REEMPLAZAR',
    projectId: 'REEMPLAZAR',
  );
}
