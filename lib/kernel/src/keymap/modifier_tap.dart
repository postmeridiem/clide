/// Detects a double-tapped bare modifier (e.g. JetBrains "Search
/// Everywhere" = double-Shift). (T-341)
///
/// Headless and clock-injected: the caller (the global key handler) passes
/// the event time so it neither reads a clock nor consumes events. Feed it
/// every [KeyDownEvent]: a bare modifier press via [tap], any other key via
/// [reset] (an intervening key breaks the gesture, e.g. `Shift a Shift`).
library;

import 'key_chord.dart';

class ModifierTapTracker {
  ModifierTapTracker({this.window = const Duration(milliseconds: 350)});

  /// Max gap between the two taps to count as a double-tap.
  final Duration window;

  KeyModifier? _last;
  DateTime? _lastAt;

  /// Record a bare-modifier press at [now]. Returns the modifier when this
  /// press completes a double-tap of the *same* modifier within [window];
  /// otherwise records it as the first tap and returns null.
  KeyModifier? tap(KeyModifier m, DateTime now) {
    final last = _last;
    final lastAt = _lastAt;
    if (last == m && lastAt != null) {
      final gap = now.difference(lastAt);
      if (gap >= Duration.zero && gap <= window) {
        reset();
        return m;
      }
    }
    _last = m;
    _lastAt = now;
    return null;
  }

  /// Break the gesture — any non-modifier key press resets the tracker.
  void reset() {
    _last = null;
    _lastAt = null;
  }
}
