/// Tests for the KeymapService layering + scope context + resolve.
library;

import 'dart:io';

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap_service.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ActivateIntent, DismissIntent;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;
  late SettingsStore settings;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('clide_keymap_test_');
    settings = SettingsStore(appDir: appDir);
    await settings.load();
  });

  tearDown(() async {
    settings.dispose();
    if (await appDir.exists()) await appDir.delete(recursive: true);
  });

  group('load()', () {
    test('loads the default preset from the asset bundle', () async {
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: dismiss\n    keys: escape\n'}),
      );
      await svc.load();
      expect(svc.keymap, isNotNull);
      expect(svc.keymap!.resolve(KeyChord.parse('escape'), const {}), isA<DismissIntent>());
    });

    test('honours the app.keymap.preset setting', () async {
      await settings.set<String>(kKeymapPresetSetting, 'vscode');
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/vscode.yaml': 'name: vscode\nbindings:\n  - intent: palette.open\n    keys: ctrl+shift+p\n'}),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+p'), const {}), isA<PaletteOpenIntent>());
    });

    test('missing preset asset is tolerated (active keymap is empty)', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle(const {}));
      await svc.load();
      expect(svc.keymap, isNotNull);
      expect(svc.keymap!.effectiveBindings, isEmpty);
    });

    test('layers a user file on top of the preset', () async {
      await File('${appDir.path}/keybindings.yaml').writeAsString('name: user\nbindings:\n  - intent: activate\n    keys: ctrl+p\n');
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: palette.open\n    keys: ctrl+p\n'}),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+p'), const {}), isA<ActivateIntent>());
    });

    test('layers a settings overlay above the user file', () async {
      await File('${appDir.path}/keybindings.yaml').writeAsString('name: user\nbindings:\n  - intent: activate\n    keys: ctrl+p\n');
      await settings.set<List<Object?>>(kKeymapOverridesSetting, [
        {'intent': 'dismiss', 'keys': 'ctrl+p'},
      ]);
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: palette.open\n    keys: ctrl+p\n'}),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+p'), const {}), isA<DismissIntent>());
    });

    test('tolerates a malformed user file by ignoring it', () async {
      await File('${appDir.path}/keybindings.yaml').writeAsString('not: real keymap [yaml');
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: dismiss\n    keys: escape\n'}),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('escape'), const {}), isA<DismissIntent>());
    });

    test('tolerates a malformed settings overlay entry by ignoring just the overlay', () async {
      await settings.set<List<Object?>>(kKeymapOverridesSetting, [
        {'intent': 'definitely.not.real', 'keys': 'ctrl+p'},
      ]);
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: dismiss\n    keys: escape\n'}),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('escape'), const {}), isA<DismissIntent>());
    });
  });

  group('registerCommandBinding / unregisterCommandBindings', () {
    test('adds an InvokeCommandIntent that resolves after load', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.registerCommandBinding('ctrl+shift+g', 'git.commit');
      final intent = svc.keymap!.resolve(KeyChord.parse('ctrl+shift+g'), const {});
      expect(intent, isA<InvokeCommandIntent>());
      final invoke = intent as InvokeCommandIntent;
      expect(invoke.commandId, 'git.commit');
    });

    test('honours a when-clause on the contribution', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.registerCommandBinding('ctrl+s', 'editor.save', when: 'editor.focused');
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+s'), const {}), isNull);
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+s'), {'editor.focused': true}), isA<InvokeCommandIntent>());
    });

    test('user file overrides a contributed binding for the same chord', () async {
      await File('${appDir.path}/keybindings.yaml').writeAsString('name: user\nbindings:\n  - intent: dismiss\n    keys: ctrl+x\n');
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.registerCommandBinding('ctrl+x', 'editor.cut');
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+x'), const {}), isA<DismissIntent>());
    });

    test('unregisterCommandBindings removes prior contributions', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.registerCommandBinding('ctrl+x', 'editor.cut');
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+x'), const {}), isA<InvokeCommandIntent>());
      svc.unregisterCommandBindings('editor.cut');
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+x'), const {}), isNull);
    });

    test('unregister of an unknown command is a no-op', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.unregisterCommandBindings('nothing-registered'); // doesn't throw
    });
  });

  group('scope flags', () {
    test('setScopeFlag updates the context; notifies listeners on change', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      var notified = 0;
      svc.addListener(() => notified++);
      svc.setScopeFlag('palette.open', true);
      expect(svc.scope['palette.open'], isTrue);
      expect(notified, 1);
      svc.setScopeFlag('palette.open', true); // no-op
      expect(notified, 1);
      svc.setScopeFlag('palette.open', false);
      expect(notified, 2);
    });

    test('clearScopeFlag removes the entry; no-op when absent', () async {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings: []\n'}));
      await svc.load();
      svc.setScopeFlag('foo', true);
      svc.clearScopeFlag('foo');
      expect(svc.scope.containsKey('foo'), isFalse);
      svc.clearScopeFlag('foo'); // no-op
    });
  });

  group('setPreset', () {
    test('switches presets and reloads', () async {
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({
          'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: dismiss\n    keys: escape\n',
          'assets/keymaps/vim.yaml': 'name: vim\nbindings:\n  - intent: activate\n    keys: escape\n',
        }),
      );
      await svc.load();
      expect(svc.keymap!.resolve(KeyChord.parse('escape'), const {}), isA<DismissIntent>());
      await svc.setPreset('vim');
      expect(settings.get<String>(kKeymapPresetSetting), 'vim');
      expect(svc.keymap!.resolve(KeyChord.parse('escape'), const {}), isA<ActivateIntent>());
    });
  });

  group('resolveEvent', () {
    test('returns null before load()', () {
      final svc = KeymapService(settings: settings, appDir: appDir, bundle: _bundle(const {}));
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape, timeStamp: Duration.zero);
      expect(svc.resolveEvent(down, HardwareKeyboard.instance), isNull);
    });

    test('returns the bound intent for a matched chord', () async {
      final svc = KeymapService(
        settings: settings,
        appDir: appDir,
        bundle: _bundle({'assets/keymaps/default.yaml': 'name: default\nbindings:\n  - intent: dismiss\n    keys: escape\n'}),
      );
      await svc.load();
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape, timeStamp: Duration.zero);
      expect(svc.resolveEvent(down, HardwareKeyboard.instance), isA<DismissIntent>());
    });
  });
}

/// In-memory AssetBundle that returns whatever the constructor map says.
AssetBundle _bundle(Map<String, String> files) => _MapBundle(files);

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._files);
  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final s = _files[key];
    if (s == null) throw Exception('asset not in fake bundle: $key');
    return ByteData.view(Uint8List.fromList(s.codeUnits).buffer);
  }
}
