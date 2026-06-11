/// Tests for ClideMarquee (T-150): static when the child fits, scrolls
/// (looped copy) when it overflows; clips its box.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_harness.dart';

Widget _boxed(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: width, height: 16, child: child),
  ),
);

Widget _reducedMotion(double width, Widget child) => MediaQuery(data: const MediaQueryData(disableAnimations: true), child: _boxed(width, child));

void main() {
  testWidgets('shows the child statically when it fits', (tester) async {
    await tester.pumpWidget(_boxed(300, const ClideMarquee(child: Text('short'))));
    await tester.pump();
    expect(find.text('short'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // tear down the ticker
  });

  testWidgets('renders a looped copy and runs without overflow when wider than the slot', (tester) async {
    await tester.pumpWidget(_boxed(40, const ClideMarquee(child: Text('a long status line that overflows the slot'))));
    await tester.pump(); // measure
    await tester.pump(const Duration(milliseconds: 100)); // advance the ticker
    expect(find.text('a long status line that overflows the slot'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); // dispose → stop ticker
  });

  testWidgets('a line that fits an ultrawide slot stays static, no scroll/overflow (T-241)', (tester) async {
    // The slot must really be 3440 wide — a SizedBox(3440) under the default
    // 800px surface would be clamped, so size the view first.
    setSurfaceSize(tester, 3440, height: 200);
    await tester.pumpWidget(_boxed(3440, const ClideMarquee(child: Text('a normal-length status line'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // would advance a ticker if one started
    // Fits the wide slot → a single static copy (not the looped duplicate), no overflow.
    expect(find.text('a normal-length status line'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion (disableAnimations) does not scroll; pumpAndSettle completes (T-284)', (tester) async {
    await tester.pumpWidget(_reducedMotion(40, const ClideMarquee(child: Text('a long status line that overflows the slot'))));
    // The ticker must never start, so the frame queue is quiescent — if the
    // marquee still ran its ticker, this would hang for the 10-minute default.
    await tester.pumpAndSettle();
    expect(find.text('a long status line that overflows the slot'), findsWidgets);
    // No looped second copy is built under reduced motion (single rendered copy).
    expect(find.text('a long status line that overflows the slot'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('toggling disableAnimations off lets an overflowing marquee scroll again (T-284)', (tester) async {
    const child = ClideMarquee(child: Text('a long status line that overflows the slot'));
    await tester.pumpWidget(_reducedMotion(40, child));
    await tester.pumpAndSettle(); // frozen, settles
    // Flip the flag off → ticker should start; the looped copy reappears.
    await tester.pumpWidget(_boxed(40, child));
    await tester.pump(); // measure
    await tester.pump(const Duration(milliseconds: 100)); // advance the ticker
    expect(find.text('a long status line that overflows the slot'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); // dispose → stop ticker
  });
}
