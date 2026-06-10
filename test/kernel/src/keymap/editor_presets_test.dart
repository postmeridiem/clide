/// Regression tests for the VS Code (T-64) and JetBrains (T-66) keymap
/// presets: activating each via `KeymapService.setPreset` resolves a
/// representative subset of its bindings as expected. The real shipped
/// `assets/keymaps/*.yaml` files are read from disk and fed through the
/// loader, so a typo in the preset fails here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap_service.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;
  late SettingsStore settings;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('clide_preset_test_');
    settings = SettingsStore(appDir: appDir);
    await settings.load();
  });

  tearDown(() async {
    settings.dispose();
    if (await appDir.exists()) await appDir.delete(recursive: true);
  });

  // Build a service whose bundle serves the real shipped preset content.
  Future<KeymapService> activate(String preset) async {
    final src = File('assets/keymaps/$preset.yaml').readAsStringSync();
    final svc = KeymapService(
      settings: settings,
      appDir: appDir,
      bundle: _bundle({'assets/keymaps/$preset.yaml': src}),
    );
    await svc.setPreset(preset);
    return svc;
  }

  bool isCommand(Intent? i, String id) => i is InvokeCommandIntent && i.commandId == id;

  group('vscode preset (T-64)', () {
    test('setPreset activates it and the representative subset resolves', () async {
      final svc = await activate('vscode');
      expect(settings.get<String>(kKeymapPresetSetting), 'vscode');

      // Acceptance #4: the two canonical chords.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+p'), const {}), isA<QuickOpenIntent>());
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+p'), const {}), isA<PaletteOpenIntent>());
      // F1 also opens the palette in VS Code.
      expect(svc.keymap!.resolve(KeyChord.parse('f1'), const {}), isA<PaletteOpenIntent>());
      // Search + panel toggles.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+f'), const {}), isA<FindInFilesIntent>());
      expect(isCommand(svc.keymap!.resolve(KeyChord.parse('ctrl+b'), const {}), 'sidebar.collapse'), isTrue);
      expect(isCommand(svc.keymap!.resolve(KeyChord.parse('ctrl+j'), const {}), 'dock.toggle'), isTrue);
      expect(isCommand(svc.keymap!.resolve(KeyChord.parse('ctrl+w'), const {}), 'editor.close'), isTrue);
    });

    test('ctrl+p is quick-open only while the palette is closed (when-clause)', () async {
      final svc = await activate('vscode');
      // palette.open → ctrl+p flips to palette.selectPrevious, not quick-open.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+p'), const {'palette.open': true}), isA<PaletteSelectPreviousIntent>());
    });

    test('the Ctrl+K Ctrl+T sequence binds the theme picker', () async {
      final svc = await activate('vscode');
      final hit = svc.keymap!.effectiveBindings.any((b) =>
          b.sequence.length == 2 &&
          b.sequence[0] == KeyChord.parse('ctrl+k') &&
          b.sequence[1] == KeyChord.parse('ctrl+t') &&
          isCommand(b.intent, 'theme.pick'));
      expect(hit, isTrue);
    });
  });

  group('jetbrains preset (T-66)', () {
    test('setPreset activates it and the representative subset resolves', () async {
      final svc = await activate('jetbrains');
      expect(settings.get<String>(kKeymapPresetSetting), 'jetbrains');

      // Double-Shift "Search Everywhere" is not expressible (T-341); Go to
      // File (Ctrl+Shift+N) is the stand-in for quick-open.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+n'), const {}), isA<QuickOpenIntent>());
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+e'), const {}), isA<QuickOpenIntent>());
      // Find Action → command palette.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+a'), const {}), isA<PaletteOpenIntent>());
      // Find in Path; tool windows.
      expect(svc.keymap!.resolve(KeyChord.parse('ctrl+shift+f'), const {}), isA<FindInFilesIntent>());
      expect(isCommand(svc.keymap!.resolve(KeyChord.parse('alt+1'), const {}), 'sidebar.collapse'), isTrue);
      expect(isCommand(svc.keymap!.resolve(KeyChord.parse('alt+f12'), const {}), 'dock.toggle'), isTrue);
    });
  });
}

/// In-memory AssetBundle that serves whatever the constructor map says.
AssetBundle _bundle(Map<String, String> files) => _MapBundle(files);

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._files);
  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final s = _files[key];
    if (s == null) throw Exception('asset not in fake bundle: $key');
    // utf8 (not codeUnits) so non-ASCII in preset comments survives — the real
    // rootBundle serves utf8 bytes.
    return ByteData.view(Uint8List.fromList(utf8.encode(s)).buffer);
  }
}
