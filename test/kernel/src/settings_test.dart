import 'dart:io';

import 'package:clide/kernel/kernel.dart';
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
      expect(() => store.get<String>('nothing.here'), throwsA(isA<ArgumentError>()));
      expect(() => store.set('notascope.key', 'v'), throwsA(isA<ArgumentError>()));
    });

    test('app.* scope round-trips via YAML on disk', () async {
      await store.set<String>('app.theme.current', 'summer-night');
      expect(store.get<String>('app.theme.current'), 'summer-night');
      final loaded = SettingsStore(appDir: tmp);
      await loaded.load();
      expect(loaded.get<String>('app.theme.current'), 'summer-night');
      loaded.dispose();
    });

    test('numeric-shaped key segments round-trip unmangled (workspace-hash keys)', () async {
      // FNV workspace-hash suffixes (app.env.pathPrepend.<hash>, the account
      // bindings) can be number-shaped; an unquoted YAML key would reload as
      // an int (leading zero dropped) or a float ('1e…' → Infinity) and
      // silently orphan the stored value.
      await store.set<List<String>>('app.env.pathPrepend.0123456789012345', const ['/opt/go/bin']);
      await store.set<String>('app.claude.account.1e23456789012345', 'work');
      final loaded = SettingsStore(appDir: tmp);
      await loaded.load();
      expect(loaded.get<List<dynamic>>('app.env.pathPrepend.0123456789012345'), ['/opt/go/bin']);
      expect(loaded.get<String>('app.claude.account.1e23456789012345'), 'work');
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
      expect(() => store.set('project.thing', 'x'), throwsA(isA<StateError>()));
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

    test('project-scoped set + get round-trip when projectDir is configured', () async {
      final project = await Directory.systemTemp.createTemp('clide_settings_project_');
      addTearDown(() => project.deleteSync(recursive: true));
      await store.setProjectDir(project);
      await store.set<int>('project.foo.bar', 7);
      expect(store.get<int>('project.foo.bar'), 7);
      // Persisted on disk.
      final file = File('${project.path}/.clide/settings.yaml');
      expect(file.existsSync(), isTrue);
      // Reload sees the value.
      await store.load();
      expect(store.get<int>('project.foo.bar'), 7);
    });

    test('setting a project-scoped key without a project throws StateError', () async {
      expect(() async => store.set<int>('project.unset', 1), throwsA(isA<StateError>()));
    });

    test('ext.* keys default to app scope; project overrides app for the same key', () async {
      await store.set<String>('ext.foo.bar', 'app-value');
      expect(store.get<String>('ext.foo.bar'), 'app-value');
      // With a project open, the project value wins.
      final project = await Directory.systemTemp.createTemp('clide_settings_extp_');
      addTearDown(() => project.deleteSync(recursive: true));
      await store.setProjectDir(project);
      // Inject a project-scoped ext value via the on-disk file (simulating
      // a per-project override).
      final pfile = File('${project.path}/.clide/settings.yaml');
      await pfile.parent.create(recursive: true);
      await pfile.writeAsString('ext:\n  foo:\n    bar: project-value\n');
      await store.load();
      expect(store.get<String>('ext.foo.bar'), 'project-value');
    });

    test('setProjectDir(null) clears the project values', () async {
      final project = await Directory.systemTemp.createTemp('clide_settings_clear_');
      addTearDown(() => project.deleteSync(recursive: true));
      await store.setProjectDir(project);
      await store.set<int>('project.x', 1);
      await store.setProjectDir(null);
      expect(store.get<int>('project.x'), isNull);
    });

    test('YAML emitter handles every scalar / collection branch', () async {
      // Null, list of mixed types, bool, num, string with special chars,
      // empty string, empty map → exercises _emitScalar + _emit.
      await store.set<Object>('app.bool', true);
      await store.set<Object>('app.num', 42);
      await store.set<Object>('app.str.simple', 'hi');
      await store.set<Object>('app.str.special', 'has:colon and # hash');
      await store.set<Object>('app.str.empty', '');
      await store.set<Object>('app.list', [1, 'two', null, false]);
      // Round-trip through reload.
      await store.load();
      expect(store.get<bool>('app.bool'), isTrue);
      expect(store.get<int>('app.num'), 42);
      expect(store.get<String>('app.str.simple'), 'hi');
      expect(store.get<String>('app.str.special'), 'has:colon and # hash');
      expect(store.get<String>('app.str.empty'), '');
      expect(store.get<List>('app.list'), [1, 'two', null, false]);
    });

    test('YAML emitter handles nested lists and empty maps', () async {
      // Nested list — forces _emitScalar's `v is List` recursive branch.
      await store.set<Object>('app.nested', [
        [1, 2],
        ['a', 'b'],
      ]);
      // Empty map under an app.* key — forces _emit's empty-map branch.
      // Use a key whose value is itself a Map.
      await store.set<Object>('app.empty', <String, Object?>{});
      // Round-trip.
      await store.load();
      expect(store.get<List>('app.nested'), [
        [1, 2],
        ['a', 'b'],
      ]);
    });

    test('load tolerates a malformed YAML file', () async {
      // Write garbage to the on-disk app settings, then load.
      final f = File('${tmp.path}/settings.yaml');
      await f.writeAsString(': : : not yaml');
      await store.load();
      // No exception; in-memory store is empty.
      expect(store.get<int>('app.anything'), isNull);
    });

    // T-376: maps nested inside lists were emitted via toString() and
    // corrupted on the next read — breaking the documented keymap overlay.
    test('maps inside lists round-trip across save/load (keymap overlay shape)', () async {
      final overlay = [
        {'keys': 'ctrl+k ctrl+s', 'command': 'keybindings.open'},
        {'keys': 'shift shift', 'command': 'finder.open', 'when': 'editorFocus'},
      ];
      await store.set<Object>('app.keymap.overlay', overlay);
      final loaded = SettingsStore(appDir: tmp);
      addTearDown(loaded.dispose);
      await loaded.load();
      final got = loaded.get<List>('app.keymap.overlay');
      expect(got, hasLength(2));
      expect((got![0] as Map)['keys'], 'ctrl+k ctrl+s');
      expect((got[0] as Map)['command'], 'keybindings.open');
      expect((got[1] as Map)['when'], 'editorFocus');
    });

    test('a parse failure preserves the original file and reports it (T-376)', () async {
      final errors = <String>[];
      final f = File('${tmp.path}/settings.yaml');
      const garbage = 'app:\n  broken: [unclosed\n'; // genuinely invalid YAML
      await f.writeAsString(garbage);
      final reporting = SettingsStore(appDir: tmp, onError: errors.add);
      addTearDown(reporting.dispose);
      await reporting.load();
      expect(errors, hasLength(1));
      expect(errors.single, contains('.broken'));
      expect(File('${f.path}.broken').readAsStringSync(), garbage, reason: 'the broken original is preserved for recovery');
    });

    test('writes are atomic — no .tmp residue, content lands whole', () async {
      await store.set<String>('app.k', 'v');
      expect(File('${tmp.path}/settings.yaml.tmp').existsSync(), isFalse);
      expect(File('${tmp.path}/settings.yaml').readAsStringSync(), contains('k: v'));
    });

    test('load returns empty when the settings file is blank or missing', () async {
      // File missing → empty.
      final f = File('${tmp.path}/settings.yaml');
      if (f.existsSync()) await f.delete();
      await store.load();
      expect(store.get<int>('app.foo'), isNull);
      // Blank file → empty.
      await f.writeAsString('');
      await store.load();
      expect(store.get<int>('app.foo'), isNull);
    });
  });
}
