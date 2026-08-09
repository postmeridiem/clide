import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

/// Animation and wall-clock pinned for the same reasons as the face goldens —
/// see the note there.
const _frame = Duration(milliseconds: 1730);
const _clock = '04:20';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  goldenTest(
    'ClideStrip across the context panel width range',
    fileName: 'clide_strip_widths',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        // The context panel runs 220–1000px (layout_preset.dart:19). The narrow
        // end is where the bubble is dropped; the wide end is where the rain
        // has to keep spanning the strip rather than hugging the face.
        for (final (label, width) in const [('narrow-220', 220.0), ('mid-500', 500.0), ('wide-1000', 1000.0)])
          GoldenTestScenario(
            name: label,
            child: harness(
              f,
              SizedBox(
                width: width,
                child: const ClideStrip(
                  state: FaceState.effort,
                  busyFor: Duration(seconds: 12),
                  message: 'that commit touched two call sites, not one',
                  debugFreezeAt: _frame,
                  debugClockLabel: _clock,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  goldenTest(
    'ClideStrip states',
    fileName: 'clide_strip_states',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final (state, message) in const [
          (FaceState.idle, null),
          (FaceState.pensive, 'reading what you just asked for'),
          (FaceState.effort, 'this is the long kind of tool run'),
          (FaceState.speaking, 'two call sites, not one'),
        ])
          GoldenTestScenario(
            name: state.name,
            child: harness(
              f,
              SizedBox(
                width: 520,
                child: ClideStrip(
                  state: state,
                  busyFor: state == FaceState.effort ? const Duration(seconds: 12) : null,
                  message: message,
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
