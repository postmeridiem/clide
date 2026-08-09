/// Mounts the Clide strip, or does not (T-527, D-107).
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

import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:flutter/widgets.dart';

class ClideStripHost extends StatelessWidget {
  const ClideStripHost({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanionStateBuilder(builder: (context, state) => state.stripVisible ? const ClideStrip() : const SizedBox.shrink());
  }
}
