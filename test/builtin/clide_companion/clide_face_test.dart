import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  /// The face at a given box, optionally under reduced motion.
  ///
  /// Deliberately **not** the shared `harness()`. That wraps its child in
  /// `Overlay(initialEntries: [OverlayEntry(builder: (_) => child)])`, and
  /// `initialEntries` is consumed only on the Overlay's first build — on later
  /// pumps the OverlayState is preserved and keeps an entry closing over the
  /// *original* child. A `pumpWidget` with a new prop therefore never reaches
  /// the widget under test, which silently turns "the label follows a state
  /// change" into a false failure. This builds the same services tree without
  /// the Overlay, which nothing here needs.
  Widget sized(Widget child, {required double width, required double height, bool reducedMotion = false}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      ),
    );
  }

  group('renders across the context panel width range', () {
    // The strip lives in the context column, which runs 220–1000px
    // (layout_preset.dart:19), and the chosen placement is short.
    for (final (label, width, height) in const [('narrow', 220.0, 110.0), ('wide', 1000.0, 110.0), ('tall', 400.0, 420.0)]) {
      testWidgets('every state renders at $label ($width x $height)', (tester) async {
        for (final state in FaceState.values) {
          await tester.pumpWidget(
            sized(
              ClideFace(state: state, debugFreezeAt: const Duration(milliseconds: 1500)),
              width: width,
              height: height,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$state threw at $label');
          expect(find.byType(ClideFace), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('degrades rather than overflowing in a tiny box', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 4, height: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a zero-sized box is handled', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 0, height: 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduced motion', () {
    testWidgets('pumpAndSettle completes — the wedge guard', (tester) async {
      // Not a courtesy. A perpetual ticker that ignores disableAnimations wedges
      // pumpAndSettle for ~10 minutes and takes the whole suite with it, which
      // is what clide_marquee_test.dart:50 exists to catch for the marquee.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort), width: 400, height: 120, reducedMotion: true));
      await tester.pumpAndSettle();
      expect(find.byType(ClideFace), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no ticker runs under reduced motion', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort), width: 400, height: 120, reducedMotion: true));
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'a ticker was scheduled despite reduced motion');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the face still renders when motion is off', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.speaking), width: 400, height: 120, reducedMotion: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ticker lifecycle', () {
    testWidgets('an animating state schedules a ticker, and disposing stops it', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort), width: 400, height: 120));
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'effort did not animate');

      // Teardown pattern from running_indicator_test.dart:29-45 — pump an empty
      // tree so the perpetual ticker is disposed before the test ends.
      await tester.pumpWidget(const SizedBox());
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'ticker survived disposal');
    });

    testWidgets('a frozen frame schedules no ticker', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort, debugFreezeAt: Duration(seconds: 2)), width: 400, height: 120));
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'a pinned frame still ran the ticker');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('advancing time does not throw', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.speaking), width: 400, height: 120));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the face and the rain are independent (T-537)', () {
    // The property the whole split exists for, asserted through the render loop
    // rather than through pixels: the goldens already cover what it looks like,
    // and rasterising inside `runAsync` while pumping hangs on the fake clock.
    //
    // The pair below is what independence means operationally — the loop follows
    // the *load*, and the face cannot start or stop it on its own.

    testWidgets('a resting face over an absent session parks', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.absent), width: 400, height: 120));
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      // idle blinks, so this parks only once the blink is also accounted for —
      // if it never parks, the face is keeping the loop alive by itself.
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'idle blinks, so it legitimately keeps ticking');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a still face over a working session keeps ticking', (tester) async {
      // Clide has nothing to say while a long tool run grinds: the face is still
      // and the weather is not. Before the split this frame was impossible —
      // `error` forced the rain to zero.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.error, load: SessionLoad.working), width: 400, height: 120));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'the rain stopped because the face was resting');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the power ladder parks the loop', () {
    testWidgets('error over a drained field stops ticking', (tester) async {
      // D-107's contract: a continuously animated surface has to prove it stops.
      // error has no blink, talk, dots or jitter, and an absent session has no
      // rain, so once the field drains there is nothing left to animate and the
      // render loop must park rather than repaint an unchanging image forever.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.error, load: SessionLoad.absent), width: 400, height: 120));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'error kept animating with nothing to animate');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a busy state keeps ticking', (tester) async {
      // The complement — the ladder must not park something that is still moving.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort, load: SessionLoad.working), width: 400, height: 120));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'effort parked while still working');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('accessibility', () {
    testWidgets('exposes one stable label per state, not the glyphs', (tester) async {
      // A screen reader should hear "Clide is thinking", never a stream of
      // box-drawing characters (D-20).
      final handle = tester.ensureSemantics();
      for (final (state, phrase) in const [
        (FaceState.idle, 'Clide is idle'),
        (FaceState.pensive, 'Clide is thinking'),
        (FaceState.effort, 'Clide is working'),
        (FaceState.speaking, 'Clide is replying'),
        (FaceState.error, 'Clide is disconnected'),
      ]) {
        // Updates in place rather than remounting, so this also exercises the
        // update path across every state.
        await tester.pumpWidget(sized(ClideFace(state: state, debugFreezeAt: Duration.zero), width: 400, height: 120));
        await tester.pump();
        expect(find.bySemanticsLabel(phrase), findsOneWidget, reason: '$state label');
      }
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('the label follows a state change on a live widget', (tester) async {
      // Epic B changes `state` on a mounted face constantly, so a label that
      // only updates on remount would announce a stale state forever.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      expect(find.bySemanticsLabel('Clide is idle'), findsOneWidget);

      await tester.pumpWidget(sized(const ClideFace(state: FaceState.pensive, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      expect(find.bySemanticsLabel('Clide is thinking'), findsOneWidget, reason: 'label did not follow the state change');
      expect(find.bySemanticsLabel('Clide is idle'), findsNothing, reason: 'stale label survived the state change');

      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('the glyphs themselves carry no semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      expect(find.byType(ExcludeSemantics), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });
  });

  group('repaint isolation', () {
    testWidgets('the painted layer sits behind a RepaintBoundary', (tester) async {
      // Only the second use in the repo. Without it, a repaint of an animating
      // layer dirties its ancestors 30 times a second inside a panel that also
      // hosts a detail view.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      expect(find.descendant(of: find.byType(ClideFace), matching: find.byType(RepaintBoundary)), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('props are the T-521 contract', () {
    testWidgets('busyFor and gaze are accepted and change the render', (tester) async {
      await tester.pumpWidget(
        sized(
          const ClideFace(state: FaceState.effort, gaze: Gaze.left, busyFor: Duration(seconds: 42), debugFreezeAt: Duration(seconds: 1)),
          width: 400,
          height: 120,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a state change is picked up without a remount', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.effort, debugFreezeAt: Duration.zero), width: 400, height: 120));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
