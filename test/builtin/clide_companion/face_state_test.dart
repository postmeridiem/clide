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

  group('rain density is the load signal', () {
    test('density is ordered idle < pensive < speaking < listening < rage < effort', () {
      int rain(FaceState s) => specFor(s).rainStreams;
      expect(rain(FaceState.idle), lessThan(rain(FaceState.pensive)));
      expect(rain(FaceState.pensive), lessThan(rain(FaceState.speaking)));
      expect(rain(FaceState.speaking), lessThan(rain(FaceState.listening)));
      expect(rain(FaceState.listening), lessThan(rain(FaceState.rage)));
      expect(rain(FaceState.rage), lessThan(rain(FaceState.effort)));
    });

    test('error stops the rain completely', () {
      // The visible half of the power-ladder contract (D-107): a dead session
      // must not keep animating.
      expect(specFor(FaceState.error).rainStreams, 0);
      expect(specFor(FaceState.error).rainSpeed, 0);
    });

    test('every other state has moving rain', () {
      for (final state in FaceState.values.where((s) => s != FaceState.error)) {
        expect(specFor(state).rainStreams, greaterThan(0), reason: '$state has no rain');
        expect(specFor(state).rainSpeed, greaterThan(0), reason: '$state has stalled rain');
      }
    });
  });

  group('wait cues', () {
    test('effort is the only state showing both honest wait cues', () {
      // DeskLock's hard requirement: a wait always shows alive-and-working
      // signals, and never a fake progress bar.
      for (final state in FaceState.values) {
        final spec = specFor(state);
        final isEffort = state == FaceState.effort;
        expect(spec.orbit, isEffort, reason: '$state orbit');
        expect(spec.elapsed, isEffort, reason: '$state elapsed');
      }
    });

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
