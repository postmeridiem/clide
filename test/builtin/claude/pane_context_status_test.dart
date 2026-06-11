/// Tests for the focus-driven status-bar slot item (T-150 / T-160): it
/// renders the focused pane's status widget and clears when focus moves
/// to a pane with no status; at a constrained width the slot never
/// overflows and ClideMarquee gets a bounded viewport.
library;

import 'package:clide/builtin/claude/src/pane_context_status.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

/// Wraps [child] in a Row with Flexible(loose), mirroring the layout that
/// StatusbarHost applies to left-side flex items (T-160), inside a
/// [SizedBox] of the given [width].
///
/// Deliberately does NOT use the shared [harness] here: that one mounts an
/// `Overlay(canSizeOverlay: true)` over a zero-size MediaQuery, which runs an
/// intrinsic-sizing pass and hands children unbounded width — so a `Flexible`
/// never bounds the marquee and this test could not observe the fix. We mount
/// the minimum theme/kernel tree under a tight, [Align]ed [SizedBox] so the
/// `Flexible` gets a real bounded width from the surrounding Row.
Widget _narrowRow(KernelFixture f, double width, Widget child) => Directionality(
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
            width: width,
            height: 24,
            child: Row(
              children: [
                Flexible(flex: 1, fit: FlexFit.loose, child: child),
                const SizedBox(width: 20), // simulated right-side items
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('renders the focused pane status, clears on focus change', (tester) async {
    await tester.pumpWidget(harness(f, const PaneContextStatusItem()));
    await tester.pump();
    expect(find.text('S'), findsNothing); // nothing focused

    final focus = f.services.focus;
    focus.setActive(slot: Slots.workspace, contributionId: 'pane.x');
    focus.setStatusWidget('pane.x', const Text('S', textDirection: TextDirection.ltr));
    await tester.pump();
    expect(find.text('S'), findsOneWidget);

    // Focus a pane with no status → the slot clears.
    focus.setActive(slot: Slots.workspace, contributionId: 'pane.y');
    await tester.pump();
    expect(find.text('S'), findsNothing);
  });

  // T-160: at a narrow bar width the slot must never overflow and
  // ClideMarquee must receive a bounded (scrollable) viewport.
  testWidgets('no RenderFlex overflow at narrow width — ClideMarquee is bounded', (tester) async {
    // A long status line similar to what T-154 added:
    // "opus 4.7 · default · 21k ctx · 10 skills" — roughly 280 px of text.
    const longStatus = Text('opus 4.7 · default · 21k ctx · 10 skills', textDirection: TextDirection.ltr, softWrap: false);

    // Pump at 200 px wide — narrower than the status content so the marquee
    // must receive a bounded viewport < content width and start scrolling.
    const barWidth = 200.0;
    await tester.pumpWidget(_narrowRow(f, barWidth, const PaneContextStatusItem()));
    await tester.pump(); // first frame — nothing focused yet

    final focus = f.services.focus;
    focus.setActive(slot: Slots.workspace, contributionId: 'pane.z');
    focus.setStatusWidget('pane.z', longStatus);
    await tester.pump(); // status widget appears
    await tester.pump(); // ClideMarquee _measure post-frame callback

    // 1. No overflow exception.
    expect(tester.takeException(), isNull);

    // 2. The ClideMarquee is in the tree.
    expect(find.byType(ClideMarquee), findsOneWidget);

    // 3. The ClideMarquee render box is bounded — its width must be less than
    //    barWidth (the slot shrinks to fit, not past the container).
    final marqueeSize = tester.getSize(find.byType(ClideMarquee));
    expect(marqueeSize.width, lessThan(barWidth));
    expect(marqueeSize.width, greaterThan(0));

    // Dispose the ticker by tearing down the widget tree.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no overflow when no status is active — slot is shrunk', (tester) async {
    const barWidth = 200.0;
    await tester.pumpWidget(_narrowRow(f, barWidth, const PaneContextStatusItem()));
    await tester.pump();

    // No focused pane → SizedBox.shrink path. No overflow, no marquee.
    expect(tester.takeException(), isNull);
    expect(find.byType(ClideMarquee), findsNothing);
  });
}
