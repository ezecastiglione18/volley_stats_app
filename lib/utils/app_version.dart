/// Versión de la app tal como figura en `version:` de `pubspec.yaml` (con el
/// número de build). Se escribe a mano para no sumar un plugin nativo
/// (`package_info_plus`) solo para esto; `test/app_version_test.dart` falla
/// si deja de coincidir con `pubspec.yaml`, así que al subir la versión en
/// un release hay que actualizarla acá también.
const kAppVersion = '1.4.0+19';
