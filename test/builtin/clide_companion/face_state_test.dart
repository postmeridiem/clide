import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:test/test.dart';

/// Every glyph the face can draw, from every source: the per-state eye and
/// mouth rows, the talk cycle, and the blink replacement.
Set<String> _allTableGlyphs() {
  final out = <String>{};
  for (final state in FaceState.values) {
    final spec = specFor(state);
    out.addAll(spec.eyes.split(''));
    out.addAll(spec.mouth.split(''));
  }
  for (final frame in kTalkCycle) {
    out.addAll(frame.split(''));
  }
  out.add(kBlinkChar);
  return out;
}

void main() {
  group('specFor', () {
    test('every state has a spec', () {
      for (final state in FaceState.values) {
        expect(() => specFor(state), returnsNormally, reason: '$state has no spec');
      }
    });

    test('returns the identical const instance each call', () {
      for (final state in FaceState.values) {
        expect(identical(specFor(state), specFor(state)), isTrue, reason: '$state rebuilds its spec');
      }
    });
  });

  group('the face carries no rain (T-537)', () {
    // The split: the face reports Clide, the rain reports the primary session
    // (D-107 commitment 5). One value driving both meant making the rain follow
    // the session dragged his expression along with it. There is no assertion
    // for "FaceSpec has no rainDensity" — that is the compiler's job, and it is
    // enforced by nothing in lib/ referencing it.

    test('every state is a complete face on its own', () {
      for (final state in FaceState.values) {
        final spec = specFor(state);
        expect(spec.eyes, isNotEmpty, reason: '$state has no eyes');
        expect(spec.opacity, greaterThan(0), reason: '$state is invisible');
      }
    });
  });

  group('wait cues', () {
    // The elapsed counter is no longer a face flag: it is gated on a turn
    // running (T-539), because a wait cue that only appeared when Clide happened
    // to be wearing the right expression would miss most waits. DeskLock's hard
    // requirement — a wait always shows alive-and-working signals, never a fake
    // progress bar — is met by the counter plus the rain, both on the weather
    // layer. Its assertions live in the painter tests.

    test('only idle shows the clock', () {
      for (final state in FaceState.values) {
        expect(specFor(state).clock, state == FaceState.idle, reason: '$state clock');
      }
    });

    test('only error is dimmed', () {
      for (final state in FaceState.values) {
        expect(specFor(state).opacity, state == FaceState.error ? 0.45 : 1.0, reason: '$state opacity');
      }
    });
  });

  group('gaze and lean', () {
    test('lean is derived from gaze, symmetric, and zero when unattended', () {
      expect(Gaze.left.leanPx, -8);
      expect(Gaze.right.leanPx, 8);
      expect(Gaze.none.leanPx, 0);
      expect(Gaze.forward.leanPx, 0);
    });

    test('left and right lean by the same magnitude', () {
      expect(Gaze.left.leanPx.abs(), Gaze.right.leanPx.abs());
    });
  });

  group('glyph coverage', () {
    // THE guard. This bug class has bitten twice — DeskLock's katakana rain
    // glyphs, then the katakana hidden inside the rage kaomoji — and both times
    // it would have rendered as tofu rather than failing anything. Adding a
    // glyph to the table now means verifying it against BOTH bundled monospace
    // fonts and adding it to kVerifiedFaceGlyphs, or this fails.
    test('the table only uses glyphs verified present in both bundled mono fonts', () {
      final verified = kVerifiedFaceGlyphs.split('').toSet();
      final unverified = _allTableGlyphs().difference(verified);
      expect(
        unverified,
        isEmpty,
        reason:
            'Unverified glyph(s) in the face table: '
            '${unverified.map((g) => '"$g" (U+${g.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})').join(', ')}. '
            'Verify against BOTH assets/fonts/jetbrains_mono/ and assets/fonts/fira_mono/ '
            'with fc-query, then add to kVerifiedFaceGlyphs.',
      );
    });

    test('no glyph is outside the Basic Multilingual Plane', () {
      // Anything needing a surrogate pair breaks the per-cell monospace grid.
      for (final glyph in _allTableGlyphs()) {
        expect(glyph.runes.length, 1, reason: 'multi-rune glyph "$glyph"');
        expect(glyph.runes.first, lessThan(0x10000), reason: 'astral glyph "$glyph"');
      }
    });

    test('no katakana anywhere in the table', () {
      // Named explicitly because it is the exact failure that has recurred.
      for (final glyph in _allTableGlyphs()) {
        final rune = glyph.runes.first;
        final isKana = (rune >= 0x3040 && rune <= 0x30FF) || (rune >= 0xFF65 && rune <= 0xFF9F);
        expect(isKana, isFalse, reason: 'kana glyph "$glyph" (U+${rune.toRadixString(16).toUpperCase()})');
      }
    });
  });

  group('eye rows', () {
    test('every state has a two-eye row of equal width', () {
      // The painter centres the mouth against the eye row, so a ragged row
      // would make the lean offset mean different things per state.
      final widths = {for (final s in FaceState.values) s: specFor(s).eyes.length};
      expect(widths.values.toSet(), hasLength(1), reason: 'eye rows differ in width: $widths');
    });

    test('blink leaves the eye row the same width', () {
      for (final state in FaceState.values) {
        final eyes = specFor(state).eyes;
        final blinked = eyes.replaceAll(RegExp(r'[^ ]'), kBlinkChar);
        expect(blinked.length, eyes.length, reason: '$state blink changes width');
      }
    });
  });

  group('timings', () {
    test('blink gap range is ordered and positive', () {
      expect(kBlinkMinGap, lessThan(kBlinkMaxGap));
      expect(kBlinkHold, lessThan(kBlinkMinGap));
      expect(kBlinkHold.inMilliseconds, greaterThan(0));
    });

    test('the talk cycle opens and closes', () {
      expect(kTalkCycle, isNotEmpty);
      expect(kTalkCycle.first, kTalkCycle.last, reason: 'talk cycle should loop seamlessly');
    });
  });
}
