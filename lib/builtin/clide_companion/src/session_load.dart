/// The weather: how hard the **primary** session is working (T-537, D-107).
///
/// Split out of `FaceSpec` because the face and the rain report different
/// subjects. D-107 commitment 5: the face is Clide's own state, the rain is the
/// primary session's load — the conditions he is sitting in. One input driving
/// both meant making the rain track the session would drag his expression along
/// with it, which is the confusion the amendment exists to remove.
///
/// Deliberately three coarse values rather than a continuous number. `busyStream`
/// is a boolean, and inventing gradations from a signal that has none would be a
/// gauge that looks precise and is not — the thing D-107 rules out when it bans
/// fake progress bars.
///
/// Flutter-free, like the face contract beside it.
library;

/// What the session is doing, as far as the rain is concerned.
enum SessionLoad {
  /// No session, or it has ended. Rain stops dead and the field drains, which is
  /// what lets the render loop park (D-107 commitment 4) — a dead session that
  /// keeps animating is the defect the power ladder exists to prevent.
  absent,

  /// A session exists and is idle. A drip: enough to show the surface is alive,
  /// little enough to ignore.
  calm,

  /// The session is busy.
  working,
}

/// Rain parameters for a load level.
class LoadSpec {
  const LoadSpec({required this.rainDensity, required this.rainSpeed});

  /// Concurrent streams **as a fraction of the grid's column count**; `1.0` is
  /// one stream per column on average.
  ///
  /// A fraction, not a count, because the strip is resizable: the context panel
  /// runs 220–1000px, which is 33 to 151 columns, and an absolute reads as two
  /// different states at the two ends of the drag range (T-533).
  final double rainDensity;

  /// Fall speed, cells per second.
  final double rainSpeed;

  /// Streams for a grid [columns] wide.
  int streamsFor(int columns) => (columns * rainDensity).round();
}

// Figures carried over unchanged from the per-state table they used to live in.
// They were chosen against rendered ladders at 420px and 1000px (T-533); this
// moved where they live, not what they are.
const _absent = LoadSpec(rainDensity: 0, rainSpeed: 0);
const _calm = LoadSpec(rainDensity: 0.05, rainSpeed: 4);
const _working = LoadSpec(rainDensity: 1.0, rainSpeed: 16);

/// How long a quiet strip keeps animating before it parks the render loop —
/// D-107 commitment 4's `dormant` rung (T-540).
///
/// Ten minutes is long enough that it never interrupts someone working and short
/// enough that a window left open overnight is not still drawing at dawn. The
/// user does not choose it: a knob here would only ever be turned up, and the
/// commitment is that the surface *demonstrably stops*.
const kDormantAfter = Duration(minutes: 10);

/// The rain recipe for [load].
LoadSpec loadSpecFor(SessionLoad load) => switch (load) {
  SessionLoad.absent => _absent,
  SessionLoad.calm => _calm,
  SessionLoad.working => _working,
};
