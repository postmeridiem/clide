import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/builtin/clide_companion/src/strip_host.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget host() => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: const MediaQuery(
          data: MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 400,
              child: Column(
                children: [
                  Expanded(child: SizedBox()),
                  ClideStripHost(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  ClideFace face(WidgetTester tester) => tester.widget<ClideFace>(find.byType(ClideFace));

  group('the weather reaches the face', () {
    testWidgets('a busy announcement raises the load', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionLoad(f.services.messages, busy: true, busySinceMs: DateTime.now().millisecondsSinceEpoch);
      await tester.pump();
      await tester.pump();

      expect(face(tester).load, SessionLoad.working);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an idle announcement is calm, not absent', (tester) async {
      // The adapter only publishes while it is watching, so an announcement is
      // itself evidence a session exists. `absent` is the pre-answer default,
      // never something announced.
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionLoad(f.services.messages, busy: false);
      await tester.pump();
      await tester.pump();

      expect(face(tester).load, SessionLoad.calm);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('before any announcement the load is absent', (tester) async {
      // Park-by-default: until the ask is answered we do not know, and a
      // surface whose power behaviour is a contract should not animate on a
      // guess (D-107 commitment 4).
      await tester.pumpWidget(host());
      await tester.pump();
      expect(face(tester).load, SessionLoad.absent);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('asking for the current load', () {
    testWidgets('mounting asks, because the first announcement predates the widget', (tester) async {
      // Extensions activate before `runApp`, so the adapter's opening
      // announcement is always published into an empty room.
      var asked = 0;
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionLoadAskChannel).listen((_) => asked++);
      addTearDown(sub.cancel);

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();

      expect(asked, 1, reason: 'the strip mounted without asking what the session is doing');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the elapsed counter', () {
    testWidgets('runs from the stamped start, not from when the widget noticed', (tester) async {
      // The instant comes from the adapter. A widget that started counting when
      // it happened to see the prop change would under-report by however long
      // noticing took — here, by a whole minute.
      final startedAMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionLoad(f.services.messages, busy: true, busySinceMs: startedAMinuteAgo.millisecondsSinceEpoch);
      await tester.pump();
      await tester.pump();

      final busyFor = face(tester).busyFor;
      expect(busyFor, isNotNull);
      expect(busyFor!.inSeconds, greaterThanOrEqualTo(60), reason: 'the counter restarted instead of using the stamped start');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('clears when the turn ends rather than freezing', (tester) async {
      // A counter that stops but stays on screen reads as a turn still running.
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionLoad(f.services.messages, busy: true, busySinceMs: DateTime.now().millisecondsSinceEpoch);
      await tester.pump();
      await tester.pump();
      expect(face(tester).busyFor, isNotNull);

      publishCompanionLoad(f.services.messages, busy: false);
      await tester.pump();
      await tester.pump();
      expect(face(tester).busyFor, isNull, reason: 'the counter froze instead of clearing');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('advances while the turn runs', (tester) async {
      final start = DateTime.now();
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionLoad(f.services.messages, busy: true, busySinceMs: start.millisecondsSinceEpoch);
      await tester.pump();
      await tester.pump();
      final first = face(tester).busyFor!;

      // The host ticks once a second while busy — seconds are the counter's
      // granularity, so anything faster would be redraws nobody can read.
      await tester.pump(const Duration(seconds: 3));
      expect(face(tester).busyFor!, greaterThanOrEqualTo(first), reason: 'the counter stalled mid-turn');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('runs no timer while idle', (tester) async {
      // The other half of the same point: a 1Hz timer that ran all the time
      // would be exactly the sort of thing the power ladder exists to forbid.
      await tester.pumpWidget(host());
      await tester.pump();
      publishCompanionLoad(f.services.messages, busy: false);
      await tester.pump();
      await tester.pump();

      // Completes only if nothing is scheduling repeating work.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('teardown', () {
    testWidgets('a turn in flight does not leave a timer behind', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      publishCompanionLoad(f.services.messages, busy: true, busySinceMs: DateTime.now().millisecondsSinceEpoch);
      await tester.pump();
      await tester.pump();

      // An uncancelled periodic Timer fails the test binding at teardown.
      await tester.pumpWidget(const SizedBox());
      expect(find.byType(ClideStrip), findsNothing);
    });
  });
}
