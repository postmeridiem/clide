/// Mounts the Clide strip, or does not, and feeds it the weather (T-527, T-539).
///
/// Exists so `slot_host.dart` stays ignorant of the companion beyond "put this
/// here": the shell should not know what a kill switch is, and the companion
/// should not need the shell edited every time its visibility rules change.
///
/// Disabled means **gone**, not hidden — the 112px goes back to the detail view
/// (D-107 commitment 1, and the shape the user asked for: "off is off for the
/// repo"). Minimising is a different control with a different key (T-528), and
/// removes the strip just as completely; what differs is that the rail button
/// survives it, so there is something left to click.
library;

import 'dart:async';

import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:flutter/widgets.dart';

class ClideStripHost extends StatelessWidget {
  const ClideStripHost({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanionStateBuilder(builder: (context, state) => state.stripVisible ? _Strip(state: state) : const SizedBox.shrink());
  }
}

/// Turns a start instant into a running counter.
///
/// The widget below it deliberately does not time turns (the T-521 contract) —
/// it renders whatever `busyFor` it is handed, and a widget that inferred
/// elapsed time from when it happened to notice a prop change would drift by
/// however long noticing took. So the instant comes from the adapter, which
/// stamped it, and the *ticking* happens here.
///
/// One tick a second, only while a turn is running: the counter's granularity is
/// seconds, so anything faster is redraws nobody can read. While busy the face is
/// already animating at frame rate, so this adds nothing measurable; while idle
/// there is no timer at all, which is what keeps it out of the power ladder's way
/// (D-107 commitment 4).
class _Strip extends StatefulWidget {
  const _Strip({required this.state});

  final CompanionState state;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_Strip old) {
    super.didUpdateWidget(old);
    if (old.state.busySince != widget.state.busySince) _syncTimer();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _tick?.cancel();
    _tick = null;
    if (widget.state.busySince == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Elapsed for the current turn, or null when idle.
  ///
  /// Null rather than a frozen last value: a counter that stops but stays on
  /// screen reads as a turn still running, which is the opposite of what it
  /// would be saying.
  Duration? get _busyFor {
    final since = widget.state.busySince;
    if (since == null) return null;
    final elapsed = DateTime.now().difference(since);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  Widget build(BuildContext context) => ClideStrip(load: widget.state.load, busyFor: _busyFor);
}
