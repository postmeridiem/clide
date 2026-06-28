/// SVG `transform` parsing → a 2-D affine for the renderer (T-320 / D-103).
///
/// Parses a transform list (`translate(..) scale(..) rotate(..) matrix(..)
/// skewX(..) skewY(..)`) into a single composed [Affine], applied left-to-right
/// (leftmost outermost, per SVG). Unknown functions are skipped; malformed
/// input yields whatever composed so far. Never throws.
///
/// Flutter-free: pure Dart, runs under `dart test`. The painter converts the
/// [Affine] to a canvas transform.
library;

import 'dart:math' as math;

/// A 2-D affine transform mapping `(x, y) → (a·x + c·y + e, b·x + d·y + f)` —
/// the SVG `matrix(a b c d e f)` convention.
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;

  static const identity = Affine(1, 0, 0, 1, 0, 0);

  /// `this · other` — `other` applied first, then `this`.
  Affine multiply(Affine o) => Affine(a * o.a + c * o.b, b * o.a + d * o.b, a * o.c + c * o.d, b * o.c + d * o.d, a * o.e + c * o.f + e, b * o.e + d * o.f + f);

  /// Map a point through this transform.
  (double, double) apply(double x, double y) => (a * x + c * y + e, b * x + d * y + f);

  bool get isIdentity => a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  @override
  bool operator ==(Object other) => other is Affine && other.a == a && other.b == b && other.c == c && other.d == d && other.e == e && other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'Affine($a, $b, $c, $d, $e, $f)';
}

/// Parse an SVG `transform` list into a composed [Affine]. Returns
/// [Affine.identity] for empty / unrecognised input.
Affine parseTransform(String s) {
  var m = Affine.identity;
  for (final fn in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(s)) {
    final args = fn.group(2)!.split(RegExp(r'[\s,]+')).where((x) => x.isNotEmpty).map(double.tryParse).toList();
    final t = _fn(fn.group(1)!, args);
    if (t != null) m = m.multiply(t);
  }
  return m;
}

Affine? _fn(String fn, List<double?> args) {
  double a(int i) => (i < args.length && args[i] != null) ? args[i]! : 0;
  switch (fn) {
    case 'translate':
      return Affine(1, 0, 0, 1, a(0), args.length > 1 ? a(1) : 0);
    case 'scale':
      final sx = a(0);
      return Affine(sx, 0, 0, args.length > 1 ? a(1) : sx, 0, 0);
    case 'rotate':
      final rad = a(0) * math.pi / 180;
      final cos = math.cos(rad), sin = math.sin(rad);
      final r = Affine(cos, sin, -sin, cos, 0, 0);
      if (args.length >= 3) {
        final cx = a(1), cy = a(2);
        // translate(cx,cy) · R · translate(-cx,-cy)
        return Affine(1, 0, 0, 1, cx, cy).multiply(r).multiply(Affine(1, 0, 0, 1, -cx, -cy));
      }
      return r;
    case 'matrix':
      return args.length >= 6 ? Affine(a(0), a(1), a(2), a(3), a(4), a(5)) : null;
    case 'skewX':
      return Affine(1, 0, math.tan(a(0) * math.pi / 180), 1, 0, 0);
    case 'skewY':
      return Affine(1, math.tan(a(0) * math.pi / 180), 0, 1, 0, 0);
    default:
      return null;
  }
}
