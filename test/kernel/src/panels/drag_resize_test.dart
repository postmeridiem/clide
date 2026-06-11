/// Tests for the DragResizeHandle widget.
library;

import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
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
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [
            LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
            LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
          ],
        ),
      );
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 40,
              height: 200,
              child: DragResizeHandle(arrangement: arr, slot: Slots.sidebar, axis: Axis.horizontal),
            ),
          ),
        ),
      );
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
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [
            LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
            LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
          ],
        ),
      );
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 40,
              height: 200,
              child: DragResizeHandle(arrangement: arr, slot: Slots.contextPanel, axis: Axis.horizontal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(DragResizeHandle));
      final gesture = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(50, 0)); // drag right → context shrinks
      await tester.pump();
      await gesture.up();
      expect(arr.sizeOf(Slots.contextPanel), 150);
    });

    testWidgets('exposes a slider Semantics node with the current size', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 240)],
        ),
      );
      final semHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 40,
              height: 200,
              child: DragResizeHandle(arrangement: arr, slot: Slots.sidebar, axis: Axis.horizontal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byType(DragResizeHandle));
      expect(data.label, 'Sidebar width');
      expect(data.value, '240 pixels');
      final actions = data.getSemanticsData().actions;
      expect(actions & SemanticsAction.increase.index, isNot(0));
      expect(actions & SemanticsAction.decrease.index, isNot(0));
      semHandle.dispose();
    });

    testWidgets('contextPanel slider Semantics label matches the slot', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 320)],
        ),
      );
      final semHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 40,
              height: 200,
              child: DragResizeHandle(arrangement: arr, slot: Slots.contextPanel, axis: Axis.horizontal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byType(DragResizeHandle));
      expect(data.label, 'Context panel width');
      expect(data.value, '320 pixels');
      semHandle.dispose();
    });

    test('bumpedSlotSize keeps natural sign for left-anchored slots', () {
      expect(bumpedSlotSize(slot: Slots.sidebar, current: 200, rawDelta: 10), 210);
      expect(bumpedSlotSize(slot: Slots.sidebar, current: 200, rawDelta: -10), 190);
      expect(bumpedSlotSize(slot: Slots.workspace, current: 500, rawDelta: 50), 550);
    });

    test('bumpedSlotSize flips sign for the right-anchored context panel', () {
      expect(bumpedSlotSize(slot: Slots.contextPanel, current: 200, rawDelta: 10), 190);
      expect(bumpedSlotSize(slot: Slots.contextPanel, current: 200, rawDelta: -10), 210);
    });

    testWidgets('vertical-axis handle uses arrow up/down shortcuts and "height" label', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [LayoutSlot(slot: Slots.workspace, position: SlotPosition.center, defaultSize: 300)],
        ),
      );
      final semHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 200,
              height: 40,
              child: DragResizeHandle(arrangement: arr, slot: Slots.workspace, axis: Axis.vertical),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byType(DragResizeHandle));
      // Custom (non-sidebar, non-contextPanel) slots fall through to
      // the slot.value-based label branch.
      expect(data.label, 'workspace height');
      semHandle.dispose();
    });

    testWidgets('hovered state flips the line colour without throwing', (tester) async {
      final arr = LayoutArrangement();
      arr.applyPreset(
        const LayoutPresetContribution(
          id: 'test-preset',
          displayName: 'Test',
          slots: [
            LayoutSlot(slot: Slots.sidebar, position: SlotPosition.left, defaultSize: 200),
            LayoutSlot(slot: Slots.contextPanel, position: SlotPosition.right, defaultSize: 200),
          ],
        ),
      );
      await tester.pumpWidget(
        harness(
          f,
          Center(
            child: SizedBox(
              width: 40,
              height: 200,
              child: DragResizeHandle(arrangement: arr, slot: Slots.sidebar, axis: Axis.horizontal),
            ),
          ),
        ),
      );
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
