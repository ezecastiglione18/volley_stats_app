# Setup de Firebase — login + control de dispositivo único

Este documento son los pasos que tenés que hacer vos manualmente (requieren
tu cuenta de Google) para que funcione el login y el bloqueo de "una cuenta,
un dispositivo a la vez" (issue #10). El código de la app (`lib/services/
auth_service.dart`, `lib/screens/auth/login_screen.dart`, el gate en
`lib/main.dart`) ya está listo y espera esta configuración.

## 1. Crear el proyecto de Firebase

1. Entrá a https://console.firebase.google.com y creá un proyecto nuevo
   (por ejemplo `rallystats`).
2. Dentro del proyecto, andá a **Build → Authentication → Get started** y
   activá el proveedor **Email/Password**.
3. Andá a **Build → Firestore Database → Create database**. Elegí modo
   **producción** (las reglas de seguridad están más abajo, en el paso 3)
   y la región que te quede más cerca.

## 2. Generar `lib/firebase_options.dart`

1. Instalá la Firebase CLI si no la tenés: `npm install -g firebase-tools`
   y logueate con `firebase login`.
2. Instalá FlutterFire CLI: `dart pub global activate flutterfire_cli`.
3. Desde la raíz del repo, corré:
   ```bash
   flutterfire configure
   ```
   Elegí el proyecto que creaste en el paso 1, y las plataformas que uses
   (Android + Windows como mínimo, según lo que dice `CLAUDE.md` sobre cómo
   se distribuye la app).
4. Esto sobreescribe `lib/firebase_options.dart` (el que está en el repo
   ahora es un placeholder con valores `'REEMPLAZAR'`) con los datos reales
   del proyecto, y en Android agrega `android/app/google-services.json`.

## 3. Reglas de seguridad de Firestore

La colección que usa `AuthService` es `account_devices`, con un documento
por usuario (id = uid de Firebase Auth) guardando qué `deviceId` tiene la
sesión tomada. Cada usuario solo necesita poder leer/escribir **su propio**
documento. En **Firestore Database → Rules**, pegar:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /account_devices/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 4. Crear las cuentas

No hace falta un panel de administración: cada entrenador/comprador puede
crear su propia cuenta desde la pantalla de login de la app ("¿No tenés
cuenta? Crear una"). Si preferís controlar vos qué cuentas existen, se
pueden dar de alta a mano desde **Authentication → Users → Add user** en la
consola de Firebase en vez de dejar que se registren solos.

## 5. Verificar

Con la configuración lista, `flutter pub get` y correr la app: debería
aparecer la pantalla de login en vez de "Falta configurar Firebase". Si
intentás loguear la misma cuenta en un segundo dispositivo mientras el
primero sigue con la sesión abierta, el segundo tiene que rechazar el
login con el mensaje "Esta cuenta ya está en uso en otro dispositivo...".
Cerrando sesión en el primero (botón de logout en Inicio) libera la cuenta
para que el segundo pueda entrar.
