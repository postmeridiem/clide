/// Tests the kernel-side bridge that connects the Flutter-free
/// `panel.resize` handler (T-119) to the live [LayoutArrangement].
/// The handler-side tests live in
/// `test/daemon/panel_commands_test.dart` against an in-memory fake.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/panel_resizer_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrangementPanelResizer', () {
    late LayoutArrangement arrangement;
    late ArrangementPanelResizer r;

    setUp(() {
      arrangement = LayoutArrangement()..applyPreset(classicPreset());
      r = ArrangementPanelResizer(arrangement);
    });

    test('setSlotSize forwards to LayoutArrangement.setSize and clamps', () {
      final ok = r.setSlotSize('sidebar', 10000);
      expect(ok, isTrue);
      expect(arrangement.sizeOf(Slots.sidebar), arrangement.maxSizeOf(Slots.sidebar));
      expect(r.currentSlotSize('sidebar'), arrangement.sizeOf(Slots.sidebar));
    });

    test('setSlotSize returns false for an unknown slot', () {
      expect(r.setSlotSize('does-not-exist', 250), isFalse);
    });

    test('bumpSlotSize applies the T-111 sign-flip on context panel', () {
      final start = arrangement.sizeOf(Slots.contextPanel)!;
      final ok = r.bumpSlotSize('context', 40);
      expect(ok, isTrue);
      // Context sits on the right edge — positive delta shrinks it.
      expect(arrangement.sizeOf(Slots.contextPanel), lessThan(start));
    });

    test('bumpSlotSize returns false for an unknown slot', () {
      expect(r.bumpSlotSize('nope', 5), isFalse);
    });

    test('setEditorRatio + currentEditorRatio round-trip through arrangement', () {
      r.setEditorRatio(0.5);
      expect(arrangement.editorRatio, 0.5);
      expect(r.currentEditorRatio, 0.5);
    });

    test('bumpEditorRatio adds to current ratio (kernel re-clamps)', () {
      r.setEditorRatio(0.4);
      r.bumpEditorRatio(0.2);
      expect(arrangement.editorRatio, closeTo(0.60, 1e-9));
      r.bumpEditorRatio(1.0); // out-of-range; kernel clamps to 0.70
      expect(arrangement.editorRatio, 0.70);
    });
  });
}
