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
}
