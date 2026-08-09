/// Clide companion face contract (T-521, D-107) — the published seam between the
/// face renderer (Epic A) and the state machine (Epic B).
///
/// Ported from DeskLock's `sim/face/index.html` STATES table, which is that
/// project's design source of truth for the same face on an ESP32 round display.
///
/// Flutter-free: pure Dart, runs under `dart test`. Deliberately holds **no
/// colours** — those come from theme tokens at paint time, so the table stays
/// reviewable as data and the file stays out of the Flutter dependency graph.
///
/// Epic B passes `state`, `gaze` and `busyFor`; everything else here is read by
/// the painter. Changing this contract is a negotiation on T-521, not a prop
/// added quietly to the widget.
library;

/// What the face is doing. Mapped from live session signals by Epic B (T-517).
enum FaceState {
  /// Nothing to read. Lids down, clock showing, rain barely drips.
  idle,

  /// You are typing — at Claude, or at Clide's own input.
  listening,

  /// Claude is thinking: busy, but no `partial-` item has arrived yet.
  pensive,

  /// A long turn. Dense rain plus an elapsed counter — DeskLock's rule is that a
  /// wait always shows an honest cue, never a bare face and never a fake bar.
  effort,

  /// Claude is streaming: busy, with `partial-` items arriving.
  speaking,

  /// Transient failure — an API error or a failed turn. Held for a beat, then
  /// back to [idle]. Distinct from [error], which means the session is gone.
  rage,

  /// The session died. Rain stops dead and the face dims.
  error,
}

/// Which way the pupils point — and, derived from it, which way the face leans.
///
/// In the chosen placement (T-514) the face is pinned to the left edge of the
/// context column, so the pane immediately to its left is the Claude
/// conversation: exactly the content it is fed. Gaze therefore encodes the data
/// flow rather than decorating it.
enum Gaze {
  /// No particular attention. Used by [FaceState.idle].
  none,

  /// Reading the conversation to its left.
  left,

  /// Looking at you — you addressed it directly.
  forward,

  /// Glancing at the detail view above/right.
  right,
}

/// Horizontal offset of the mouth from the eye centre, in logical pixels.
///
/// This is the whole lean mechanic: one number, animated rather than snapped, so
/// the transition *is* the acknowledgement (D-107). There is deliberately no
/// `lean` prop — two sources for one value can disagree.
extension GazeLean on Gaze {
  double get leanPx => switch (this) {
    Gaze.left => -8,
    Gaze.right => 8,
    Gaze.none || Gaze.forward => 0,
  };
}

/// The per-state drawing recipe. Const; one instance per [FaceState].
class FaceSpec {
  const FaceSpec({
    required this.eyes,
    required this.mouth,
    required this.rainStreams,
    required this.rainSpeed,
    this.blink = false,
    this.thoughtDots = false,
    this.talkCycle = false,
    this.jitter = false,
    this.elapsed = false,
    this.clock = false,
    this.opacity = 1,
  });

  /// The eye row, e.g. `-   -`. Always an eyes string — there is no alternate
  /// whole-line render path (see the `rage` note on the library docs).
  final String eyes;

  /// The mouth glyph, or `''` when hidden.
  final String mouth;

  /// Lids drop for [kBlinkHold] every [kBlinkMinGap]–[kBlinkMaxGap].
  final bool blink;

  /// Cycling `.` / `..` / `...` beside the head.
  final bool thoughtDots;

  /// Mouth runs [kTalkCycle] while speaking.
  final bool talkCycle;

  /// ±1px shake on the face group.
  final bool jitter;

  /// `[ Ns ]` counter — the wait cue. Driven by the widget's `busyFor`.
  ///
  /// DeskLock pairs this with a sweeping bezel arc. That arc is **not** ported
  /// (T-531): it encodes activity, and activity is already the rain's job — two
  /// glyph-free pixels saying the same thing, one of which reads as a smear at
  /// strip proportions. The counter stays because it says something the rain
  /// cannot: *how long*.
  final bool elapsed;

  /// `HH:MM` under the face.
  final bool clock;

  /// Number of concurrent rain streams. **This is the load signal** — the thing
  /// that tells you at a glance whether the session is idle or grinding.
  final int rainStreams;

  /// Rain fall speed, cells per second.
  final double rainSpeed;

  /// Face opacity; dimmed for [FaceState.error].
  final double opacity;
}

const _idle = FaceSpec(eyes: '-   -', mouth: r'\_/', blink: true, clock: true, rainStreams: 2, rainSpeed: 4);

const _listening = FaceSpec(eyes: 'O   O', mouth: 'o', blink: true, rainStreams: 16, rainSpeed: 7);

const _pensive = FaceSpec(eyes: '·   ·', mouth: '~', thoughtDots: true, rainStreams: 7, rainSpeed: 5);

const _effort = FaceSpec(eyes: '>   <', mouth: '~', jitter: true, elapsed: true, rainStreams: 40, rainSpeed: 16);

const _speaking = FaceSpec(eyes: '^   ^', mouth: 'o', blink: true, talkCycle: true, rainStreams: 14, rainSpeed: 9);

/// Brows down, hard flat mouth, agitated.
///
/// Deliberate deviation from DeskLock, which flips a table here via a 3-frame
/// kaomoji. Two of that sequence's glyphs (`︵` U+FE35 and `ノ` U+30CE — katakana)
/// are absent from both bundled monospace fonts, and rendering whole lines
/// through the eye slot would need a second render path for the least-seen
/// state. The scowl reuses the ordinary grammar; [jitter] carries the agitation.
const _rage = FaceSpec(eyes: '▼   ▼', mouth: '━', jitter: true, rainStreams: 34, rainSpeed: 20);

/// Rain stops completely — the visible half of the power-ladder contract.
const _error = FaceSpec(eyes: 'x   x', mouth: '-', rainStreams: 0, rainSpeed: 0, opacity: 0.45);

/// The drawing recipe for [state].
FaceSpec specFor(FaceState state) => switch (state) {
  FaceState.idle => _idle,
  FaceState.listening => _listening,
  FaceState.pensive => _pensive,
  FaceState.effort => _effort,
  FaceState.speaking => _speaking,
  FaceState.rage => _rage,
  FaceState.error => _error,
};

/// Mouth frames cycled while [FaceSpec.talkCycle] is set.
const kTalkCycle = <String>['o', 'O', '-', 'O', '=', 'o'];

/// Every non-space eye character is replaced with this while blinking.
const kBlinkChar = '_';

/// How long lids stay down.
const kBlinkHold = Duration(milliseconds: 130);

/// Blink interval is drawn uniformly from this range.
const kBlinkMinGap = Duration(milliseconds: 2600);
const kBlinkMaxGap = Duration(milliseconds: 6200);

/// One mouth frame of [kTalkCycle].
const kTalkFrame = Duration(milliseconds: 150);

/// One step of the `.` / `..` / `...` thought cycle.
const kThoughtDotFrame = Duration(milliseconds: 480);

/// Vertical bob applied to the whole face group, in every state.
const kBreathePeriod = Duration(milliseconds: 4500);
const kBreatheAmplitudePx = 9.0;

/// Every glyph the face may draw, verified present in **both** bundled
/// monospace fonts — JetBrains Mono and Fira Mono — with `fc-query`.
///
/// The mono face is user-selectable (D-101), so checking one font is not enough:
/// a glyph present in JetBrains but absent from Fira would render as tofu for
/// anyone who switched, and would silently break goldens and the monospace
/// advance width the rain grid assumes.
///
/// **Adding a glyph to the table means adding it here, and verifying it first:**
///
/// ```sh
/// fc-query --format='%{charset}\n' assets/fonts/fira_mono/FiraMono-Regular.ttf
/// ```
///
/// `face_state_test.dart` asserts the table only uses glyphs from this string,
/// so an unverified addition fails the suite rather than the render. That guard
/// exists because this bug class has already bitten twice: once on DeskLock's
/// katakana rain glyphs, and again on the kaomoji hidden inside `rage`.
const kVerifiedFaceGlyphs = r""" -_\/<>^~=.:[]0123456789sOox·▼━""";
