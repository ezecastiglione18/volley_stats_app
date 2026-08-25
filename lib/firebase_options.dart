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
    apiKey: 'AIzaSyBeG0qH8_Ds1Q2egcE_B8wZJwPw6ahUy8Y',
    appId: '1:1082356934892:web:be539c436db9b9a1299dc9',
    messagingSenderId: '1082356934892',
    projectId: 'volleystatsapp-be835',
    authDomain: 'volleystatsapp-be835.firebaseapp.com',
    storageBucket: 'volleystatsapp-be835.firebasestorage.app',
    measurementId: 'G-37J8MN2B61',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXdkxD4aO-VTBSE-WO0wIQF_c7CJSNm5M',
    appId: '1:1082356934892:android:4be0af08001aec8c299dc9',
    messagingSenderId: '1082356934892',
    projectId: 'volleystatsapp-be835',
    storageBucket: 'volleystatsapp-be835.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR',
    appId: 'REEMPLAZAR',
    messagingSenderId: 'REEMPLAZAR',
    projectId: 'REEMPLAZAR',
    iosBundleId: 'REEMPLAZAR',
  );

  // Firebase no tiene un tipo de app nativo para Windows: se usa la config
  // de la app Web (mismo proyecto), que es lo que recomienda el equipo de
  // FlutterFire para desktop.
  static const FirebaseOptions windows = web;
}
