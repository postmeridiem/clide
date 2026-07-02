import 'package:clide/src/graph/vault_graph.dart';
import 'package:test/test.dart';

void main() {
  group('VaultGraph.fromOutlinks', () {
    test('every file is a node; its label is the basename without extension', () {
      final g = VaultGraph.fromOutlinks({'notes/alpha.md': const [], 'beta.md': const []});
      expect(g.nodes.map((n) => n.id), containsAll(['notes/alpha.md', 'beta.md']));
      expect(g.nodes.firstWhere((n) => n.id == 'notes/alpha.md').label, 'alpha');
    });

    test('outlinks to known files become edges', () {
      final g = VaultGraph.fromOutlinks({
        'a.md': const ['b.md'],
        'b.md': const [],
      });
      expect(g.edgePairs, [('a.md', 'b.md')]);
    });

    test('self-links and dangling links are dropped', () {
      final g = VaultGraph.fromOutlinks({
        'a.md': const ['a.md', 'ghost.md', 'b.md'],
        'b.md': const [],
      });
      expect(g.edgePairs, [('a.md', 'b.md')]); // no self, no ghost
    });

    test('parallel edges are de-duplicated', () {
      final g = VaultGraph.fromOutlinks({
        'a.md': const ['b.md', 'b.md'],
        'b.md': const [],
      });
      expect(g.edgePairs, hasLength(1));
    });

    test('an empty vault is empty', () {
      expect(VaultGraph.fromOutlinks(const {}).isEmpty, isTrue);
    });
  });

  test('neighborhood returns a node plus its direct links, both directions', () {
    final g = VaultGraph.fromOutlinks({
      'a.md': const ['b.md'],
      'b.md': const ['c.md'],
      'c.md': const [],
      'x.md': const [],
    });
    expect(g.neighborhood('b.md'), {'b.md', 'a.md', 'c.md'});
    expect(g.neighborhood('x.md'), {'x.md'}); // isolated node
  });

  group('nodesWithin', () {
    final g = VaultGraph.fromOutlinks({
      'a.md': const ['b.md'],
      'b.md': const ['c.md'],
      'c.md': const [],
      'x.md': const [],
    }); // a—b—c chain, x isolated

    test('depth 0 is the root alone', () {
      expect(g.nodesWithin('a.md', 0), {'a.md'});
    });

    test('depth grows the frontier over undirected edges, both directions', () {
      expect(g.nodesWithin('a.md', 1), {'a.md', 'b.md'});
      expect(g.nodesWithin('a.md', 2), {'a.md', 'b.md', 'c.md'});
      expect(g.nodesWithin('c.md', 2), {'c.md', 'b.md', 'a.md'}); // walks backwards too
    });

    test('an isolated node is just itself; an unknown root is empty', () {
      expect(g.nodesWithin('x.md', 3), {'x.md'});
      expect(g.nodesWithin('ghost.md', 3), isEmpty);
    });
  });

  test('subgraph keeps only the kept nodes and edges between them', () {
    final g = VaultGraph.fromOutlinks({
      'a.md': const ['b.md', 'c.md'],
      'b.md': const ['c.md'],
      'c.md': const [],
    });
    final sub = g.subgraph({'a.md', 'b.md'});
    expect(sub.nodes.map((n) => n.id), unorderedEquals(['a.md', 'b.md']));
    expect(sub.edgePairs, [('a.md', 'b.md')]); // a—c and b—c drop with c gone
  });
}
