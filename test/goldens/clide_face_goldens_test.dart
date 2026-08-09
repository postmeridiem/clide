import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

/// Both animation sources are pinned, or these images would differ every run:
///
/// * `debugFreezeAt` holds the ticker at a fixed instant. Everything cyclic —
///   breathe, blink, talk, thought dots, jitter — derives from it, so one
///   value fixes the whole frame. Chosen off a round number so the phases are
///   mid-cycle rather than all sitting at zero.
/// * `debugClockLabel` pins the idle wall-clock, which is genuinely time-of-day
///   and would otherwise change the image every minute.
const _frame = Duration(milliseconds: 1730);
const _clock = '04:20';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  goldenTest(
    'ClideFace states',
    fileName: 'clide_face_states',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final state in FaceState.values)
          GoldenTestScenario(
            name: state.name,
            child: harness(
              f,
              SizedBox(
                width: 320,
                height: 120,
                // Held at one load throughout so the grid varies by face alone —
                // the rain is a different axis now (T-537) and would otherwise
                // make every cell differ for the wrong reason.
                child: ClideFace(state: state, load: SessionLoad.calm, debugFreezeAt: _frame, debugClockLabel: _clock),
              ),
            ),
          ),
      ],
    ),
  );

  goldenTest(
    'ClideFace gaze and lean',
    fileName: 'clide_face_gaze',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final gaze in Gaze.values)
          GoldenTestScenario(
            name: gaze.name,
            child: harness(
              f,
              SizedBox(
                width: 320,
                height: 120,
                child: ClideFace(state: FaceState.pensive, load: SessionLoad.calm, gaze: gaze, debugFreezeAt: _frame, debugClockLabel: _clock),
              ),
            ),
          ),
      ],
    ),
  );

  goldenTest(
    'ClideFace across the context panel width range',
    fileName: 'clide_face_widths',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        // The context panel runs 220–1000px (layout_preset.dart:19) and the
        // chosen placement is a short strip, so both ends are pinned.
        for (final (label, width) in const [('narrow-220', 220.0), ('mid-500', 500.0), ('wide-1000', 1000.0)])
          GoldenTestScenario(
            name: label,
            child: harness(
              f,
              SizedBox(
                width: width,
                height: 110,
                // Full load here: the width range exists to check the rain
                // spreads, which needs rain.
                child: ClideFace(
                  state: FaceState.effort,
                  load: SessionLoad.working,
                  busyFor: const Duration(seconds: 12),
                  debugFreezeAt: _frame,
                  debugClockLabel: _clock,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
