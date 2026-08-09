import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/strip_host.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// The `night` rung for a minimised window (T-541, D-107 commitment 4). The one
/// case collapse and hide do not already cover, because a minimised window keeps
/// its tree mounted and its tickers running.
void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());

  tearDown(() async {
    // Leave the app on screen for whatever runs next.
    f.services.lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await f.dispose();
  });

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

  bool ticking() => SchedulerBinding.instance.transientCallbackCount > 0;

  /// Put the strip in a state that is definitely animating.
  Future<void> makeItRain(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    publishCompanionLoad(f.services.messages, busy: true, busySinceMs: DateTime.now().millisecondsSinceEpoch);
    await tester.pump();
    await tester.pump();
    expect(ticking(), isTrue, reason: 'the strip was not animating to begin with');
  }

  Future<void> setLifecycle(WidgetTester tester, AppLifecycleState state) async {
    f.services.lifecycle.didChangeAppLifecycleState(state);
    await tester.pump();
    await tester.pump();
  }

  group('minimising', () {
    testWidgets('stops the render loop', (tester) async {
      await makeItRain(tester);
      await setLifecycle(tester, AppLifecycleState.hidden);
      expect(ticking(), isFalse, reason: 'the strip kept animating into a minimised window');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('restoring starts it again', (tester) async {
      await makeItRain(tester);
      await setLifecycle(tester, AppLifecycleState.hidden);
      expect(ticking(), isFalse);

      await setLifecycle(tester, AppLifecycleState.resumed);
      expect(ticking(), isTrue, reason: 'the strip stayed frozen after the window came back');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('restores rather than restarts — the strip is never rebuilt', (tester) async {
      // The requirement is that coming back continues, not that it reseeds and
      // looks like the rain just started. Muting via TickerMode leaves the
      // element — and therefore the field — exactly where it was; unmounting
      // would not.
      await makeItRain(tester);
      final before = tester.element(find.byType(ClideStrip));

      await setLifecycle(tester, AppLifecycleState.hidden);
      expect(find.byType(ClideStrip), findsOneWidget, reason: 'suspending must not unmount the strip');

      await setLifecycle(tester, AppLifecycleState.resumed);
      expect(identical(tester.element(find.byType(ClideStrip)), before), isTrue, reason: 'the strip was rebuilt, so its field started over');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('losing focus is not being minimised', () {
    testWidgets('inactive keeps animating', (tester) async {
      // On desktop, clicking another application reports `inactive` while clide
      // stays fully visible beside it. Freezing then would stop a window the
      // user is looking straight at — worse than the problem being solved.
      await makeItRain(tester);
      await setLifecycle(tester, AppLifecycleState.inactive);
      expect(ticking(), isTrue, reason: 'losing focus froze a visible window');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the preference', () {
    testWidgets('off keeps it animating while minimised', (tester) async {
      // app.companion.suspendWhenMinimised has existed since T-527 and until now
      // was read by nobody. Off is a legitimate choice on a desktop that does
      // not care about the battery.
      await tester.runAsync(() async {
        await f.services.settings.set(kCompanionSuspendWhenMinimisedKey, false);
      });

      await makeItRain(tester);
      await setLifecycle(tester, AppLifecycleState.hidden);
      expect(ticking(), isTrue, reason: 'the preference was ignored');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('on is the default', (tester) async {
      await makeItRain(tester);
      await setLifecycle(tester, AppLifecycleState.hidden);
      expect(ticking(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
