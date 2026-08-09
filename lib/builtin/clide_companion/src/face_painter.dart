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

/// Orbit arc period, seconds per revolution.
const _orbitPeriod = 1.4;

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

  final double rainFontSize;

  double get _lean => lean ?? gaze.leanPx;

  double get _seconds => clock.value.inMicroseconds / 1e6;

  /// Accent for states that recolour the face.
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
    if (spec.orbit) _paintOrbit(canvas, size, t);
    if (spec.elapsed) _paintElapsed(canvas, size);
  }

  void _paintRain(Canvas canvas, Size size) {
    final cell = cache.metrics(fontSize: rainFontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    if (cell.width <= 0 || cell.height <= 0) return;

    // Trail first, heads second, so a head always reads over its own trail.
    for (final leading in const [false, true]) {
      final color = tokens.globalTextMuted.withValues(alpha: leading ? 0.85 : 0.25);
      for (final c in field.cells) {
        if (c.leading != leading) continue;
        final p = cache.paragraph(
          kRainGlyphs[c.glyphIndex],
          color: color,
          fontSize: rainFontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        );
        canvas.drawParagraph(p, Offset(c.column * cell.width, c.row * cell.height));
      }
    }
  }

  /// Radial darkening behind the face. At 40 streams this is load-bearing, not
  /// decoration — without it the glyphs compete with the rain for legibility.
  void _paintVignette(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.47);
    final radius = math.max(size.width, size.height) * 0.54;
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

  void _paintFace(Canvas canvas, Size size, FaceSpec spec, double t) {
    final eyeSize = (size.height * 0.22).clamp(8.0, 40.0);
    final mouthSize = eyeSize * 0.62;

    // Breathe: 0 → amplitude → 0 over the period, applied to the whole group.
    final breathe = (1 - math.cos(2 * math.pi * t / (kBreathePeriod.inMilliseconds / 1000))) / 2 * kBreatheAmplitudePx;
    final jitter = spec.jitter ? (((t / _jitterStep).floor() % 2 == 0) ? 1.0 : -1.0) : 0.0;

    final colour = _faceColor.withValues(alpha: _faceColor.a * spec.opacity);
    final muted = tokens.globalTextMuted.withValues(alpha: tokens.globalTextMuted.a * spec.opacity);

    final eyes = _eyesNow(spec, t);
    final eyesPara = cache.paragraph(eyes, color: colour, fontSize: eyeSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    final eyesX = (size.width - eyesPara.maxIntrinsicWidth) / 2 + jitter;
    final eyesY = size.height * 0.30 + breathe + jitter;
    canvas.drawParagraph(eyesPara, Offset(eyesX, eyesY));

    final mouth = _mouthNow(spec, t);
    if (mouth.isNotEmpty) {
      final mouthPara = cache.paragraph(mouth, color: colour, fontSize: mouthSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      // The lean: the mouth slides off the eye axis. One number, and the reason
      // the face reads as attending to something rather than staring ahead.
      final mouthX = (size.width - mouthPara.maxIntrinsicWidth) / 2 + _lean + jitter;
      canvas.drawParagraph(mouthPara, Offset(mouthX, eyesY + eyesPara.height * 0.9));
    }

    if (spec.thoughtDots) {
      final dots = '.' * (1 + (t / (kThoughtDotFrame.inMilliseconds / 1000)).floor() % 3);
      final p = cache.paragraph(dots, color: muted, fontSize: mouthSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      canvas.drawParagraph(p, Offset(eyesX + eyesPara.maxIntrinsicWidth + mouthSize * 0.4, eyesY - mouthSize * 0.2));
    }

    if (spec.clock) {
      final p = cache.paragraph(_clockLabel(), color: muted, fontSize: mouthSize * 0.7, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
      canvas.drawParagraph(p, Offset((size.width - p.maxIntrinsicWidth) / 2, eyesY + eyesPara.height * 1.9));
    }
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

  String _clockLabel() {
    // Wall-clock is genuinely time-of-day, not animation state, so it is the one
    // thing here that does not derive from the ticker.
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Sweeping arc on the bezel — one half of the honest wait cue.
  void _paintOrbit(Canvas canvas, Size size, double t) {
    final inset = math.min(size.width, size.height) * 0.06;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    if (rect.width <= 0 || rect.height <= 0) return;
    final sweep = 2 * math.pi * ((t % _orbitPeriod) / _orbitPeriod);
    canvas.drawArc(
      rect,
      sweep,
      math.pi / 3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tokens.globalFocus,
    );
  }

  /// `[ 12s ]` — the other half. Honest: it counts up from real elapsed time and
  /// never estimates a completion.
  void _paintElapsed(Canvas canvas, Size size) {
    final busy = busyFor;
    if (busy == null) return;
    final label = '[ ${busy.inSeconds}s ]';
    final fontSize = (size.height * 0.1).clamp(7.0, 16.0);
    final p = cache.paragraph(label, color: tokens.globalTextMuted, fontSize: fontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    canvas.drawParagraph(p, Offset((size.width - p.maxIntrinsicWidth) / 2, size.height - p.height - fontSize * 0.4));
  }

  @override
  bool shouldRepaint(ClideFacePainter old) =>
      old.state != state ||
      old.gaze != gaze ||
      old.lean != lean ||
      old.busyFor != busyFor ||
      old.rainFontSize != rainFontSize ||
      old.fontFamily != fontFamily ||
      // SurfaceTokens has no `==`, so identity is the correct comparison — a new
      // instance is only built on a theme change. Matches the existing painters.
      old.tokens != tokens ||
      !identical(old.field, field) ||
      !identical(old.cache, cache) ||
      !identical(old.clock, clock);
}
