import 'dart:io';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsStore', () {
    late Directory tmp;
    late SettingsStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('clide_settings_');
      store = SettingsStore(appDir: tmp);
      await store.load();
    });

    tearDown(() async {
      store.dispose();
      if (await tmp.exists()) {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('scope key validation — rejects non-standard prefixes', () async {
      expect(
        () => store.get<String>('nothing.here'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.set('notascope.key', 'v'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('app.* scope round-trips via YAML on disk', () async {
      await store.set<String>('app.theme.current', 'summer-night');
      expect(store.get<String>('app.theme.current'), 'summer-night');
      final loaded = SettingsStore(appDir: tmp);
      await loaded.load();
      expect(loaded.get<String>('app.theme.current'), 'summer-night');
      loaded.dispose();
    });

    test('app.* scope supports bool + int + list', () async {
      await store.set<bool>('app.extensions.git.enabled', false);
      await store.set<int>('app.layout.width', 240);
      await store.set<List<String>>('app.recent', const ['/a', '/b']);
      final loaded = SettingsStore(appDir: tmp);
      await loaded.load();
      expect(loaded.get<bool>('app.extensions.git.enabled'), false);
      expect(loaded.get<int>('app.layout.width'), 240);
      expect(loaded.get<List<dynamic>>('app.recent'), ['/a', '/b']);
      loaded.dispose();
    });

    test('setting a project.* key without an open project throws', () async {
      expect(
        () => store.set('project.thing', 'x'),
        throwsA(isA<StateError>()),
      );
    });

    test('project scope is isolated from app scope', () async {
      final projectDir = await Directory.systemTemp.createTemp('clide_proj_');
      try {
        await store.setProjectDir(projectDir);
        await store.set<String>('app.global', 'A');
        await store.set<String>('project.scoped', 'P');
        expect(store.get<String>('app.global'), 'A');
        expect(store.get<String>('project.scoped'), 'P');
        // Reload project dir (simulate reopening) and confirm app values
        // don't leak into project store.
        await store.setProjectDir(null);
        expect(store.get<String>('app.global'), 'A');
        expect(store.get<String>('project.scoped'), isNull);
        await store.setProjectDir(projectDir);
        expect(store.get<String>('project.scoped'), 'P');
      } finally {
        try {
          await projectDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('notifyListeners fires on set and load', () async {
      var count = 0;
      store.addListener(() => count++);
      await store.set<String>('app.k', 'v');
      expect(count, greaterThanOrEqualTo(1));
    });
  });
}
