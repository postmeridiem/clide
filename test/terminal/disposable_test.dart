/// Unit tests for `lib/src/terminal/src/base/disposable.dart` —
/// covers the `disposed` flag, the `onDisposed` event, and registering
/// child disposables.
library;

import 'package:clide/src/terminal/src/base/disposable.dart';
import 'package:test/test.dart';

class _D with Disposable {}

void main() {
  group('Disposable mixin', () {
    test('disposed flips from false to true after dispose()', () {
      final d = _D();
      expect(d.disposed, isFalse);
      d.dispose();
      expect(d.disposed, isTrue);
    });

    test('onDisposed fires once when dispose() runs', () {
      final d = _D();
      var fired = 0;
      d.onDisposed((_) => fired++);
      d.dispose();
      expect(fired, 1);
    });

    test('register propagates dispose to child disposables', () {
      final parent = _D();
      final child = _D();
      parent.register(child);
      expect(child.disposed, isFalse);
      parent.dispose();
      expect(child.disposed, isTrue);
    });
  });
}
