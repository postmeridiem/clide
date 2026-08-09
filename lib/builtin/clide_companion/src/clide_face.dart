/// The Clide companion face widget (T-525, D-107) — the shell around the
/// painter: one ticker, the reduced-motion gate, and an isolated repaint layer.
///
/// This completes Epic A. Its public surface is exactly the contract published
/// on T-521 — `state`, `gaze`, `busyFor` — and nothing else. If Epic B needs
/// more, that is a change negotiated on T-521 rather than a prop added quietly
/// here, so the two epics keep one shared definition of the seam.
library;

import 'package:clide/builtin/clide_companion/src/face_painter.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/glyph_cache.dart';
import 'package:clide/builtin/clide_companion/src/rain_field.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Rain glyph size. Small enough that a short strip still gets several rows of
/// fall, which is what makes density read as density.
const _rainFontSize = 11.0;

/// Seconds for the lean to travel between gaze positions. Long enough to read
/// as a movement, short enough not to lag the thing it is reacting to.
const _leanTravel = 0.22;

/// A glyph face whose expression tracks session state, over a rain field whose
/// density encodes load.
class ClideFace extends StatefulWidget {
  const ClideFace({
    super.key,
    required this.state,
    this.load = SessionLoad.calm,
    this.gaze = Gaze.none,
    this.busyFor,
    this.faceAlignX = 0,
    this.debugFreezeAt,
    this.debugClockLabel,
  });

  /// What Clide is doing. Driven by his own session (Epic D).
  final FaceState state;

  /// What the **primary** session is doing — the rain, not the face (D-107
  /// commitment 5, T-537).
  ///
  /// Two inputs rather than one because they report different subjects: he can
  /// be idle in a downpour, which is the ordinary case while a long tool run is
  /// going and he has nothing to say about it yet.
  final SessionLoad load;

  /// Which way the pupils point; also drives the lean.
  final Gaze gaze;

  /// How long the current turn has been running, for the `[ Ns ]` cue. Owned by
  /// the caller — the face does not time turns.
  final Duration? busyFor;

  /// Where the face sits horizontally: `-1` flush left, `0` centred, `1` flush
  /// right. **The rain always spans the full box.**
  ///
  /// Added to the T-521 contract by T-526. The chosen placement puts the face at
  /// the left of a wide strip with the speech bubble beside it, but the rain has
  /// to keep the whole width: density reads as how many columns are lit, and
  /// penning it into a narrow face region would cut ~45 columns to ~9 — the very
  /// thing that made a strip preferable to a rail (T-514).
  final double faceAlignX;

  /// Test seam: hold the animation at a fixed instant instead of running the
  /// ticker. Goldens of a live animation are flaky by construction, and sleeping
  /// to land on a frame is worse; this pins the frame outright.
  @visibleForTesting
  final Duration? debugFreezeAt;

  /// Test seam: pin the idle clock so a golden does not change every minute.
  @visibleForTesting
  final String? debugClockLabel;

  @override
  State<ClideFace> createState() => _ClideFaceState();
}

class _ClideFaceState extends State<ClideFace> with SingleTickerProviderStateMixin {
  /// Both the painter's `repaint:` source and its time source. The painter is
  /// not rebuilt per frame, so a plain field would go stale — see the painter's
  /// library docs.
  final ValueNotifier<Duration> _clock = ValueNotifier(Duration.zero);

  final GlyphCache _cache = GlyphCache();

  late final Ticker _ticker = createTicker(_tick);

  RainField? _field;
  int _columns = 0;
  int _rows = 0;

  Duration _last = Duration.zero;

  /// Current lean, eased toward the gaze's target so the transition reads as a
  /// movement rather than a snap (D-107).
  double _lean = 0;

  bool _reduced = false;

  bool get _frozen => widget.debugFreezeAt != null;

  @override
  void initState() {
    super.initState();
    _lean = widget.gaze.leanPx;
    if (_frozen) _clock.value = widget.debugFreezeAt!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != _reduced) {
      _reduced = reduced;
      _syncTicker();
    } else {
      _syncTicker();
    }
  }

  @override
  void didUpdateWidget(ClideFace old) {
    super.didUpdateWidget(old);
    if (_frozen) {
      _clock.value = widget.debugFreezeAt!;
      // A frozen face still needs its lean to reflect the gaze it was given.
      _lean = widget.gaze.leanPx;
    }
    // Density follows the *load*, so a static frame re-primes when the load
    // changes — otherwise it keeps the previous load's rain forever. A face
    // change alone no longer touches the field, which is the point of the split.
    if (!_ticking && old.load != widget.load) {
      _field = null;
      _ensureField(_columns, _rows);
    }
    _syncTicker();
  }

  /// Run only when motion is allowed, the frame is not pinned, and there is
  /// something to animate.
  ///
  /// The last clause is the widget half of D-107's power-ladder contract: an
  /// `error` face over a drained field has no moving parts, so the render loop
  /// parks itself rather than repainting an unchanging image forever.
  void _syncTicker() {
    final wantsMotion = !_reduced && !_frozen && !_isQuiescent;
    if (wantsMotion && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!wantsMotion && _ticker.isActive) {
      _ticker.stop();
    }
  }

  /// True when nothing on screen would change from one frame to the next.
  ///
  /// Both layers have to be still: a dimmed face over a raining field is
  /// animating, and so is a resting face while streams are draining.
  bool get _isQuiescent {
    final field = _field;
    if (field == null) return false;
    final spec = specFor(widget.state);
    final settled = (_lean - widget.gaze.leanPx).abs() < 0.01;
    return loadSpecFor(widget.load).rainDensity == 0 && field.isQuiescent && !spec.blink && !spec.talkCycle && !spec.thoughtDots && !spec.jitter && settled;
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) {
      _clock.value = elapsed;
      return;
    }

    final load = loadSpecFor(widget.load);
    _field?.tick(dt, targetStreams: load.streamsFor(_columns), speed: load.rainSpeed);

    // Ease the lean toward its target at a constant rate.
    final target = widget.gaze.leanPx;
    if ((_lean - target).abs() > 0.01) {
      final step = (16 / _leanTravel) * dt;
      _lean = (target - _lean).abs() <= step ? target : _lean + step * (target > _lean ? 1 : -1);
    }

    _clock.value = elapsed;
    if (_isQuiescent) _syncTicker();
  }

  /// Rebuild the field when the grid changes shape. Seeded per size so a rebuild
  /// at the same size is reproducible.
  void _ensureField(int columns, int rows) {
    if (_field != null && columns == _columns && rows == _rows) return;
    _columns = columns;
    _rows = rows;
    final field = RainField(columns: columns, rows: rows, seed: 0x5EED);
    if (!_ticking) _primeField(field);
    _field = field;
    _syncTicker();
  }

  /// True when the render loop will be running, and therefore filling the field
  /// on its own.
  bool get _ticking => !_reduced && !_frozen;

  /// Advance a fresh field to a steady state for a frame the ticker will never
  /// produce — a pinned golden, or reduced motion.
  ///
  /// Without this a static frame shows **no rain at all**, which drops the
  /// density signal — the one thing the field exists to convey. A reduced-motion
  /// user should still see that the session is busy; they just should not see it
  /// move.
  void _primeField(RainField field) {
    final load = loadSpecFor(widget.load);
    final target = load.streamsFor(field.columns);
    if (target == 0) return;
    const step = 1 / 30;
    // Long enough to actually reach the target, which is now width-dependent:
    // growth is capped at `spawnPerSecond`, so a wide strip at full density needs
    // seconds, and a fixed budget silently under-fills it. Bounded so this stays
    // cheap enough to run during build.
    final seconds = (target / RainField.spawnPerSecond + 2.0).clamp(1.0, 8.0);
    for (var t = 0.0; t < seconds; t += step) {
      field.tick(step, targetStreams: target, speed: load.rainSpeed);
    }
  }

  String _clockLabel() {
    final pinned = widget.debugClockLabel;
    if (pinned != null) return pinned;
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Screen-reader label. One stable phrase per state — a reader should hear
  /// "Clide: thinking", never a stream of box-drawing characters (D-20).
  String _semanticsLabel(BuildContext context) {
    final key = switch (widget.state) {
      FaceState.idle => 'idle',
      FaceState.listening => 'listening',
      FaceState.pensive => 'thinking',
      FaceState.effort => 'working',
      FaceState.speaking => 'replying',
      FaceState.rage => 'error',
      FaceState.error => 'disconnected',
    };
    const english = {
      'idle': 'Clide is idle',
      'listening': 'Clide is listening',
      'thinking': 'Clide is thinking',
      'working': 'Clide is working',
      'replying': 'Clide is replying',
      'error': 'Clide hit an error',
      'disconnected': 'Clide is disconnected',
    };
    return ClideSettings.i18n.string(context, 'face.semantics.$key', namespace: 'builtin.clide-companion', placeholder: english[key]!);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final fontFamily = ClideSettings.fonts.monoOf(context);

    return Semantics(
      label: _semanticsLabel(context),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
            final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
            if (width <= 0 || height <= 0) return const SizedBox.shrink();

            final cell = _cache.metrics(fontSize: _rainFontSize, fontFamily: fontFamily, fontFamilyFallback: clideMonoFamilyFallback);
            final columns = cell.width > 0 ? (width / cell.width).floor() : 0;
            final rows = cell.height > 0 ? (height / cell.height).ceil() : 0;
            _ensureField(columns, rows);

            // The second RepaintBoundary in the repo (the terminal render object
            // is the first). Without it a repaint of this layer dirties its
            // ancestors — 30 times a second, inside a panel that also hosts a
            // detail view.
            return RepaintBoundary(
              child: CustomPaint(
                size: Size(width, height),
                painter: ClideFacePainter(
                  clock: _clock,
                  state: widget.state,
                  gaze: widget.gaze,
                  field: _field!,
                  cache: _cache,
                  tokens: tokens,
                  fontFamily: fontFamily,
                  fontFamilyFallback: clideMonoFamilyFallback,
                  busyFor: widget.busyFor,
                  lean: _lean,
                  clockLabel: _clockLabel(),
                  faceAlignX: widget.faceAlignX,
                  rainFontSize: _rainFontSize,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
