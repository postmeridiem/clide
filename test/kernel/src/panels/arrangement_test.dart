import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LayoutArrangement', () {
    test('applyPreset sets position + size + visibility per slot', () {
      final a = LayoutArrangement();
      a.applyPreset(classicPreset());
      expect(a.positionOf(Slots.sidebar), SlotPosition.left);
      expect(a.sizeOf(Slots.sidebar), 400);
      expect(a.minSizeOf(Slots.sidebar), 180);
      expect(a.maxSizeOf(Slots.sidebar), 400);
      expect(a.isVisible(Slots.workspace), true);
    });

    test('setSize clamps to min/max', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.setSize(Slots.sidebar, 50); // below min 180
      expect(a.sizeOf(Slots.sidebar), 180);
      a.setSize(Slots.sidebar, 10000); // above max 400
      expect(a.sizeOf(Slots.sidebar), 400);
    });

    test('setSize notifies listeners only when changing', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      var count = 0;
      a.addListener(() => count++);
      a.setSize(Slots.sidebar, 400); // already 400, no change
      expect(count, 0);
      a.setSize(Slots.sidebar, 260);
      expect(count, 1);
    });

    test('setVisible flips the flag', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      expect(a.isVisible(Slots.sidebar), true);
      a.setVisible(Slots.sidebar, false);
      expect(a.isVisible(Slots.sidebar), false);
    });

    test('registerSlotsInto populates a PanelRegistry', () {
      final a = LayoutArrangement();
      final r = PanelRegistry();
      final preset = classicPreset();
      a.registerSlotsInto(r, preset);
      expect(r.definitionFor(Slots.sidebar), isNotNull);
      expect(r.definitionFor(Slots.statusbar), isNotNull);
    });

    test('setCollapsed toggles collapsed state', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      expect(a.isCollapsed(Slots.sidebar), false);
      a.setCollapsed(Slots.sidebar, true);
      expect(a.isCollapsed(Slots.sidebar), true);
      expect(a.isVisible(Slots.sidebar), true);
    });

    test('toggleCollapsed flips collapsed flag', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.toggleCollapsed(Slots.sidebar);
      expect(a.isCollapsed(Slots.sidebar), true);
      a.toggleCollapsed(Slots.sidebar);
      expect(a.isCollapsed(Slots.sidebar), false);
    });

    test('enterFocusMode hides all slots except the focused one', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.enterFocusMode(Slots.workspace);
      expect(a.isInFocusMode, true);
      expect(a.focusModeSlot, Slots.workspace);
      expect(a.isVisible(Slots.workspace), true);
      expect(a.isVisible(Slots.sidebar), false);
      expect(a.isVisible(Slots.contextPanel), false);
    });

    test('exitFocusMode restores prior layout', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.setCollapsed(Slots.sidebar, true);
      a.setSize(Slots.contextPanel, 300);
      a.enterFocusMode(Slots.workspace);
      a.exitFocusMode();
      expect(a.isInFocusMode, false);
      expect(a.isVisible(Slots.sidebar), true);
      expect(a.isCollapsed(Slots.sidebar), true);
      expect(a.sizeOf(Slots.contextPanel), 300);
    });

    test('toggleFocusMode enters then exits', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.toggleFocusMode(Slots.workspace);
      expect(a.isInFocusMode, true);
      a.toggleFocusMode(Slots.workspace);
      expect(a.isInFocusMode, false);
      expect(a.isVisible(Slots.sidebar), true);
    });

    test('applyPreset clears focus mode', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.enterFocusMode(Slots.workspace);
      a.applyPreset(classicPreset());
      expect(a.isInFocusMode, false);
    });

    test('openEditor sets editorOpen', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      expect(a.editorOpen, false);
      a.openEditor();
      expect(a.editorOpen, true);
    });

    test('closeEditor clears editorOpen', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.openEditor();
      a.closeEditor();
      expect(a.editorOpen, false);
    });

    test('toggleEditor flips editorOpen', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.toggleEditor();
      expect(a.editorOpen, true);
      a.toggleEditor();
      expect(a.editorOpen, false);
    });

    test('setEditorRatio clamps to 0.15–0.70', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      a.setEditorRatio(0.05);
      expect(a.editorRatio, 0.15);
      a.setEditorRatio(0.90);
      expect(a.editorRatio, 0.70);
      a.setEditorRatio(0.40);
      expect(a.editorRatio, 0.40);
    });

    test('editorRatio defaults to 0.35', () {
      final a = LayoutArrangement()..applyPreset(classicPreset());
      expect(a.editorRatio, 0.35);
    });
  });
}
