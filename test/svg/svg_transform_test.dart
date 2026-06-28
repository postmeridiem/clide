import 'package:clide/src/svg/svg_transform.dart';
import 'package:test/test.dart';

void main() {
  group('Affine', () {
    test('apply maps a point', () {
      final (x, y) = const Affine(2, 0, 0, 3, 5, 7).apply(1, 1);
      expect(x, 7); // 2*1 + 0 + 5
      expect(y, 10); // 3*1 + 0 + 7
    });

    test('multiply composes (this after other)', () {
      // translate(10,0) · scale(2): scale first, then translate.
      const t = Affine(1, 0, 0, 1, 10, 0);
      const s = Affine(2, 0, 0, 2, 0, 0);
      final (x, y) = t.multiply(s).apply(1, 1);
      expect(x, 12);
      expect(y, 2);
    });
  });

  group('parseTransform', () {
    test('empty / garbage → identity', () {
      expect(parseTransform(''), Affine.identity);
      expect(parseTransform('not a transform'), Affine.identity);
    });

    test('translate with one and two args', () {
      expect(parseTransform('translate(5,10)'), const Affine(1, 0, 0, 1, 5, 10));
      expect(parseTransform('translate(5)'), const Affine(1, 0, 0, 1, 5, 0));
    });

    test('scale uniform and non-uniform', () {
      expect(parseTransform('scale(2)'), const Affine(2, 0, 0, 2, 0, 0));
      expect(parseTransform('scale(2,3)'), const Affine(2, 0, 0, 3, 0, 0));
    });

    test('matrix is taken verbatim', () {
      expect(parseTransform('matrix(1,2,3,4,5,6)'), const Affine(1, 2, 3, 4, 5, 6));
    });

    test('rotate(90) turns +x into +y', () {
      final (x, y) = parseTransform('rotate(90)').apply(1, 0);
      expect(x, closeTo(0, 1e-9));
      expect(y, closeTo(1, 1e-9));
    });

    test('rotate about a point leaves that point fixed', () {
      final (x, y) = parseTransform('rotate(90, 1, 1)').apply(1, 1);
      expect(x, closeTo(1, 1e-9));
      expect(y, closeTo(1, 1e-9));
    });

    test('composes a list left-to-right, leftmost outermost', () {
      // translate(10,0) scale(2): point (1,1) → scale → (2,2) → translate → (12,2)
      final (x, y) = parseTransform('translate(10,0) scale(2)').apply(1, 1);
      expect(x, closeTo(12, 1e-9));
      expect(y, closeTo(2, 1e-9));
    });

    test('skips unknown functions but keeps the rest', () {
      expect(parseTransform('frobnicate(9) translate(3,4)'), const Affine(1, 0, 0, 1, 3, 4));
    });
  });
}
