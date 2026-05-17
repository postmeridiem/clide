/// Tests for the DragResizeHandle widget.
library;

import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/kernel_fixture.dart';
import '../../../helpers/widget_harness.dart';

void main() {
  group('DragResizeHandle', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('horizontal drag adjusts the sidebar slot size', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(const LayoutPresetContribution(
        id: 'test-preset',
        displayName: 'Test',
        slots: [
          LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
          LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
        ],
      ));
      await tester.pumpWidget(harness(
        f,
        Center(
          child: SizedBox(
            width: 40,
            height: 200,
            child: DragResizeHandle(
              arrangement: arr,
              slot: Slots.sidebar,
              axis: Axis.horizontal,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(DragResizeHandle));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(arr.sizeOf(Slots.sidebar), 250);
    });

    testWidgets('contextPanel drag inverts the delta sign', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(const LayoutPresetContribution(
        id: 'test-preset',
        displayName: 'Test',
        slots: [
          LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
          LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
        ],
      ));
      await tester.pumpWidget(harness(
        f,
        Center(
          child: SizedBox(
            width: 40,
            height: 200,
            child: DragResizeHandle(
              arrangement: arr,
              slot: Slots.contextPanel,
              axis: Axis.horizontal,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(DragResizeHandle));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(50, 0)); // drag right → context shrinks
      await tester.pump();
      await gesture.up();
      expect(arr.sizeOf(Slots.contextPanel), 150);
    });

    testWidgets('hovered state flips the line colour without throwing', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(const LayoutPresetContribution(
        id: 'test-preset',
        displayName: 'Test',
        slots: [
          LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
          LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
        ],
      ));
      await tester.pumpWidget(harness(
        f,
        Center(
          child: SizedBox(
            width: 40,
            height: 200,
            child: DragResizeHandle(
              arrangement: arr,
              slot: Slots.sidebar,
              axis: Axis.horizontal,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Hover over the handle.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: tester.getCenter(find.byType(DragResizeHandle)));
      await tester.pump();
      // Move pointer away.
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
    });
  });
}
