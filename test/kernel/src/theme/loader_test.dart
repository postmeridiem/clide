import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const loader = ThemeLoader();

  group('ThemeLoader.fromYamlString', () {
    test('parses palette-only theme', () {
      final def = loader.fromYamlString('''
name: summer-night
display_name: Summer Night
dark: true
palette:
  primary: "#00a3d2"
  background: "#21262F"
  foreground: "#E2E8F5"
''');
      expect(def.name, 'summer-night');
      expect(def.displayName, 'Summer Night');
      expect(def.dark, true);
      expect(def.palette.lookup('primary'), const Color(0xFF00A3D2));
      expect(def.semanticOverride, isNull);
      expect(def.surfaceOverride, isNull);
    });

    test('captures semantic overrides as palette-resolved colors', () {
      final def = loader.fromYamlString('''
name: t
palette:
  red: "#FF0000"
  blue: "#0000FF"
semantic:
  mainchrome: red
  focus: "#123456"
''');
      expect(def.semanticOverride!.lookup('mainchrome'), const Color(0xFFFF0000));
      expect(def.semanticOverride!.lookup('focus'), const Color(0xFF123456));
    });

    test('captures surface overrides as ref strings', () {
      final def = loader.fromYamlString('''
name: t
palette:
  red: "#FF0000"
surface:
  panel.background: "semantic.mainchrome"
  panel.border: red
''');
      expect(def.surfaceOverride, {
        'panel.background': 'semantic.mainchrome',
        'panel.border': 'red',
      });
    });

    test('throws when name is missing and no fallback', () {
      expect(
        () => loader.fromYamlString('palette: { fg: "#fff" }'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when palette is missing', () {
      expect(
        () => loader.fromYamlString('name: t'),
        throwsA(isA<FormatException>()),
      );
    });

    test('fallback name is used when name is absent', () {
      final def = loader.fromYamlString(
        'palette: { fg: "#fff" }',
        fallbackName: 'inferred',
      );
      expect(def.name, 'inferred');
    });
  });
}
