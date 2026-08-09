/// Clide companion rain field (T-522, D-107) — the load signal behind the face.
///
/// Density is the point. Two streams means idle; forty means the session is
/// grinding. That difference is readable at a glance without reading anything,
/// which is the whole reason the companion exists, so the simulation is its own
/// unit rather than something asserted through a painted image.
///
/// Flutter-free: pure Dart, runs under `dart test`. Produces cell positions and
/// glyph *indices*; the painter (T-524) resolves indices to characters and picks
/// colours from theme tokens.
///
/// Deterministic by construction — a hand-rolled xorshift seeded per field, so
/// the same seed and the same tick sequence always produce the same field.
/// Goldens depend on that, and on it not drifting when the Dart SDK changes its
/// `Random` implementation.
library;

/// Glyphs the rain may draw, verified present in **both** bundled monospace
/// fonts (JetBrains Mono and Fira Mono) with `fc-query`.
///
/// Two constraints shaped this set, both learned the hard way:
///
/// 1. **No katakana.** DeskLock's rain uses `アイウエオカキ…`; the bundled fonts
///    have zero kana coverage, so those would fall through to a system font,
///    break goldens, and break the monospace advance width this grid assumes.
///    Only DeskLock's covered half (`0-9 A C E F H K Z $ # % * + = < >`) ports.
///
/// 2. **Both fonts, not one.** The mono face is user-selectable (D-101). The
///    obvious rain glyphs `┆` (U+2506) and `┊` (U+250A) — dashed and dotted
///    verticals, exactly what falling rain wants — are present in JetBrains Mono
///    and **absent from Fira Mono**, so they would render as tofu for anyone who
///    switched fonts. They are deliberately excluded. Check both:
///
/// ```sh
/// fc-query --format='%{charset}\n' assets/fonts/fira_mono/FiraMono-Regular.ttf
/// ```
///
/// `rain_field_test.dart` asserts the set only contains verified glyphs, so an
/// unverified addition fails the suite rather than the render.
const kRainGlyphs = <String>[
  // DeskLock's ASCII half — the characters that carry the "code rain" read.
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  'A', 'C', 'E', 'F', 'H', 'K', 'Z',
  r'$', '#', '%', '*', '+', '=', '<', '>',
  // Box drawing and geometric, present in both fonts. Verticals and junctions
  // read as falling; the diagonals and the small square break up the grid.
  '─', '│', '┌', '┐', '└', '┘', '├', '┤', '┬', '┴', '┼', '╎', '╱', '╲', '╵', '╷', '▪',
];

/// One drawn cell. The painter turns this into a glyph at a pixel position.
class RainCell {
  const RainCell({required this.column, required this.row, required this.glyphIndex, required this.leading});

  /// Grid column.
  final int column;

  /// Grid row, fractional — the painter interpolates for smooth fall.
  final double row;

  /// Index into [kRainGlyphs].
  final int glyphIndex;

  /// True for the head of a stream, which DeskLock draws brighter than its
  /// trail. The painter picks the colour; this only says which is which.
  final bool leading;
}

/// Xorshift32. Hand-rolled rather than `dart:math`'s `Random(seed)` so the
/// sequence is pinned to this file and cannot drift when the SDK changes its
/// generator — goldens would silently rebase if it did.
class _Rng {
  _Rng(int seed) : _s = (seed == 0 ? 0x9E3779B9 : seed) & 0xFFFFFFFF;

  int _s;

  int _next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    return _s = x & 0xFFFFFFFF;
  }

  double nextDouble() => _next() / 0x100000000;

  int nextInt(int max) => max <= 0 ? 0 : _next() % max;
}

class _Stream {
  _Stream({required this.column, required this.row, required this.speed, required this.glyphIndex, required this.trailGlyphIndex});

  final int column;
  double row;
  final double speed;
  int glyphIndex;
  int trailGlyphIndex;
}

/// A falling-glyph field on a [columns] × [rows] grid.
class RainField {
  RainField({required this.columns, required this.rows, int seed = 0}) : _rng = _Rng(seed);

  /// Streams spawned per second while ramping up. Chosen so idle→effort (2→40)
  /// fills in ~0.6s: visible as the field *filling*, not popping.
  static const double spawnPerSecond = 60;

  /// A stream is culled once it falls this far past the bottom, so its trail
  /// cell has left the grid too.
  static const double cullMargin = 2;

  final int columns;
  final int rows;
  final _Rng _rng;
  final List<_Stream> _streams = [];

  /// Fractional spawn credit carried between ticks, so a slow ramp is not lost
  /// to rounding on short frames.
  double _spawnCredit = 0;

  /// Live stream count. This is the value that converges on `targetStreams`.
  int get streamCount => _streams.length;

  /// True when nothing is left to draw. The widget (T-525) can park its ticker
  /// on this — the visible half of the power-ladder contract (D-107).
  bool get isQuiescent => _streams.isEmpty;

  /// Advance by [dt] seconds, moving toward [targetStreams] at [speed].
  ///
  /// Density **ramps rather than snaps**: spawning is rate-limited, and a
  /// reduced target drains by letting streams fall off the bottom rather than
  /// clearing them, so a state change reads as the field filling or thinning.
  void tick(double dt, {required int targetStreams, required double speed}) {
    if (dt <= 0) return;

    for (final s in _streams) {
      s.row += s.speed * dt;
      // Re-roll glyphs as the stream falls — the flicker that makes it read as
      // code rather than as moving dots.
      s.glyphIndex = _rng.nextInt(kRainGlyphs.length);
      s.trailGlyphIndex = _rng.nextInt(kRainGlyphs.length);
    }

    final beforeCull = _streams.length;
    _streams.removeWhere((s) => s.row > rows + cullMargin);
    final culled = beforeCull - _streams.length;

    if (targetStreams <= 0 || columns <= 0 || rows <= 0) {
      _spawnCredit = 0;
      return;
    }

    final deficit = targetStreams - _streams.length;
    if (deficit <= 0) {
      _spawnCredit = 0;
      return;
    }

    // Churn and growth are different things and do not share a budget.
    // Replacing a stream that just fell off the bottom keeps density flat, so it
    // is free; only a genuine *increase* is rate-limited. Sharing one budget
    // makes a dense field hover below its target forever, because at 40 streams
    // the cull rate alone consumes the whole per-frame spawn allowance.
    final replacements = culled.clamp(0, deficit);
    _spawnCredit += spawnPerSecond * dt;
    final growth = _spawnCredit.floor().clamp(0, deficit - replacements);
    _spawnCredit -= growth;

    for (var i = 0; i < replacements + growth; i++) {
      _streams.add(_spawn(speed));
    }
  }

  _Stream _spawn(double speed) => _Stream(
    column: _rng.nextInt(columns),
    // Start just above the grid, staggered so a burst does not arrive as a
    // single rank.
    row: -_rng.nextDouble() * 14,
    // Per-stream speed jitter, as DeskLock does it: ±30% around the state's
    // base speed, assigned at spawn. A state change therefore affects new
    // streams first, which makes the transition read as organic.
    speed: speed * (0.7 + _rng.nextDouble() * 0.6),
    glyphIndex: _rng.nextInt(kRainGlyphs.length),
    trailGlyphIndex: _rng.nextInt(kRainGlyphs.length),
  );

  /// The cells to draw this frame: each stream contributes its head plus one
  /// dimmer trail cell above it. Cells outside the grid are omitted.
  Iterable<RainCell> get cells sync* {
    for (final s in _streams) {
      if (s.row >= 0 && s.row < rows) {
        yield RainCell(column: s.column, row: s.row, glyphIndex: s.glyphIndex, leading: true);
      }
      final trail = s.row - 1;
      if (trail >= 0 && trail < rows) {
        yield RainCell(column: s.column, row: trail, glyphIndex: s.trailGlyphIndex, leading: false);
      }
    }
  }
}
