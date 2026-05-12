/// Mop-up tests for the small residuals across `lib/kernel/src/theme/`:
/// ClideTheme.of / .controllerOf inherited-widget lookups, the alpha
/// path in _composite, ContrastFailure.toString, ThemeLoader's
/// non-map / fromFile paths, and the Palette.names / SemanticRoles.roles
/// getters.
library;

import 'dart:io';
import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/theme/contrast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClideTheme inherited-widget lookups', () {
    testWidgets('of() returns the current theme data when wrapped', (tester) async {
      final controller = ThemeController(
        bundled: [
          ThemeDefinition(
            name: 't',
            displayName: 't',
            dark: true,
            palette: Palette(const {
              'primary': Color(0xFF000000),
              'foreground': Color(0xFFFFFFFF),
              'background': Color(0xFF000000),
              'surface': Color(0xFF111111),
              'panel': Color(0xFF222222),
              'accent': Color(0xFFFF00FF),
              'success': Color(0xFF00FF00),
              'warning': Color(0xFFFFFF00),
              'error': Color(0xFFFF0000),
            }),
          ),
        ],
        initialName: 't',
      );
      addTearDown(controller.dispose);
      late ClideThemeData captured;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ClideTheme(
          controller: controller,
          child: Builder(builder: (ctx) {
            captured = ClideTheme.of(ctx);
            return const SizedBox();
          }),
        ),
      ));
      expect(captured, isNotNull);
    });

    testWidgets('of() throws when no ClideTheme ancestor', (tester) async {
      late Object captured;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (ctx) {
          try {
            ClideTheme.of(ctx);
          } catch (e) {
            captured = e;
          }
          return const SizedBox();
        }),
      ));
      expect(captured, isA<FlutterError>());
    });

    testWidgets('controllerOf() returns the wrapped controller', (tester) async {
      final controller = ThemeController(
        bundled: [
          ThemeDefinition(
            name: 't',
            displayName: 't',
            dark: true,
            palette: Palette(const {
              'primary': Color(0xFF000000),
              'foreground': Color(0xFFFFFFFF),
              'background': Color(0xFF000000),
              'surface': Color(0xFF111111),
              'panel': Color(0xFF222222),
              'accent': Color(0xFFFF00FF),
              'success': Color(0xFF00FF00),
              'warning': Color(0xFFFFFF00),
              'error': Color(0xFFFF0000),
            }),
          ),
        ],
        initialName: 't',
      );
      addTearDown(controller.dispose);
      late ThemeController captured;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ClideTheme(
          controller: controller,
          child: Builder(builder: (ctx) {
            captured = ClideTheme.controllerOf(ctx);
            return const SizedBox();
          }),
        ),
      ));
      expect(captured, same(controller));
    });

    testWidgets('controllerOf() throws when no ClideTheme ancestor', (tester) async {
      late Object captured;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (ctx) {
          try {
            ClideTheme.controllerOf(ctx);
          } catch (e) {
            captured = e;
          }
          return const SizedBox();
        }),
      ));
      expect(captured, isA<FlutterError>());
    });
  });

  group('contrast tail paths', () {
    test('contrastRatio composites partially-transparent colours onto the neutral grey', () {
      // alpha < 0.999 → _composite mix branch.
      const semiRed = Color.from(alpha: 0.5, red: 1.0, green: 0.0, blue: 0.0);
      const opaqueBlack = Color(0xFF000000);
      final ratio = contrastRatio(semiRed, opaqueBlack);
      // Mixed-with-grey red on black still produces a finite ratio > 1.
      expect(ratio, greaterThan(1.0));
      expect(ratio, lessThan(21.0));
    });

    test('ContrastFailure.toString embeds the pair name, ratio, and minimum', () {
      const failure = ContrastFailure(
        pair: ContrastPair(
          name: 'global.text_on_background',
          foreground: Color(0xFF888888),
          background: Color(0xFF7F7F7F),
        ),
        ratio: 1.23,
        minimum: 4.5,
      );
      final s = failure.toString();
      expect(s, contains('global.text_on_background'));
      expect(s, contains('1.23'));
      expect(s, contains('4.5'));
    });
  });

  group('ThemeLoader error + file paths', () {
    test('fromYamlString throws when the root is not a map', () {
      expect(
        () => const ThemeLoader().fromYamlString('- this\n- is\n- a list'),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromFile loads the same content as fromYamlString', () async {
      final tmp = await File.fromUri(
        Uri.file('${Directory.systemTemp.path}/clide-theme-${DateTime.now().microsecondsSinceEpoch}.yaml'),
      ).create();
      addTearDown(() async {
        if (tmp.existsSync()) await tmp.delete();
      });
      await tmp.writeAsString('''
name: tmp
palette:
  foreground: "#FFFFFF"
  background: "#000000"
  primary: "#FF00FF"
  accent: "#00FFFF"
  surface: "#111111"
  panel: "#222222"
  success: "#00FF00"
  warning: "#FFFF00"
  error: "#FF0000"
''');
      final def = await const ThemeLoader().fromFile(tmp);
      expect(def.name, 'tmp');
      expect(def.palette.lookup('foreground')?.toARGB32(), 0xFFFFFFFF);
    });
  });

  group('Palette / SemanticRoles iterables', () {
    test('Palette.names yields every registered colour key', () {
      final p = Palette(const {
        'primary': Color(0xFF000000),
        'accent': Color(0xFFFFFFFF),
      });
      expect(p.names, containsAll(['primary', 'accent']));
    });

    test('SemanticRoles.roles yields every registered role key', () {
      final s = SemanticRoles(const {
        'text': Color(0xFFFFFFFF),
        'background': Color(0xFF000000),
      });
      expect(s.roles, containsAll(['text', 'background']));
    });
  });
}
