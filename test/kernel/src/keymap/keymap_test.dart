/// Unit tests for Keymap layering + resolution + KeymapLayer YAML parsing.
library;

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap.dart';
import 'package:flutter/widgets.dart' show ActivateIntent, DismissIntent;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeymapLayer.fromYaml', () {
    test('parses a single binding with one chord', () {
      const src = '''
name: test
bindings:
  - intent: activate
    keys: enter
''';
      final layer = KeymapLayer.fromYaml(src);
      expect(layer.name, 'test');
      expect(layer.bindings, hasLength(1));
      expect(layer.bindings.single.chord, KeyChord.parse('enter'));
      expect(layer.bindings.single.intent, isA<ActivateIntent>());
      expect(layer.bindings.single.when, isNull);
    });

    test('expands `keys:` list into one binding per chord', () {
      const src = '''
name: t
bindings:
  - intent: activate
    keys: [enter, space]
''';
      final layer = KeymapLayer.fromYaml(src);
      expect(layer.bindings, hasLength(2));
      expect(layer.bindings[0].chord, KeyChord.parse('enter'));
      expect(layer.bindings[1].chord, KeyChord.parse('space'));
      // Same intent instance reused — fine because intents are const.
      expect(layer.bindings[0].intent, isA<ActivateIntent>());
    });

    test('stores when-clause parsed into an evaluable WhenExpr', () {
      const src = '''
name: t
bindings:
  - intent: palette.selectNext
    keys: down
    when: palette.open && !textInputFocused
''';
      final layer = KeymapLayer.fromYaml(src);
      final w = layer.bindings.single.when!;
      expect(w.evaluate({'palette.open': true, 'textInputFocused': false}), isTrue);
      expect(w.evaluate({'palette.open': true, 'textInputFocused': true}), isFalse);
      expect(w.evaluate({'palette.open': false, 'textInputFocused': false}), isFalse);
    });

    test('command: prefix resolves to InvokeCommandIntent', () {
      const src = '''
name: t
bindings:
  - intent: command:git.commit
    keys: ctrl+shift+g
''';
      final layer = KeymapLayer.fromYaml(src);
      final intent = layer.bindings.single.intent;
      expect(intent, isA<InvokeCommandIntent>());
      expect((intent as InvokeCommandIntent).commandId, 'git.commit');
    });

    test('nameOverride wins over `name:`', () {
      const src = 'name: ignored\nbindings: []\n';
      final layer = KeymapLayer.fromYaml(src, nameOverride: 'user-file');
      expect(layer.name, 'user-file');
    });

    test('rejects unknown intent id', () {
      const src = 'name: t\nbindings:\n  - intent: definitely.not.real\n    keys: enter\n';
      expect(() => KeymapLayer.fromYaml(src), throwsFormatException);
    });

    test('rejects missing keys', () {
      const src = 'name: t\nbindings:\n  - intent: activate\n';
      expect(() => KeymapLayer.fromYaml(src), throwsFormatException);
    });

    test('rejects non-map top level', () {
      expect(() => KeymapLayer.fromYaml('- one\n- two\n'), throwsFormatException);
    });

    test('rejects missing bindings list', () {
      expect(() => KeymapLayer.fromYaml('name: t\n'), throwsFormatException);
    });

    test('rejects non-string entries in keys list', () {
      const src = 'name: t\nbindings:\n  - intent: activate\n    keys: [42]\n';
      expect(() => KeymapLayer.fromYaml(src), throwsFormatException);
    });

    test('rejects unparseable keys value (neither string nor list)', () {
      const src = 'name: t\nbindings:\n  - intent: activate\n    keys: {wrong: shape}\n';
      expect(() => KeymapLayer.fromYaml(src), throwsFormatException);
    });
  });

  group('Keymap + KeymapLayer toString', () {
    test('layer toString includes name + binding count', () {
      final layer = KeymapLayer.fromYaml('name: t\nbindings:\n  - intent: dismiss\n    keys: escape\n');
      expect(layer.toString(), 'KeymapLayer(t, 1 binding)');
    });

    test('keymap toString lists layers low-to-high', () {
      final a = KeymapLayer.fromYaml('name: a\nbindings: []\n');
      final b = KeymapLayer.fromYaml('name: b\nbindings: []\n');
      expect(Keymap([a, b]).toString(), 'Keymap(a < b)');
    });
  });

  group('Keymap.resolve — single layer', () {
    final layer = KeymapLayer.fromYaml('''
name: t
bindings:
  - intent: activate
    keys: enter
  - intent: palette.selectNext
    keys: down
    when: palette.open
''');

    test('matches an unconditional binding', () {
      final km = Keymap([layer]);
      expect(km.resolve(KeyChord.parse('enter'), const {}), isA<ActivateIntent>());
    });

    test('matches a when-gated binding when the flag is true', () {
      final km = Keymap([layer]);
      expect(km.resolve(KeyChord.parse('down'), {'palette.open': true}), isA<PaletteSelectNextIntent>());
    });

    test('skips a when-gated binding when the flag is false', () {
      final km = Keymap([layer]);
      expect(km.resolve(KeyChord.parse('down'), const {}), isNull);
    });

    test('returns null when the chord has no binding', () {
      final km = Keymap([layer]);
      expect(km.resolve(KeyChord.parse('ctrl+x'), const {}), isNull);
    });
  });

  group('Keymap.resolve — layering precedence', () {
    test('later layer replaces earlier binding for the same chord', () {
      final preset = KeymapLayer.fromYaml('''
name: preset
bindings:
  - intent: palette.open
    keys: ctrl+shift+p
''');
      final user = KeymapLayer.fromYaml('''
name: user
bindings:
  - intent: activate
    keys: ctrl+shift+p
''');
      final km = Keymap([preset, user]);
      // User layer wins — Activate, not PaletteOpen.
      expect(km.resolve(KeyChord.parse('ctrl+shift+p'), const {}), isA<ActivateIntent>());
    });

    test('preset binding survives when no later layer overrides it', () {
      final preset = KeymapLayer.fromYaml('''
name: preset
bindings:
  - intent: dismiss
    keys: escape
''');
      final user = KeymapLayer.fromYaml('''
name: user
bindings:
  - intent: activate
    keys: enter
''');
      final km = Keymap([preset, user]);
      expect(km.resolve(KeyChord.parse('escape'), const {}), isA<DismissIntent>());
      expect(km.resolve(KeyChord.parse('enter'), const {}), isA<ActivateIntent>());
    });
  });
}
