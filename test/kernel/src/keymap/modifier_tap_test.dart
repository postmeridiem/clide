/// Unit tests for ModifierTapTracker — double-tapped bare-modifier
/// detection (T-341).
library;

import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/modifier_tap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed base instant; offsets are in milliseconds. (Date.now-free so the
  // test is deterministic.)
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('ModifierTapTracker', () {
    test('two taps of the same modifier within the window fire', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(t.tap(KeyModifier.shift, at(0)), isNull); // first tap arms
      expect(t.tap(KeyModifier.shift, at(200)), KeyModifier.shift); // double-tap
    });

    test('the second tap just outside the window does not fire', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(t.tap(KeyModifier.shift, at(0)), isNull);
      expect(t.tap(KeyModifier.shift, at(400)), isNull); // too slow
    });

    test('a slow second tap re-arms, so a prompt third tap fires', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(t.tap(KeyModifier.shift, at(0)), isNull);
      expect(t.tap(KeyModifier.shift, at(500)), isNull); // re-arms from here
      expect(t.tap(KeyModifier.shift, at(600)), KeyModifier.shift);
    });

    test('different modifiers never form a double-tap', () {
      final t = ModifierTapTracker();
      expect(t.tap(KeyModifier.shift, at(0)), isNull);
      expect(t.tap(KeyModifier.ctrl, at(100)), isNull); // ctrl != shift
    });

    test('an intervening key (reset) breaks the gesture', () {
      final t = ModifierTapTracker();
      expect(t.tap(KeyModifier.shift, at(0)), isNull);
      t.reset(); // e.g. a letter was pressed: Shift a Shift
      expect(t.tap(KeyModifier.shift, at(100)), isNull);
    });

    test('firing consumes the pair — a third tap re-arms, not re-fires', () {
      final t = ModifierTapTracker();
      expect(t.tap(KeyModifier.shift, at(0)), isNull);
      expect(t.tap(KeyModifier.shift, at(100)), KeyModifier.shift); // fires + resets
      expect(t.tap(KeyModifier.shift, at(150)), isNull); // back to arming
      expect(t.tap(KeyModifier.shift, at(200)), KeyModifier.shift);
    });
  });
}
