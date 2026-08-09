import 'package:clide/builtin/clide_companion/src/rain_field.dart';
import 'package:test/test.dart';

/// Ranges verified present in BOTH bundled monospace fonts with `fc-query`.
/// Deliberately narrower than JetBrains Mono alone: Fira Mono lacks U+2506 and
/// U+250A, and the mono face is user-selectable (D-101).
bool _verified(int rune) {
  if (rune >= 0x20 && rune <= 0x7E) return true; // ASCII printable
  const boxAndGeometric = <int>[
    0x2500, 0x2502, 0x250C, 0x2510, 0x2514, 0x2518, //
    0x251C, 0x2524, 0x252C, 0x2534, 0x253C, 0x254E,
    0x2571, 0x2572, 0x2575, 0x2577, 0x25AA,
  ];
  return boxAndGeometric.contains(rune);
}

RainField _field({int columns = 20, int rows = 20, int seed = 7}) => RainField(columns: columns, rows: rows, seed: seed);

/// Run [field] for [seconds] at a fixed step.
void _run(RainField field, {required double seconds, required int target, required double speed, double step = 1 / 30}) {
  for (var t = 0.0; t < seconds; t += step) {
    field.tick(step, targetStreams: target, speed: speed);
  }
}

void main() {
  group('glyph set', () {
    test('every glyph is verified present in both bundled mono fonts', () {
      // The guard. `┆` (U+2506) and `┊` (U+250A) are the obvious rain glyphs and
      // are present in JetBrains Mono but ABSENT from Fira Mono — they would be
      // tofu for anyone who switched fonts. This fails if one sneaks in.
      final unverified = kRainGlyphs.where((g) => !_verified(g.runes.first)).toList();
      expect(
        unverified,
        isEmpty,
        reason:
            'Unverified rain glyph(s): '
            '${unverified.map((g) => '"$g" (U+${g.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})').join(', ')}. '
            'Verify against BOTH assets/fonts/jetbrains_mono/ and assets/fonts/fira_mono/ with fc-query first.',
      );
    });

    test('no katakana', () {
      for (final g in kRainGlyphs) {
        final r = g.runes.first;
        final isKana = (r >= 0x3040 && r <= 0x30FF) || (r >= 0xFF65 && r <= 0xFF9F);
        expect(isKana, isFalse, reason: 'kana glyph "$g"');
      }
    });

    test('every glyph is a single BMP rune', () {
      // A surrogate pair or combining mark would break the monospace cell grid.
      for (final g in kRainGlyphs) {
        expect(g.runes.length, 1, reason: 'multi-rune glyph "$g"');
        expect(g.runes.first, lessThan(0x10000), reason: 'astral glyph "$g"');
      }
    });

    test('has no duplicates', () {
      expect(kRainGlyphs.toSet().length, kRainGlyphs.length);
    });
  });

  group('determinism', () {
    test('same seed and same ticks produce an identical field', () {
      final a = _field(seed: 42);
      final b = _field(seed: 42);
      _run(a, seconds: 3, target: 20, speed: 9);
      _run(b, seconds: 3, target: 20, speed: 9);

      final ca = a.cells.toList();
      final cb = b.cells.toList();
      expect(ca.length, cb.length);
      for (var i = 0; i < ca.length; i++) {
        expect(ca[i].column, cb[i].column);
        expect(ca[i].row, closeTo(cb[i].row, 1e-12));
        expect(ca[i].glyphIndex, cb[i].glyphIndex);
        expect(ca[i].leading, cb[i].leading);
      }
    });

    test('different seeds diverge', () {
      final a = _field(seed: 1);
      final b = _field(seed: 2);
      _run(a, seconds: 3, target: 20, speed: 9);
      _run(b, seconds: 3, target: 20, speed: 9);
      final sameColumns = a.cells.map((c) => c.column).toList().toString() == b.cells.map((c) => c.column).toList().toString();
      expect(sameColumns, isFalse, reason: 'different seeds produced the same field');
    });
  });

  group('density', () {
    test('converges on the target and holds', () {
      final f = _field();
      _run(f, seconds: 4, target: 24, speed: 9);
      expect(f.streamCount, 24);
      _run(f, seconds: 2, target: 24, speed: 9);
      expect(f.streamCount, 24, reason: 'density drifted once converged');
    });

    test('ramps rather than snaps', () {
      // Idle -> effort should read as the field filling in, not popping.
      final f = _field();
      _run(f, seconds: 2, target: 2, speed: 4);
      expect(f.streamCount, 2);

      f.tick(1 / 30, targetStreams: 40, speed: 16);
      expect(f.streamCount, lessThan(40), reason: 'density snapped to target in one frame');
      expect(f.streamCount, greaterThan(2), reason: 'density did not begin ramping');

      _run(f, seconds: 2, target: 40, speed: 16);
      expect(f.streamCount, 40, reason: 'ramp never reached the target');
    });

    test('holds exactly under maximum churn', () {
      // Regression guard. Cull and spawn happen in the same tick, so if
      // replacing a culled stream is charged to the same rate limit that makes
      // ramping visible, a dense fast field hovers below its target forever —
      // at 40 streams the cull rate alone eats the whole per-frame allowance.
      // Sampled every frame, because the shortfall is invisible if you only
      // look once at the end.
      final f = _field();
      _run(f, seconds: 4, target: 40, speed: 20);
      for (var i = 0; i < 300; i++) {
        f.tick(1 / 30, targetStreams: 40, speed: 20);
        expect(f.streamCount, 40, reason: 'density dipped to ${f.streamCount} on frame $i');
      }
    });

    test('drains by falling off the bottom, not by clearing', () {
      final f = _field();
      _run(f, seconds: 4, target: 40, speed: 16);
      expect(f.streamCount, 40);

      // One frame at target 0 must not empty the field — the rain runs out.
      f.tick(1 / 30, targetStreams: 0, speed: 0);
      expect(f.streamCount, greaterThan(0), reason: 'field was cleared instead of drained');
    });
  });

  group('the error state actually stops', () {
    test('a fresh field at zero density never spawns', () {
      final f = _field();
      _run(f, seconds: 5, target: 0, speed: 0);
      expect(f.streamCount, 0);
      expect(f.cells, isEmpty);
      expect(f.isQuiescent, isTrue);
    });

    test('an existing field drains to empty and reports quiescent', () {
      final f = _field();
      _run(f, seconds: 3, target: 30, speed: 16);
      expect(f.isQuiescent, isFalse);

      // Streams keep their spawn-time speed, so draining takes as long as the
      // slowest one needs to fall clear.
      _run(f, seconds: 20, target: 0, speed: 0);
      expect(f.streamCount, 0);
      expect(f.cells, isEmpty);
      expect(f.isQuiescent, isTrue, reason: 'field never went quiescent, so the ticker could never park');
    });
  });

  group('bounds', () {
    test('cell count stays bounded over a long run', () {
      // The leak test. An unbounded field is the obvious failure mode for a
      // perpetual simulation, and it would not show up in a short render.
      final f = _field();
      _run(f, seconds: 120, target: 40, speed: 16);
      expect(f.streamCount, 40, reason: 'streams accumulated: ${f.streamCount}');
      expect(f.cells.length, lessThanOrEqualTo(40 * (f.trailLength + 1)), reason: 'cells accumulated: ${f.cells.length}');
    });

    test('no cell is ever drawn outside the grid', () {
      final f = _field(columns: 12, rows: 15);
      for (var t = 0.0; t < 30; t += 1 / 30) {
        f.tick(1 / 30, targetStreams: 30, speed: 14);
        for (final c in f.cells) {
          expect(c.column, inInclusiveRange(0, 11), reason: 'column out of grid');
          expect(c.row, greaterThanOrEqualTo(0));
          expect(c.row, lessThan(15), reason: 'row out of grid');
          expect(c.glyphIndex, inInclusiveRange(0, kRainGlyphs.length - 1));
        }
      }
    });

    test('each stream contributes at most a head and its trail', () {
      final f = _field();
      _run(f, seconds: 4, target: 40, speed: 16);
      expect(f.cells.where((c) => c.leading).length, lessThanOrEqualTo(f.streamCount));
      expect(f.cells.length, lessThanOrEqualTo(f.streamCount * (f.trailLength + 1)));
    });

    test('a trail fades monotonically behind its head', () {
      // The fade is what makes a stream read as falling rather than as a dash
      // (T-533), so its shape is asserted rather than eyeballed.
      final f = RainField(columns: 1, rows: 40, seed: 11, trailLength: 6);
      _run(f, seconds: 2, target: 1, speed: 6);
      final cells = f.cells.toList()..sort((a, b) => b.row.compareTo(a.row));
      expect(cells.length, greaterThan(1), reason: 'no trail was drawn at all');
      expect(cells.first.intensity, 1.0, reason: 'the lowest cell is the head');
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].intensity, lessThan(cells[i - 1].intensity), reason: 'intensity did not fall at cell $i');
        expect(cells[i].intensity, greaterThan(0), reason: 'an invisible cell was still drawn at $i');
      }
    });

    test('trail length is honoured', () {
      for (final trail in const [1, 4, 6]) {
        final f = RainField(columns: 1, rows: 40, seed: 3, trailLength: trail);
        _run(f, seconds: 2, target: 1, speed: 6);
        expect(f.cells.length, lessThanOrEqualTo(trail + 1), reason: 'trail $trail drew ${f.cells.length} cells');
      }
    });

    test('a degenerate grid is handled rather than dividing by zero', () {
      final zero = RainField(columns: 0, rows: 0, seed: 3);
      _run(zero, seconds: 1, target: 20, speed: 9);
      expect(zero.cells, isEmpty);
      expect(zero.streamCount, 0);
    });
  });

  group('tick guards', () {
    test('a zero or negative dt is a no-op', () {
      final f = _field();
      _run(f, seconds: 2, target: 10, speed: 9);
      final before = f.cells.map((c) => c.row).toList();
      f.tick(0, targetStreams: 10, speed: 9);
      f.tick(-1, targetStreams: 10, speed: 9);
      expect(f.cells.map((c) => c.row).toList(), before);
    });
  });
}
