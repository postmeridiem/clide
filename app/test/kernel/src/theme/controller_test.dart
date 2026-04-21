import 'dart:ui';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeDefinition _def(String name, Color primary) => ThemeDefinition(
      name: name,
      displayName: name,
      dark: true,
      palette: Palette({
        'primary': primary,
        'accent': primary,
        'background': const Color(0xFF000000),
        'surface': const Color(0xFF111111),
        'panel': const Color(0xFF222222),
        'foreground': const Color(0xFFFFFFFF),
        'success': const Color(0xFF00FF00),
        'warning': const Color(0xFFFFFF00),
        'error': const Color(0xFFFF0000),
      }),
    );

void main() {
  group('ThemeController', () {
    test('starts on first bundled theme', () {
      final c = ThemeController(bundled: [
        _def('a', const Color(0xFF111111)),
        _def('b', const Color(0xFF222222)),
      ]);
      expect(c.currentName, 'a');
    });

    test('honors initialName when present', () {
      final c = ThemeController(
        bundled: [
          _def('a', const Color(0xFF000000)),
          _def('b', const Color(0xFF999999))
        ],
        initialName: 'b',
      );
      expect(c.currentName, 'b');
    });

    test('silently falls back to first when initialName is unknown', () {
      final c = ThemeController(
        bundled: [_def('a', const Color(0xFF000000))],
        initialName: 'missing',
      );
      expect(c.currentName, 'a');
    });

    test('select changes current + notifies listeners', () {
      final c = ThemeController(bundled: [
        _def('a', const Color(0xFF000000)),
        _def('b', const Color(0xFF333333)),
      ]);
      var count = 0;
      c.addListener(() => count++);
      c.select('b');
      expect(c.currentName, 'b');
      expect(count, 1);
    });

    test('select on same theme is a no-op', () {
      final c = ThemeController(bundled: [_def('a', const Color(0xFF000000))]);
      var count = 0;
      c.addListener(() => count++);
      c.select('a');
      expect(count, 0);
    });

    test('select throws on unknown name', () {
      final c = ThemeController(bundled: [_def('a', const Color(0xFF000000))]);
      expect(() => c.select('nope'), throwsA(isA<ArgumentError>()));
    });

    test('registerTheme adds a new theme and rebuilds current if matching', () {
      final c = ThemeController(bundled: [_def('a', const Color(0xFFAAAAAA))]);
      expect(c.available.length, 1);
      c.registerTheme(_def('b', const Color(0xFFBBBBBB)));
      expect(c.available.length, 2);
      // re-register 'a' with a different palette — current rebuilds
      var count = 0;
      c.addListener(() => count++);
      c.registerTheme(_def('a', const Color(0xFF123456)));
      expect(count, 1);
    });
  });
}
