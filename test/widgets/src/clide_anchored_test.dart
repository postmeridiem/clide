/// Tests for ClideAnchoredOverlay (D-88): controller-driven insert/remove,
/// barrier + Escape dismissal, centered mode, and clean dispose.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideAnchoredOverlay', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    Widget host(ClideOverlayController c, ValueNotifier<bool> present, {bool barrier = true, bool centered = false}) {
      return harness(
        f,
        ValueListenableBuilder<bool>(
          valueListenable: present,
          builder: (_, show, __) => show
              ? Align(
                  alignment: Alignment.center,
                  child: ClideAnchoredOverlay(
                    controller: c,
                    barrier: barrier,
                    centered: centered,
                    autoFlip: false,
                    anchor: const SizedBox(width: 60, height: 24, child: ClideText('anchor')),
                    overlayBuilder: (_, __) => const SizedBox(width: 120, height: 60, child: ClideText('panel')),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    testWidgets('open inserts the panel; close removes it', (tester) async {
      final c = ClideOverlayController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, ValueNotifier(true)));
      expect(find.text('panel'), findsNothing);
      c.open();
      await tester.pump();
      expect(find.text('panel'), findsOneWidget);
      c.close();
      await tester.pump();
      expect(find.text('panel'), findsNothing);
    });

    testWidgets('barrier tap closes', (tester) async {
      final c = ClideOverlayController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, ValueNotifier(true)));
      c.open();
      await tester.pump();
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(c.isOpen, isFalse);
      expect(find.text('panel'), findsNothing);
    });

    testWidgets('Escape closes', (tester) async {
      final c = ClideOverlayController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, ValueNotifier(true)));
      c.open();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c.isOpen, isFalse);
    });

    testWidgets('centered mode renders the panel', (tester) async {
      final c = ClideOverlayController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c, ValueNotifier(true), centered: true));
      c.open();
      await tester.pump();
      expect(find.text('panel'), findsOneWidget);
    });

    testWidgets('unmounting the host while open removes the entry without crashing', (tester) async {
      final c = ClideOverlayController();
      addTearDown(c.dispose);
      final present = ValueNotifier(true);
      await tester.pumpWidget(host(c, present));
      c.open();
      await tester.pump();
      expect(find.text('panel'), findsOneWidget);
      present.value = false; // unmount ClideAnchoredOverlay -> dispose removes entry
      await tester.pump(); // rebuild host (unmount + dispose)
      await tester.pump(); // overlay rebuild reflects the removed entry
      expect(find.text('panel'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
