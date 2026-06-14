/// Unit tests for ModifierTapTracker — double-tapped bare-modifier
/// detection (T-341), clean-release semantics (T-409).
library;

import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:clide/kernel/src/keymap/modifier_tap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed base instant; offsets are in milliseconds. (Date.now-free so the
  // test is deterministic.)
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  // A clean tap: bare press + release.
  KeyModifier? tap(ModifierTapTracker t, KeyModifier m, int ms) {
    t.down(m);
    return t.up(m, at(ms));
  }

  group('ModifierTapTracker', () {
    test('two clean taps of the same modifier within the window fire', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(tap(t, KeyModifier.shift, 0), isNull); // first tap arms
      expect(tap(t, KeyModifier.shift, 200), KeyModifier.shift); // double-tap
    });

    test('the second tap just outside the window does not fire', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(tap(t, KeyModifier.shift, 0), isNull);
      expect(tap(t, KeyModifier.shift, 400), isNull); // too slow
    });

    test('a slow second tap re-arms, so a prompt third tap fires', () {
      final t = ModifierTapTracker(window: const Duration(milliseconds: 350));
      expect(tap(t, KeyModifier.shift, 0), isNull);
      expect(tap(t, KeyModifier.shift, 500), isNull); // re-arms from here
      expect(tap(t, KeyModifier.shift, 600), KeyModifier.shift);
    });

    test('different modifiers never form a double-tap', () {
      final t = ModifierTapTracker();
      expect(tap(t, KeyModifier.shift, 0), isNull);
      expect(tap(t, KeyModifier.ctrl, 100), isNull); // ctrl != shift
    });

    test('an intervening key between taps breaks the gesture', () {
      final t = ModifierTapTracker();
      expect(tap(t, KeyModifier.shift, 0), isNull);
      t.down(null); // a letter: Shift a Shift
      t.up(null, at(50));
      expect(tap(t, KeyModifier.shift, 100), isNull);
    });

    test('firing consumes the pair — a third tap re-arms, not re-fires', () {
      final t = ModifierTapTracker();
      expect(tap(t, KeyModifier.shift, 0), isNull);
      expect(tap(t, KeyModifier.shift, 100), KeyModifier.shift); // fires + resets
      expect(tap(t, KeyModifier.shift, 150), isNull); // back to arming
      expect(tap(t, KeyModifier.shift, 200), KeyModifier.shift);
    });

    // T-409 regression: a chorded press (Shift+; typing a colon) is not a tap.
    test('a key chorded onto a held modifier dirties the press', () {
      final t = ModifierTapTracker();
      t.down(KeyModifier.shift);
      t.down(null); // `;` while Shift held — typing `:`
      t.up(null, at(50));
      expect(t.up(KeyModifier.shift, at(80)), isNull); // dirty press, no tap
    });

    test('typing two colons rapidly never fires', () {
      final t = ModifierTapTracker();
      for (final base in [0, 120]) {
        t.down(KeyModifier.shift);
        t.down(null);
        t.up(null, at(base + 40));
        expect(t.up(KeyModifier.shift, at(base + 60)), isNull);
      }
    });

    test('a chorded press also breaks an armed first tap', () {
      final t = ModifierTapTracker();
      expect(tap(t, KeyModifier.shift, 0), isNull); // clean tap arms
      t.down(KeyModifier.shift);
      t.down(null); // Shift+; — chord, must disarm
      t.up(null, at(40));
      expect(t.up(KeyModifier.shift, at(60)), isNull);
      // The next single clean tap re-arms but must not fire either.
      expect(tap(t, KeyModifier.shift, 100), isNull);
    });

    test('a second modifier chorded onto the first is not a tap', () {
      final t = ModifierTapTracker();
      t.down(KeyModifier.shift);
      t.down(KeyModifier.ctrl); // ctrl while shift held
      expect(t.up(KeyModifier.ctrl, at(30)), isNull);
      expect(t.up(KeyModifier.shift, at(50)), isNull);
    });

    test('a release without a tracked press is ignored', () {
      final t = ModifierTapTracker();
      expect(t.up(KeyModifier.shift, at(0)), isNull); // stale release
      expect(tap(t, KeyModifier.shift, 50), isNull); // arms normally after
      expect(tap(t, KeyModifier.shift, 150), KeyModifier.shift);
    });
  });
}
