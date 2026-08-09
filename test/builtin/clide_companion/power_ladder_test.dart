import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// D-107 commitment 4: the ladder is a contract, not an optimisation. A
/// continuously animated surface in an IDE must **prove it stops** — so every
/// rung here is asserted against the render loop actually parking, not against
/// it drawing less.
void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget sized(Widget child, {double width = 400, double height = 120}) => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    ),
  );

  /// Whether the render loop is running.
  bool ticking() => SchedulerBinding.instance.transientCallbackCount > 0;

  /// Advance real-ish time in frame-sized steps. Bounded — never
  /// `pumpAndSettle`, which would wait out a live ticker forever.
  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 33);
    for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
      await tester.pump(step);
    }
  }

  // Short enough to drive in a test, long enough that the field has time to
  // drain first. The production default is ten minutes; the point of making it
  // injectable is that a test which waits ten real minutes never runs, and a
  // rung nobody asserts is decoration.
  const soon = Duration(milliseconds: 300);

  group('active — busy and visible', () {
    testWidgets('a working session keeps the loop running', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.working, dormantAfter: Duration.zero)));
      await advance(tester, const Duration(seconds: 3));
      expect(ticking(), isTrue, reason: 'the loop parked while the session was working');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ambient — idle, recently active', () {
    testWidgets('a calm session still animates, sparsely', (tester) async {
      // Ambient is not a separate mechanism: it is `calm`, which is a real but
      // small density. The rung is asserted here so that if someone later makes
      // `calm` zero, this fails rather than the strip silently going still.
      expect(loadSpecFor(SessionLoad.calm).rainDensity, greaterThan(0));
      expect(loadSpecFor(SessionLoad.calm).rainDensity, lessThan(loadSpecFor(SessionLoad.working).rainDensity));

      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: Duration.zero)));
      await advance(tester, const Duration(seconds: 3));
      expect(ticking(), isTrue, reason: 'ambient stopped animating before it was asked to');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('dormant — quiet long enough', () {
    testWidgets('the loop parks', (tester) async {
      // THE assertion. Before dormancy existed this was impossible at rest:
      // `idle` blinks, and quiescence refused to park while any face animation
      // was live — so a strip left alone drew forever however empty the field.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 1));
      expect(ticking(), isTrue, reason: 'it should still be awake this early');

      await advance(tester, const Duration(seconds: 6));
      expect(ticking(), isFalse, reason: 'the loop never parked — the dormant rung is decoration');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('parks even while the session is working', (tester) async {
      // Deliberate: "working" with no change for ten minutes means a turn that
      // is producing nothing observable. The surface stops; the counter is
      // still there to say the turn is live.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.working, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 8));
      expect(ticking(), isFalse, reason: 'a busy-but-silent session animated forever');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the timer does not itself keep the loop alive', (tester) async {
      // The failure this rung exists to prevent: a periodic timer waking every
      // second to ask whether things are quiet. One-shot, so once it has fired
      // nothing is scheduled at all.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 6));
      expect(ticking(), isFalse);

      await advance(tester, const Duration(seconds: 5));
      expect(ticking(), isFalse, reason: 'something woke the loop back up on its own');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disabling dormancy keeps it awake', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: Duration.zero)));
      await advance(tester, const Duration(seconds: 8));
      expect(ticking(), isTrue, reason: 'Duration.zero should mean never sleep');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('waking', () {
    testWidgets('a change wakes it and it fills rather than pops', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 6));
      expect(ticking(), isFalse);

      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.working, dormantAfter: soon)));
      await tester.pump();
      expect(ticking(), isTrue, reason: 'a load change did not wake it');

      // Spawning is rate-limited, so a woken field ramps toward its target
      // instead of appearing whole — the difference between rain starting and
      // rain being pasted on.
      await advance(tester, const Duration(milliseconds: 100));
      expect(ticking(), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a face change wakes it too', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 6));
      expect(ticking(), isFalse);

      await tester.pumpWidget(sized(const ClideFace(state: FaceState.speaking, load: SessionLoad.calm, dormantAfter: soon)));
      await tester.pump();
      expect(ticking(), isTrue, reason: 'Clide started speaking into a parked loop');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('and goes back to sleep afterwards', (tester) async {
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.calm, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 6));
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.speaking, load: SessionLoad.calm, dormantAfter: soon)));
      await tester.pump();
      expect(ticking(), isTrue);

      // Generous on purpose. Going dormant drains rather than freezing, and at
      // `calm` the streams fall at four cells a second — an eight-row grid plus
      // the trail's cull margin takes about five seconds to clear, and each
      // stream carries its own jittered speed. A tight budget here would fail
      // for the drain being slow rather than for dormancy being broken.
      await advance(tester, const Duration(seconds: 12));
      expect(ticking(), isFalse, reason: 'waking once left it awake forever');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('night — unmounted', () {
    testWidgets('disposing leaves nothing scheduled', (tester) async {
      // Collapse, hide, disable and minimise all resolve to the widget being
      // gone, so this is the whole of the `night` rung: teardown must be clean.
      await tester.pumpWidget(sized(const ClideFace(state: FaceState.idle, load: SessionLoad.working, dormantAfter: soon)));
      await advance(tester, const Duration(seconds: 1));
      expect(ticking(), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(ticking(), isFalse, reason: 'the ticker outlived the widget');
      // A live dormancy timer would fail teardown here.
      await advance(tester, const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
