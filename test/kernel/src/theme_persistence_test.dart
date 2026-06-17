import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/theme/theme_persistence.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

ThemeDefinition _def(String name) => ThemeDefinition(
  name: name,
  displayName: name,
  dark: true,
  palette: Palette(const {
    'primary': Color(0xFF00A3D2),
    'accent': Color(0xFFFA5F8B),
    'background': Color(0xFF21262F),
    'surface': Color(0xFF393E48),
    'panel': Color(0xFF292E38),
    'foreground': Color(0xFFE2E8F5),
    'success': Color(0xFF00AB9A),
    'warning': Color(0xFFD08447),
    'error': Color(0xFFF06C6F),
  }),
);

void main() {
  group('wireThemePersistence (T-293)', () {
    late Directory appTmp;
    late Directory repoTmp;
    late SettingsStore settings;
    late ThemeController theme;

    setUp(() async {
      appTmp = await Directory.systemTemp.createTemp('clide_theme_app_');
      repoTmp = await Directory.systemTemp.createTemp('clide_theme_repo_');
      settings = SettingsStore(appDir: appTmp);
      await settings.load();
      theme = ThemeController(bundled: [_def('summer-night'), _def('forest'), _def('paper'), _def('paper-hc')]);
      wireThemePersistence(theme, settings);
    });

    tearDown(() async {
      await pumpEventQueue(); // let in-flight writes settle (dispose then no-ops any straggler)
      settings.dispose();
      theme.dispose();
      for (final d in [appTmp, repoTmp]) {
        if (await d.exists()) {
          try {
            await d.delete(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('selecting with no repo open persists app.theme (global default)', () async {
      theme.select('forest');
      expect(settings.get<String>('app.theme'), 'forest');
      expect(settings.get<String>('project.theme'), isNull);
    });

    test('selecting with a repo open persists project.theme into that repo', () async {
      await settings.setProjectDir(repoTmp);
      theme.select('forest');
      expect(settings.get<String>('project.theme'), 'forest');
      // The on-disk write is fire-and-forget; poll for it instead of assuming a
      // single event-queue drain flushes the real I/O (flaked under load).
      final file = File('${repoTmp.path}/.clide/settings.yaml');
      for (var i = 0; i < 100 && !file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(file.existsSync(), isTrue);
    });

    test('the high-contrast variant persists (the name encodes -hc)', () async {
      theme.select('paper-hc');
      expect(settings.get<String>('app.theme'), 'paper-hc');
    });

    test('opening a repo restores project.theme over the global app.theme', () async {
      await settings.set<String>('app.theme', 'forest');
      await File('${repoTmp.path}/.clide/settings.yaml').create(recursive: true);
      await File('${repoTmp.path}/.clide/settings.yaml').writeAsString('project:\n  theme: paper\n');

      await settings.setProjectDir(repoTmp); // loads project values + notifies → restore

      expect(theme.currentName, 'paper');
    });

    test('restores the global app.theme at wiring time (boot)', () async {
      await File('${appTmp.path}/settings.yaml').writeAsString('app:\n  theme: forest\n');
      final s2 = SettingsStore(appDir: appTmp);
      await s2.load();
      final t2 = ThemeController(bundled: [_def('summer-night'), _def('forest')]);
      expect(t2.currentName, 'summer-night'); // bundled.first before wiring

      wireThemePersistence(t2, s2);

      expect(t2.currentName, 'forest'); // restored from app.theme
      s2.dispose();
      t2.dispose();
    });

    test('an unknown saved theme is ignored (no throw, keeps current)', () async {
      await File('${repoTmp.path}/.clide/settings.yaml').create(recursive: true);
      await File('${repoTmp.path}/.clide/settings.yaml').writeAsString('project:\n  theme: gone-theme\n');

      await settings.setProjectDir(repoTmp);

      expect(theme.currentName, 'summer-night'); // unchanged
    });
  });
}
