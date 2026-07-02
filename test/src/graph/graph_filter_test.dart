import 'package:clide/src/graph/graph_filter.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:test/test.dart';

void main() {
  final g = VaultGraph.fromOutlinks({
    'a.md': const ['b.md'],
    'b.md': const ['c.md'],
    'c.md': const [],
    'x.md': const [],
  }); // a—b—c chain, x isolated
  final tags = {
    'a.md': {'project'},
    'b.md': {'note', 'project'},
    'c.md': {'note'},
  };

  test('an empty filter returns the full graph unchanged', () {
    const f = GraphFilter();
    expect(identical(f.apply(g, tagsByPath: tags), g), isTrue); // no-op short-circuit
  });

  test('includeTags keeps only notes carrying a matching tag', () {
    const f = GraphFilter(includeTags: {'project'});
    expect(f.apply(g, tagsByPath: tags).nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md']));
  });

  test('excludeTags drops notes carrying a matching tag', () {
    const f = GraphFilter(excludeTags: {'note'});
    // b and c carry 'note' → dropped; a (project) and x (untagged) survive.
    expect(f.apply(g, tagsByPath: tags).nodes.map((n) => n.id), unorderedEquals(['a.md', 'x.md']));
  });

  test('depth keeps the local graph around the active note', () {
    const f = GraphFilter(depth: 1);
    expect(f.apply(g, tagsByPath: tags, activePath: 'a.md').nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md']));
  });

  test('a depth filter with no active note yields nothing', () {
    const f = GraphFilter(depth: 2);
    expect(f.apply(g, tagsByPath: tags, activePath: null).isEmpty, isTrue);
  });

  test('tag and depth compose by intersection', () {
    // include project → {a,b}; depth 2 from c → {c,b,a}; intersection → {a,b}.
    const f = GraphFilter(includeTags: {'project'}, depth: 2);
    expect(f.apply(g, tagsByPath: tags, activePath: 'c.md').nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md']));
  });

  test('copyWith sets and clears the depth, keeping other fields', () {
    const f = GraphFilter(depth: 2, includeTags: {'project'});
    expect(f.copyWith(depth: 3).depth, 3);
    expect(f.copyWith(clearDepth: true).depth, isNull);
    expect(f.copyWith(clearDepth: true).includeTags, {'project'});
  });
}
