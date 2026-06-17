import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory appDir;
  late Directory projDir;
  late SettingsStore store;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('clide_app_');
    projDir = await Directory.systemTemp.createTemp('clide_proj_');
    store = SettingsStore(appDir: appDir, projectDir: projDir);
    await store.load();
  });

  tearDown(() async {
    store.dispose();
    await appDir.delete(recursive: true);
    await projDir.delete(recursive: true);
  });

  group('SettingsStore scope-explicit access (T-449)', () {
    test('writableLayers honours the key prefix', () {
      expect(store.writableLayers('app.x'), [SettingsScope.app]);
      expect(store.writableLayers('project.x'), [SettingsScope.project]);
      expect(store.writableLayers('ext.x'), [SettingsScope.project, SettingsScope.app]);
    });

    test('ext.* value: project overrides app, and effectiveLayer tracks it', () async {
      await store.setAt(SettingsScope.app, 'ext.k', 'a');
      expect(store.rawAt(SettingsScope.app, 'ext.k'), 'a');
      expect(store.effectiveLayer('ext.k'), SettingsScope.app);
      expect(store.get<String>('ext.k'), 'a');

      await store.setAt(SettingsScope.project, 'ext.k', 'p');
      expect(store.effectiveLayer('ext.k'), SettingsScope.project);
      expect(store.get<String>('ext.k'), 'p');

      await store.removeAt(SettingsScope.project, 'ext.k');
      expect(store.effectiveLayer('ext.k'), SettingsScope.app);
      expect(store.get<String>('ext.k'), 'a');

      await store.removeAt(SettingsScope.app, 'ext.k');
      expect(store.effectiveLayer('ext.k'), isNull);
      expect(store.get<String>('ext.k'), isNull);
    });

    test('writes survive a reload from disk', () async {
      await store.setAt(SettingsScope.project, 'ext.k', 'p');
      await store.setAt(SettingsScope.app, 'app.y', 1);
      await store.load();
      expect(store.rawAt(SettingsScope.project, 'ext.k'), 'p');
      expect(store.get<int>('app.y'), 1);
    });

    test('setAt(project) with no project open throws', () async {
      final noProj = SettingsStore(appDir: appDir);
      await noProj.load();
      expect(() => noProj.setAt(SettingsScope.project, 'project.x', 1), throwsStateError);
      noProj.dispose();
    });

    test('ext is a key class, not a storage layer', () {
      expect(() => store.setAt(SettingsScope.ext, 'ext.k', 1), throwsArgumentError);
      expect(() => store.removeAt(SettingsScope.ext, 'ext.k'), throwsArgumentError);
      expect(store.rawAt(SettingsScope.ext, 'ext.k'), isNull);
    });
  });
}
