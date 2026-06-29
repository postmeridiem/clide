import 'dart:math' as math;

import 'package:clide/src/graph/force_layout.dart';
import 'package:test/test.dart';

double _dist(GraphPoint a, GraphPoint b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

void main() {
  test('an empty graph lays out to nothing', () {
    expect(ForceLayout.compute(const [], const []), isEmpty);
  });

  test('a single node sits at the centre', () {
    expect(ForceLayout.compute(['a'], const [], width: 800, height: 600), {'a': (x: 400.0, y: 300.0)});
  });

  test('every node settles inside the area', () {
    final p = ForceLayout.compute(['a', 'b', 'c', 'd'], const [('a', 'b'), ('b', 'c'), ('c', 'd')], width: 800, height: 600);
    expect(p, hasLength(4));
    for (final pt in p.values) {
      expect(pt.x, inInclusiveRange(0, 800));
      expect(pt.y, inInclusiveRange(0, 600));
    }
  });

  test('it is deterministic — same input, same layout', () {
    final a = ForceLayout.compute(['a', 'b', 'c'], const [('a', 'b'), ('b', 'c')]);
    final b = ForceLayout.compute(['a', 'b', 'c'], const [('a', 'b'), ('b', 'c')]);
    expect(a, b);
  });

  test('two disconnected nodes repel farther apart than two connected ones', () {
    final connected = ForceLayout.compute(['a', 'b'], const [('a', 'b')]);
    final apart = ForceLayout.compute(['a', 'b'], const []);
    expect(_dist(apart['a']!, apart['b']!), greaterThan(_dist(connected['a']!, connected['b']!)));
  });

  test('an edge to an unknown node is ignored, not a crash', () {
    final p = ForceLayout.compute(['a', 'b'], const [('a', 'ghost')]);
    expect(p.keys, containsAll(['a', 'b']));
  });
}
