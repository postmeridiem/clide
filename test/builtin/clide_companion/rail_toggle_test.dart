import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/companion_state.dart';
import 'package:clide/builtin/clide_companion/src/rail_toggle.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  /// Persist a preference — project-scoped, so the fixture needs a project, and
  /// real I/O, so it has to run outside the fake clock.
  Future<void> store(WidgetTester tester, String key, Object value) async {
    await tester.runAsync(() async {
      await f.services.settings.setProjectDir(f.tempDir);
      await f.services.settings.set(key, value);
    });
  }

  /// The rail as the status bar builds it: two ordinary tabs, then whatever the
  /// companion contributes.
  Widget rail() => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              height: 40,
              child: CompanionStateBuilder(
                builder: (ctx, state) => ClideIconRail(
                  items: [
                    ClideIconRailItem(id: 'tickets', icon: PhosphorIcons.byName('ticket'), tooltip: 'Tickets'),
                    ClideIconRailItem(id: 'graph', icon: PhosphorIcons.byName('graph'), tooltip: 'Graph'),
                  ],
                  activeId: 'tickets',
                  onSelect: (_) {},
                  toggles: [?companionRailToggle(ctx, state)],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Finder toggle() => find.bySemanticsLabel(RegExp('Clide'));

  group('presence', () {
    testWidgets('sits at the end of the rail, after the tabs', (tester) async {
      await tester.pumpWidget(rail());
      await tester.pump();
      expect(toggle(), findsOneWidget);
      // Reads as the last member of the tab family — same treatment, same
      // spacing, last position (the placement the product owner settled on).
      expect(tester.getCenter(toggle()).dx, greaterThan(tester.getCenter(find.bySemanticsLabel('Graph')).dx));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is absent when the companion is disabled for the repo', (tester) async {
      // A dead button only settings can revive is worse than no button, and
      // "off is off for the repo" means leaving no trace in the chrome.
      await store(tester, kCompanionEnabledKey, false);
      await tester.pumpWidget(rail());
      await tester.pump();
      expect(toggle(), findsNothing);
      expect(find.bySemanticsLabel('Tickets'), findsOneWidget, reason: 'the tabs must be unaffected');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('survives being minimised — it is the way back', (tester) async {
      await store(tester, kCompanionOpenKey, false);
      await tester.pumpWidget(rail());
      await tester.pump();
      expect(toggle(), findsOneWidget, reason: 'the control that restores Clide cannot vanish with him');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('it toggles rather than selects', () {
    testWidgets('tapping asks for the opposite state without touching the tabs', (tester) async {
      await tester.pumpWidget(rail());
      await tester.pump();

      // Never `await sub.cancel()` in a widget-test body: the future resolves
      // on a microtask the fake clock only drains on pump, so awaiting it hangs
      // the file. Tear it down instead.
      final asks = <Object?>[];
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionSetChannel).listen((m) => asks.add(m.data['open']));
      addTearDown(sub.cancel);

      await tester.tap(toggle());
      await tester.pump();
      await tester.pump();

      expect(asks, [false], reason: 'open -> minimise');
      // It publishes rather than writing: the extension owns persistence, so a
      // tap alone must not have changed the stored preference.
      expect(f.services.settings.get<bool>(kCompanionOpenKey), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('follows the announced state and asks the other way once minimised', (tester) async {
      await tester.pumpWidget(rail());
      await tester.pump();

      publishCompanionState(f.services.messages, enabled: true, open: false, frequency: 'notable');
      await tester.pump();
      await tester.pump();

      final asks = <Object?>[];
      final sub = f.services.messages.subscribe(publisher: clideCompanionPublisher, channel: companionSetChannel).listen((m) => asks.add(m.data['open']));
      addTearDown(sub.cancel);
      await tester.tap(toggle());
      await tester.pump();
      await tester.pump();

      expect(asks, [true], reason: 'minimised -> restore');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disappears when an announcement disables the companion', (tester) async {
      await tester.pumpWidget(rail());
      await tester.pump();
      expect(toggle(), findsOneWidget);

      publishCompanionState(f.services.messages, enabled: false, open: true, frequency: 'notable');
      await tester.pump();
      await tester.pump();
      expect(toggle(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('accessibility', () {
    testWidgets('announces as a toggle, not as a selected tab', (tester) async {
      // A reader told this was "selected" would understand turning Clide on as
      // having switched away from the current view (D-20).
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(rail());
      await tester.pump();

      expect(
        tester.getSemantics(toggle()),
        matchesSemantics(
          label: 'Minimise Clide',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );

      // A tab beside it keeps the selected semantics — the two must not have
      // converged on one role.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tickets')),
        matchesSemantics(
          label: 'Tickets',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );

      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the label describes the action and follows the state', (tester) async {
      await tester.pumpWidget(rail());
      await tester.pump();
      expect(find.bySemanticsLabel('Minimise Clide'), findsOneWidget);

      publishCompanionState(f.services.messages, enabled: true, open: false, frequency: 'notable');
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Show Clide'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
