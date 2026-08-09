import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/strip_host.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  /// Persist a companion preference for real.
  ///
  /// Two traps in one line. The keys are project-scoped — a repo, not a
  /// machine, decides whether a second model may read its conversation — and a
  /// project-scoped write with no project open throws by design, so the fixture
  /// needs a project first. And both calls touch the filesystem, which has to
  /// happen inside [WidgetTester.runAsync]: real I/O awaited under the
  /// fake-async harness never completes and hangs the whole file.
  Future<void> store(WidgetTester tester, String key, Object value) async {
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await f.services.settings.set(key, value);
    });
  }

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

  group('seeding', () {
    testWidgets('renders the strip by default', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byType(ClideStrip), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a stored disable is honoured on first build', (tester) async {
      // The bus does not retain, so a host that only subscribed would show the
      // default until something happened to change — which, for a preference
      // nobody touches this session, is never. Seeding from the store is what
      // makes "off" survive a restart.
      await store(tester, kCompanionEnabledKey, false);
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byType(ClideStrip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a stored minimise is honoured on first build', (tester) async {
      await store(tester, kCompanionOpenKey, false);
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byType(ClideStrip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the bus drives it', () {
    testWidgets('an announced disable removes the strip', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byType(ClideStrip), findsOneWidget);

      publishCompanionState(f.services.messages, enabled: false, open: true, frequency: 'notable');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsNothing, reason: 'the host must follow the bus, not just its seed');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an announced minimise removes it, and re-opening brings it back', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      publishCompanionState(f.services.messages, enabled: true, open: false, frequency: 'notable');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsNothing);

      publishCompanionState(f.services.messages, enabled: true, open: true, frequency: 'notable');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an unrelated publisher on the same channel is ignored', (tester) async {
      // Channel names are not unique across publishers; the subscription is
      // addressed to both.
      await tester.pumpWidget(host());
      await tester.pump();
      f.services.messages.publish('someone.else', companionStateChannel, {'enabled': false});
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a partial announcement leaves the unmentioned field alone', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      f.services.messages.publish(clideCompanionPublisher, companionStateChannel, {'open': false});
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsNothing);

      f.services.messages.publish(clideCompanionPublisher, companionStateChannel, {'open': true});
      await tester.pump();
      await tester.pump();
      expect(find.byType(ClideStrip), findsOneWidget, reason: 'enabled was never mentioned and must not have been reset');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('lifecycle', () {
    testWidgets('unmounting cancels the subscription', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      // A live listener on a disposed State throws when it calls setState.
      publishCompanionState(f.services.messages, enabled: false, open: false, frequency: 'notable');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
