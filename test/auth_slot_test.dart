// Cuándo la escucha de `account_devices/{uid}` cierra la sesión local
// (AuthService.slotLost). El bug: tras cerrar sesión y volver a entrar, el
// primer snapshot de la escucha venía de la caché (vieja, sin este
// dispositivo) y cerraba la sesión recién abierta; entraba recién al segundo
// intento.

import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/services/auth_service.dart';

void main() {
  const me = 'device-me';
  final withMe = {me: {}, 'otro': {}};
  final withoutMe = {'otro': {}};

  test('una copia en caché nunca cierra la sesión (aunque no incluya este dispositivo)', () {
    expect(AuthService.slotLost(exists: true, fromCache: true, devices: withoutMe, deviceId: me), isFalse);
    expect(AuthService.slotLost(exists: false, fromCache: true, devices: null, deviceId: me), isFalse);
  });

  test('del servidor: documento borrado (cuenta eliminada) o sin este dispositivo cierra la sesión', () {
    expect(AuthService.slotLost(exists: false, fromCache: false, devices: null, deviceId: me), isTrue);
    expect(AuthService.slotLost(exists: true, fromCache: false, devices: withoutMe, deviceId: me), isTrue);
    expect(AuthService.slotLost(exists: true, fromCache: false, devices: null, deviceId: me), isTrue);
  });

  test('del servidor con este dispositivo adentro: la sesión sigue', () {
    expect(AuthService.slotLost(exists: true, fromCache: false, devices: withMe, deviceId: me), isFalse);
  });
}
