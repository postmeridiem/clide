import 'package:clide/kernel/src/text_zoom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextZoom', () {
    test('starts at 1.0', () {
      expect(TextZoom().scale, 1.0);
    });

    test('increase adds one step, notifies listeners', () {
      final z = TextZoom();
      var calls = 0;
      z.addListener(() => calls++);
      z.increase();
      expect(z.scale, closeTo(1.0 + TextZoom.stepScale, 1e-9));
      expect(calls, 1);
    });

    test('decrease subtracts one step', () {
      final z = TextZoom();
      z.decrease();
      expect(z.scale, closeTo(1.0 - TextZoom.stepScale, 1e-9));
    });

    test('reset jumps back to 1.0', () {
      final z = TextZoom()..increase()..increase();
      expect(z.scale, isNot(1.0));
      z.reset();
      expect(z.scale, 1.0);
    });

    test('clamps at minScale', () {
      final z = TextZoom();
      for (var i = 0; i < 100; i++) {
        z.decrease();
      }
      expect(z.scale, TextZoom.minScale);
    });

    test('clamps at maxScale', () {
      final z = TextZoom();
      for (var i = 0; i < 100; i++) {
        z.increase();
      }
      expect(z.scale, TextZoom.maxScale);
    });

    test('no-op increment does not notify', () {
      final z = TextZoom();
      for (var i = 0; i < 100; i++) {
        z.increase();
      }
      // Already at max — the next increase shouldn't fire.
      var calls = 0;
      z.addListener(() => calls++);
      z.increase();
      expect(calls, 0);
    });
  });
}
