// kAppVersion (va en el "appVersion" de la copia completa) se escribe a mano:
// este test avisa si deja de coincidir con `version:` de pubspec.yaml.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:rally_stats/utils/app_version.dart';

void main() {
  test('kAppVersion coincide con la versión de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    expect(kAppVersion, line.substring('version:'.length).trim());
  });
}
