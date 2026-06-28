import 'package:clide/src/svg/svg_path.dart';
import 'package:test/test.dart';

void main() {
  SvgPathSeg m(double x, double y) => SvgPathSeg(SvgPathOp.moveTo, [x, y]);
  SvgPathSeg l(double x, double y) => SvgPathSeg(SvgPathOp.lineTo, [x, y]);
  const close = SvgPathSeg(SvgPathOp.close, []);

  group('parseSvgPath', () {
    test('absolute moveto + lineto', () {
      expect(parseSvgPath('M10 10 L20 20'), [m(10, 10), l(20, 20)]);
    });

    test('relative commands accumulate from the current point', () {
      expect(parseSvgPath('m10 10 l5 5'), [m(10, 10), l(15, 15)]);
    });

    test('extra moveto coordinates become implicit linetos', () {
      expect(parseSvgPath('M0 0 10 10 20 20'), [m(0, 0), l(10, 10), l(20, 20)]);
    });

    test('extra relative-moveto coordinates become relative linetos', () {
      expect(parseSvgPath('m0 0 10 10'), [m(0, 0), l(10, 10)]);
    });

    test('H and V lower to lineto, absolute and relative', () {
      expect(parseSvgPath('M0 0 H10 V10'), [m(0, 0), l(10, 0), l(10, 10)]);
      expect(parseSvgPath('M5 5 h10 v-5'), [m(5, 5), l(15, 5), l(15, 0)]);
    });

    test('cubic bezier', () {
      expect(parseSvgPath('M0 0 C1 2 3 4 5 6'), [
        m(0, 0),
        const SvgPathSeg(SvgPathOp.cubicTo, [1, 2, 3, 4, 5, 6]),
      ]);
    });

    test('smooth cubic reflects the previous cubic control', () {
      // C ends at (5,6) with 2nd control (3,4); S reflects it about (5,6) → (7,8).
      final segs = parseSvgPath('M0 0 C1 2 3 4 5 6 S9 9 10 10');
      expect(segs[2], const SvgPathSeg(SvgPathOp.cubicTo, [7, 8, 9, 9, 10, 10]));
    });

    test('smooth cubic with no preceding cubic uses the current point', () {
      final segs = parseSvgPath('M0 0 S2 2 4 4');
      expect(segs[1], const SvgPathSeg(SvgPathOp.cubicTo, [0, 0, 2, 2, 4, 4]));
    });

    test('quadratic + smooth-quadratic reflection', () {
      // Q control (2,0) end (4,0); T reflects control about (4,0) → (6,0).
      final segs = parseSvgPath('M0 0 Q2 0 4 0 T8 0');
      expect(segs[1], const SvgPathSeg(SvgPathOp.quadTo, [2, 0, 4, 0]));
      expect(segs[2], const SvgPathSeg(SvgPathOp.quadTo, [6, 0, 8, 0]));
    });

    test('arc keeps flags and normalises radii to positive', () {
      final segs = parseSvgPath('M0 0 A5 5 0 0 1 10 10');
      expect(segs[1], const SvgPathSeg(SvgPathOp.arcTo, [5, 5, 0, 0, 1, 10, 10]));
    });

    test('arc flags packed without separators', () {
      // "...0 0110 10" → rot 0, largeArc 0, sweep 1, then x=10 y=10.
      final segs = parseSvgPath('M0 0 A5 5 0 0110 10');
      expect(segs[1], const SvgPathSeg(SvgPathOp.arcTo, [5, 5, 0, 0, 1, 10, 10]));
    });

    test('close returns the current point to the subpath start', () {
      // After Z the point is back at (10,10); the relative l5 5 → (15,15).
      expect(parseSvgPath('M10 10 L20 20 Z l5 5'), [m(10, 10), l(20, 20), close, l(15, 15)]);
    });

    test('packed decimals split correctly', () {
      expect(parseSvgPath('M.5.5'), [m(0.5, 0.5)]);
      expect(parseSvgPath('M1.5.3'), [m(1.5, 0.3)]);
    });

    test('negative numbers act as their own delimiter', () {
      expect(parseSvgPath('M0 0L-5-5'), [m(0, 0), l(-5, -5)]);
    });

    test('scientific notation', () {
      expect(parseSvgPath('M1e2 0'), [m(100, 0)]);
    });

    test('commas and stray whitespace are tolerated', () {
      expect(parseSvgPath('  M0,0  L 10 , 10 '), [m(0, 0), l(10, 10)]);
    });

    test('malformed tail yields the understood prefix and never throws', () {
      expect(parseSvgPath('M0 0 L10 10 L20'), [m(0, 0), l(10, 10)]);
    });

    test('empty or garbage input is empty and never throws', () {
      expect(parseSvgPath(''), isEmpty);
      expect(parseSvgPath('   '), isEmpty);
      expect(parseSvgPath('garbage'), isEmpty);
    });

    test('explicit repeated Z closes twice; trailing junk after Z bails cleanly', () {
      expect(parseSvgPath('M0 0 Z Z'), [m(0, 0), close, close]);
      // A number after Z is invalid: no implicit repeat, no spurious close, no hang.
      expect(parseSvgPath('M0 0 Z 5 5'), [m(0, 0), close]);
    });
  });
}
