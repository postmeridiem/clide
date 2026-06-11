/// Widget tests for `lib/widgets/src/clide_tooltip.dart` — hover-driven
/// OverlayEntry that respects showDelay, places itself below the target by
/// default, and flips above when the screen is short on space below.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideTooltip', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('tooltip appears after showDelay on hover and hides on exit', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          const Align(
            alignment: Alignment.topLeft,
            child: ClideTooltip(
              message: 'hello',
              showDelay: Duration(milliseconds: 10),
              child: SizedBox(width: 40, height: 20, key: ValueKey('target')),
            ),
          ),
        ),
      );

      // Not yet hovering — tooltip text is not in the tree.
      expect(find.text('hello'), findsNothing);

      // Move a mouse pointer over the target.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
      await tester.pump();

      // Let the showDelay elapse and the overlay insert.
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('hello'), findsOneWidget);

      // Hover out — overlay entry is removed synchronously.
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pump();
      expect(find.text('hello'), findsNothing);
    });

    testWidgets('mouse-exit before showDelay elapses suppresses the overlay', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          const Align(
            alignment: Alignment.topLeft,
            child: ClideTooltip(
              message: 'late',
              showDelay: Duration(milliseconds: 50),
              child: SizedBox(width: 40, height: 20, key: ValueKey('target')),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
      await tester.pump(const Duration(milliseconds: 10));

      // Exit before the delay completes.
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('late'), findsNothing);
    });

    testWidgets('places tooltip above the target when little space below', (tester) async {
      // Shrink the test view so the target sits near the bottom edge.
      tester.view.physicalSize = const Size(400, 100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        harness(
          f,
          const Align(
            alignment: Alignment.bottomLeft,
            child: ClideTooltip(
              message: 'above',
              showDelay: Duration(milliseconds: 1),
              child: SizedBox(width: 40, height: 20, key: ValueKey('target')),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('above'), findsOneWidget);

      // The Positioned ancestor of the tooltip uses `bottom:` (above-mode),
      // not `top:`, when there isn't enough room below.
      final positioned = tester.widget<Positioned>(find.ancestor(of: find.text('above'), matching: find.byType(Positioned)));
      expect(positioned.bottom, isNotNull);
      expect(positioned.top, isNull);
    });

    testWidgets('re-entering after exit shows the tooltip again (replaces overlay entry)', (tester) async {
      await tester.pumpWidget(
        harness(
          f,
          const Align(
            alignment: Alignment.topLeft,
            child: ClideTooltip(
              message: 'again',
              showDelay: Duration(milliseconds: 5),
              child: SizedBox(width: 40, height: 20, key: ValueKey('target')),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);

      // First hover cycle.
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('again'), findsOneWidget);

      // Exit.
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pump();
      expect(find.text('again'), findsNothing);

      // Re-enter — _show takes the `_entry?.remove()` branch (entry is null
      // now, but the rebuild proves the overlay path is re-traversed).
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('again'), findsOneWidget);
    });
  });
}
