/// Clide companion painter (T-524, D-107) — draws the face and the rain field.
///
/// Composes the three pieces built ahead of it: the state contract
/// (`face_state.dart`), the simulation (`rain_field.dart`) and the paragraph
/// cache (`glyph_cache.dart`).
///
/// **The clock is both the time source and the repaint source.** `repaint:` on
/// `CustomPainter` triggers a repaint *without* rebuilding the widget subtree —
/// the first use of that in this repo. Both existing painters drive repaints
/// through `setState`, which is right for a static painter that repaints on
/// interaction and wrong for something animating 30 times a second. Because the
/// painter is not reconstructed per frame, a `final Duration` field would go
/// stale, so time arrives through the same listenable that schedules the paint.
///
/// The painter **reads**; it does not simulate. Advancing the rain field is the
/// widget's job (T-525), which keeps this class free of hidden state and makes
/// every frame a pure function of (clock, field, spec, tokens).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/glyph_cache.dart';
import 'package:clide/builtin/clide_companion/src/rain_field.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Average gap between blinks; the actual gap is jittered per cycle.
const _blinkAverageGap = 4.4;

/// Jitter step — how often the shake flips sign.
const _jitterStep = 0.16;

/// Cheap deterministic 0..1 from an integer, for per-cycle blink jitter.
/// Avoids `Random` so a frame is reproducible from its timestamp alone.
double _hash01(int n) {
  var x = (n * 0x9E3779B1) & 0x7FFFFFFF;
  x ^= x >> 15;
  x = (x * 0x85EBCA6B) & 0x7FFFFFFF;
  x ^= x >> 13;
  return (x & 0xFFFF) / 0xFFFF;
}

class ClideFacePainter extends CustomPainter {
  ClideFacePainter({
    required this.clock,
    required this.state,
    required this.gaze,
    required this.field,
    required this.cache,
    required this.tokens,
    required this.fontFamily,
    this.fontFamilyFallback,
    this.busyFor,
    this.lean,
    this.clockLabel,
    this.faceAlignX = 0,
    this.rainFontSize = 11,
  }) : super(repaint: clock);

  /// Elapsed time since the face was mounted. Drives every cyclic animation and
  /// schedules the repaint.
  final ValueListenable<Duration> clock;

  final FaceState state;
  final Gaze gaze;

  /// Simulation state, advanced by the widget before this paints.
  final RainField field;

  final GlyphCache cache;
  final SurfaceTokens tokens;
  final String fontFamily;
  final List<String>? fontFamilyFallback;

  /// How long the current turn has been running; drives the `[ Ns ]` counter.
  /// Owned by Epic B — the face never times turns itself.
  final Duration? busyFor;

  /// Mouth offset from the eye centre. Defaults to the value derived from
  /// [gaze]; the widget may pass an interpolated value to animate the
  /// transition, which is what makes the lean read as a movement rather than a
  /// snap (D-107).
  final double? lean;

  /// `HH:MM` for the idle state, supplied by the widget.
  ///
  /// Time-of-day is the one thing here that is not derived from the ticker, so
  /// it is passed in rather than read from `DateTime.now()` inside `paint`.
  /// That keeps the painter a pure function of its inputs and lets goldens pin
  /// the clock instead of rendering a different image every minute. Null draws
  /// no clock, whatever the spec says.
  final String? clockLabel;

  /// Where the face group sits horizontally: `-1` flush left, `0` centred,
  /// `1` flush right. The **rain always spans the full box** regardless.
  ///
  /// That separation is the point. In the chosen placement the face sits at the
  /// left of a wide strip with the speech bubble beside it, but the rain must
  /// still use the whole width — density is read as how many columns are lit,
  /// and confining it to a narrow face region would cut ~45 columns to ~9 and
  /// undo the reason the strip was chosen over a rail (T-514).
  final double faceAlignX;

  final double rainFontSize;

  double get _lean => lean ?? gaze.leanPx;

  double get _seconds => clock.value.inMicroseconds / 1e6;

  /// The rain's colour: markdown's inline-code green (`syntaxString`), not the
  /// muted body text it started as.
  ///
  /// Reaching for a *syntax* token from chrome looks like a layering slip and is
  /// not. The rain is the one place in the app that is literally falling code —
  /// the same green the markdown reader gives a backticked span — and borrowing
  /// the token is what keeps it in step with a theme rather than approximating
  /// one theme's idea of green. Verified readable across every bundled theme
  /// before adopting.
  Color get _rainColor => tokens.syntaxString;

  /// Accent for the face.
  ///
  /// Stays `globalForeground` at rest, deliberately, now that the rain is
  /// coloured: the face is the character and the rain is the weather (D-107
  /// commitment 5), and giving them one colour would undo the separation the
  /// vignette exists to create — worst at high density, which is exactly when
  /// the face needs to read.
  Color get _faceColor => switch (state) {
    FaceState.rage => tokens.statusWarning,
    FaceState.error => tokens.statusError,
    _ => tokens.globalForeground,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final spec = specFor(state);
    final t = _seconds;

    _paintRain(canvas, size);
    _paintVignette(canvas, size);
    _paintFace(canvas, size, spec, t);
    if (spec.elapsed) _paintElapsed(canvas, size);
  }

  void _paintRain(Canvas canvas, Size size) {
    final cell = cache.metrics(fontSize: rainFontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    if (cell.width <= 0 || cell.height <= 0) return;

    // One pass: the field yields each stream tail-first, so a head already
    // paints over its own trail. The old two-pass split re-ran the `cells`
    // generator — and its per-cell allocation — twice per frame.
    for (final c in field.cells) {
      final p = cache.paragraph(
        kRainGlyphs[c.glyphIndex],
        // Quantised so the glyph cache sees a handful of colours rather than a
        // new one per cell; keys include the colour, and an unbounded palette
        // would evict the whole cache every frame.
        color: _rainColor.withValues(alpha: _trailAlpha(c.intensity)),
        fontSize: rainFontSize,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );
      canvas.drawParagraph(p, Offset(c.column * cell.width, c.row * cell.height));
    }
  }

  /// Intensity → alpha. Curved rather than linear so the head stays clearly the
  /// brightest thing and the tail falls away quickly, which is what gives the
  /// stream a direction.
  static double _trailAlpha(double intensity) {
    final a = 0.85 * math.pow(intensity.clamp(0.0, 1.0), 1.7);
    return (a * 32).round() / 32;
  }

  /// Radial darkening behind the face. At 40 streams this is load-bearing, not
  /// decoration — without it the glyphs compete with the rain for legibility.
  ///
  /// Anchored on the face and sized off the height, never off the width. Sizing
  /// it to the box made it a local pool behind a square face and a full-width
  /// wash across a strip — which erases the rain everywhere, including the
  /// columns whose job is to show density (T-526).
  void _paintVignette(Canvas canvas, Size size) {
    final centre = Offset(_faceCentreX(size), size.height * 0.47);
    final radius = size.height * 0.85;
    if (radius <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          radius,
          [tokens.panelBackground.withValues(alpha: 0.94), tokens.panelBackground.withValues(alpha: 0)],
          const [0.25, 1],
        ),
    );
  }

  double _eyeSize(Size size) => (size.height * 0.22).clamp(8.0, 40.0);

  /// Centre of the face group, without laying out any text.
  ///
  /// The eye row is five monospace cells at [_eyeSize]; a mono advance is close
  /// enough to 0.6em that the vignette can be placed before the face is laid
  /// out, which is what lets it be painted underneath.
  double _faceCentreX(Size size) {
    final width = _eyeSize(size) * 0.6 * 5;
    return _alignX(size.width, width) + width / 2;
  }

  void _paintFace(Canvas canvas, Size size, FaceSpec spec, double t) {
    final eyeSize = _eyeSize(size);
    final mouthSize = eyeSize * 0.62;

    // Breathe: 0 → amplitude → 0 over the period, applied to the whole group.
    final breathe = (1 - math.cos(2 * math.pi * t / (kBreathePeriod.inMilliseconds / 1000))) / 2 * kBreatheAmplitudePx;
    final jitter = spec.jitter ? (((t / _jitterStep).floor() % 2 == 0) ? 1.0 : -1.0) : 0.0;

    final colour = _faceColor.withValues(alpha: _faceColor.a * spec.opacity);
    final muted = tokens.globalTextMuted.withValues(alpha: tokens.globalTextMuted.a * spec.opacity);

    final eyes = _eyesNow(spec, t);
    final eyesPara = cache.paragraph(eyes, color: colour, fontSize: eyeSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    final eyesX = _alignX(size.width, eyesPara.maxIntrinsicWidth) + jitter;
    final eyesY = size.height * 0.30 + breathe + jitter;
    canvas.drawParagraph(eyesPara, Offset(eyesX, eyesY));

    // Everything below the eyes hangs off the eye group's centre, not off the
    // box. Aligning each element independently is the same thing only while the
    // face is centred; once it sits left (faceAlignX: -1) a one-character mouth
    // aligns to the same margin as the five-character eye row and ends up under
    // the *left eye* instead of under the face.
    final eyesCentre = eyesX + eyesPara.maxIntrinsicWidth / 2;

    final mouth = _mouthNow(spec, t);
    if (mouth.isNotEmpty) {
      final mouthPara = cache.paragraph(mouth, color: colour, fontSize: mouthSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      // The lean: the mouth slides off the eye axis. One number, and the reason
      // the face reads as attending to something rather than staring ahead.
      final mouthX = eyesCentre - mouthPara.maxIntrinsicWidth / 2 + _lean + jitter;
      canvas.drawParagraph(mouthPara, Offset(mouthX, eyesY + eyesPara.height * 0.9));
    }

    if (spec.thoughtDots) {
      final dots = '.' * (1 + (t / (kThoughtDotFrame.inMilliseconds / 1000)).floor() % 3);
      final p = cache.paragraph(dots, color: muted, fontSize: mouthSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      canvas.drawParagraph(p, Offset(eyesX + eyesPara.maxIntrinsicWidth + mouthSize * 0.4, eyesY - mouthSize * 0.2));
    }

    final clock = clockLabel;
    if (spec.clock && clock != null) {
      final p = cache.paragraph(clock, color: muted, fontSize: mouthSize * 0.7, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      _drawBottomCue(canvas, size, p);
    }
  }

  /// Draw a muted cue on the bottom edge, on the face's side of the box.
  ///
  /// The clock and the elapsed counter share this slot — they never appear
  /// together (one is `idle`, the other `effort`). Stacking them under the mouth
  /// instead worked at the 320×120 the face was prototyped at and clipped at the
  /// 112px strip height (T-526); anchoring to the bottom edge holds at any height
  /// the strip is later given.
  void _drawBottomCue(Canvas canvas, Size size, ui.Paragraph p) {
    canvas.drawParagraph(p, Offset(_alignX(size.width, p.maxIntrinsicWidth), size.height - p.height - 4));
  }

  /// Horizontal origin for a face element of [contentWidth] inside [boxWidth],
  /// honouring [faceAlignX] with a margin so it never sits flush to the edge.
  double _alignX(double boxWidth, double contentWidth) {
    const margin = 12.0;
    final available = (boxWidth - contentWidth - margin * 2).clamp(0.0, double.infinity);
    return margin + available * ((faceAlignX.clamp(-1.0, 1.0) + 1) / 2);
  }

  /// The eye row for this instant — blinking replaces every non-space character.
  String _eyesNow(FaceSpec spec, double t) {
    if (!spec.blink) return spec.eyes;
    final cycle = (t / _blinkAverageGap).floor();
    final start = cycle * _blinkAverageGap + _hash01(cycle) * _blinkAverageGap * 0.5;
    final hold = kBlinkHold.inMilliseconds / 1000;
    final blinking = t >= start && t < start + hold;
    return blinking ? spec.eyes.replaceAll(RegExp(r'[^ ]'), kBlinkChar) : spec.eyes;
  }

  String _mouthNow(FaceSpec spec, double t) {
    if (!spec.talkCycle) return spec.mouth;
    return kTalkCycle[(t / (kTalkFrame.inMilliseconds / 1000)).floor() % kTalkCycle.length];
  }

  /// `[ 12s ]` — the wait cue. Honest: it counts up from real elapsed time and
  /// never estimates a completion.
  void _paintElapsed(Canvas canvas, Size size) {
    final busy = busyFor;
    if (busy == null) return;
    final label = '[ ${busy.inSeconds}s ]';
    final fontSize = (size.height * 0.1).clamp(7.0, 16.0);
    final p = cache.paragraph(label, color: tokens.globalTextMuted, fontSize: fontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    _drawBottomCue(canvas, size, p);
  }

  @override
  bool shouldRepaint(ClideFacePainter old) =>
      old.state != state ||
      old.gaze != gaze ||
      old.lean != lean ||
      old.busyFor != busyFor ||
      old.clockLabel != clockLabel ||
      old.faceAlignX != faceAlignX ||
      old.rainFontSize != rainFontSize ||
      old.fontFamily != fontFamily ||
      // SurfaceTokens has no `==`, so identity is the correct comparison — a new
      // instance is only built on a theme change. Matches the existing painters.
      old.tokens != tokens ||
      !identical(old.field, field) ||
      !identical(old.cache, cache) ||
      !identical(old.clock, clock);
}
