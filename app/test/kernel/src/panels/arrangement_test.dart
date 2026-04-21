import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LayoutArrangement', () {
    test('applyPreset sets position + size + visibility per slot', () {
      final a = LayoutArrangement();
      a.applyPreset(classicPreset());
      expect(a.positionOf(Slots.sidebar), SlotPosition.left);
      expect(a.sizeOf(Slots.sidebar), 240);
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
      a.setSize(Slots.sidebar, 240); // already 240, no change
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
  });
}
