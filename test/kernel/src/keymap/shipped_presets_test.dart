/// Guard: every preset we ship under `assets/keymaps/` must parse
/// through the real loader.
///
/// T-204 — `default.yaml` bound `tab`/`shift+tab` to `focus.next` /
/// `focus.previous`, intent ids that didn't exist in [builtinIntents].
/// `KeymapLayer.fromYaml` throws on an unknown id, and `KeymapService.load`
/// catches that and silently sets `_preset = null` — so the ENTIRE default
/// keymap was dead at runtime (palette, quick-open, find-in-files, scale).
/// It slipped through because every `keymap_service_test` injects a
/// synthetic bundle; the shipped asset was never parsed in a test.
///
/// This test reads the real files from disk and parses them, so a typo in
/// any shipped preset fails CI instead of silently disabling the keymap.
library;

import 'dart:io';

import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/keymap.dart';
import 'package:flutter/widgets.dart' show NextFocusIntent, PreviousFocusIntent;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('assets/keymaps');
  final presets = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.yaml')).toList()..sort((a, b) => a.path.compareTo(b.path));

  test('assets/keymaps ships at least the default preset', () {
    expect(presets.map((f) => f.uri.pathSegments.last), contains('default.yaml'));
  });

  for (final file in presets) {
    final name = file.uri.pathSegments.last;
    test('$name parses through the real loader', () {
      final layer = KeymapLayer.fromYaml(file.readAsStringSync());
      // A preset that produced zero bindings would mean every entry was
      // dropped — almost certainly a schema mistake, not an intentional
      // empty file.
      expect(layer.bindings, isNotEmpty, reason: '$name produced no bindings');
    });
  }

  test('focus.next / focus.previous are real intent ids', () {
    expect(parseIntentId('focus.next'), isA<NextFocusIntent>());
    expect(parseIntentId('focus.previous'), isA<PreviousFocusIntent>());
  });

  test('default.yaml binds Tab / Shift+Tab to focus traversal', () {
    final layer = KeymapLayer.fromYaml(File('assets/keymaps/default.yaml').readAsStringSync());
    expect(layer.bindings.any((b) => b.intent is NextFocusIntent), isTrue);
    expect(layer.bindings.any((b) => b.intent is PreviousFocusIntent), isTrue);
  });

  // Every shipped preset aliases the double-Shift "Search Everywhere"
  // gesture to quick-open (T-341).
  final doubleShift = [KeyChord.bareModifier(KeyModifier.shift), KeyChord.bareModifier(KeyModifier.shift)];
  for (final file in presets) {
    final name = file.uri.pathSegments.last;
    test('$name resolves `shift shift` (double-tap) to quick-open', () {
      final km = Keymap([KeymapLayer.fromYaml(file.readAsStringSync())]);
      final m = km.match(doubleShift, const {});
      expect(m.exact, isA<QuickOpenIntent>(), reason: '$name should bind double-Shift to quickOpen.open');
    });
  }
}
