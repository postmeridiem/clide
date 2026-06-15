/// Detects a double-tapped bare modifier (e.g. JetBrains "Search
/// Everywhere" = double-Shift). (T-341)
///
/// A "tap" is a clean press-and-release: no other key may go down while the
/// modifier is held, otherwise the press was a chord (`Shift+;` typing a
/// colon) and must not count (T-409). The gesture therefore completes on the
/// second clean *release*, never on a key-down — at down time it's unknowable
/// whether the press will stay bare.
///
/// Headless and clock-injected: the caller (the root shell's raw-keyboard
/// handler) passes the event time so it neither reads a clock nor consumes
/// events. Feed every [KeyDownEvent] to `down` and every [KeyUpEvent] to
/// `up`, passing the event's [KeyModifier] (null for non-modifier keys).
library;

import 'key_chord.dart';

class ModifierTapTracker {
  ModifierTapTracker({this.window = const Duration(milliseconds: 350)});

  /// Max gap between the two tap releases to count as a double-tap.
  final Duration window;

  /// Modifier currently held whose press is still bare (no chorded key yet).
  KeyModifier? _pressing;

  /// Modifier of the last completed clean tap, arming the double-tap.
  KeyModifier? _armed;
  DateTime? _armedAt;

  /// Record a key press. A non-modifier key ([mod] == null) — or any key
  /// landing while a modifier is already held — is a chord: it dirties the
  /// held press and breaks the armed gesture.
  void down(KeyModifier? mod) {
    if (mod == null || _pressing != null) {
      _pressing = null;
      _disarm();
      return;
    }
    _pressing = mod;
  }

  /// Record a key release at [now]. Returns the modifier when this release
  /// completes a double-tap: the second clean tap of the *same* modifier
  /// within [window] of the first tap's release.
  KeyModifier? up(KeyModifier? mod, DateTime now) {
    if (mod == null) return null;
    final pressing = _pressing;
    _pressing = null;
    if (pressing != mod) return null; // press went dirty (chorded) or stale
    if (_armed == mod && _armedAt != null) {
      final gap = now.difference(_armedAt!);
      if (gap >= Duration.zero && gap <= window) {
        _disarm();
        return mod;
      }
    }
    _armed = mod;
    _armedAt = now;
    return null;
  }

  void _disarm() {
    _armed = null;
    _armedAt = null;
  }
}
