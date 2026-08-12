/// Tests for the `canvas.*` verbs (T-570) — the CLI half of the canvas
/// pane's edit actions. Runs against a fake [CanvasDocuments] rather than a
/// live pane, which is the point of the interface: the handlers speak only
/// the pure model.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/src/daemon/canvas_commands.dart';
import 'package:test/test.dart';

class _FakeDocuments implements CanvasDocuments {
  _FakeDocuments(this._docs);

  final Map<String, CanvasDoc> _docs;

  /// Every apply, in order — so a test can assert what was persisted.
  final List<({String path, CanvasDoc doc})> applied = [];

  @override
  List<String> get openPaths => _docs.keys.toList();

  @override
  CanvasDoc? doc(String path) => _docs[path];

  @override
  Future<void> apply(String path, CanvasDoc next) async {
    applied.add((path: path, doc: next));
    _docs[path] = next;
  }
}

void main() {
  const path = 'notes/map.canvas';

  late _FakeDocuments docs;
  late DaemonDispatcher dispatcher;

  /// Two nodes 100 apart, one edge between them.
  CanvasDoc seed() => const CanvasDoc(
    nodes: [
      TextNode(id: 'a', x: 0, y: 0, width: 100, height: 100, text: 'a'),
      TextNode(id: 'b', x: 200, y: 200, width: 100, height: 100, text: 'b'),
    ],
    edges: [CanvasEdge(id: 'e', fromNode: 'a', toNode: 'b')],
  );

  setUp(() {
    docs = _FakeDocuments({path: seed()});
    dispatcher = DaemonDispatcher();
    registerCanvasCommands(dispatcher, () => docs);
  });

  Future<IpcResponse> call(String cmd, Map<String, Object?> args) => dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));

  group('canvas.list', () {
    test('returns the document nodes and edges', () async {
      final r = await call('canvas.list', const {'path': path});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['path'], path);
      expect([for (final n in (r.data['nodes']! as List).cast<Map>()) n['id']], ['a', 'b']);
      expect([for (final e in (r.data['edges']! as List).cast<Map>()) e['id']], ['e']);
    });

    test('CLI positional path binds (T-232)', () async {
      final r = await call('canvas.list', const {
        'positional': [path],
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['path'], path);
    });

    test('reading does not persist anything', () async {
      await call('canvas.list', const {'path': path});
      expect(docs.applied, isEmpty);
    });
  });

  group('canvas.add-text', () {
    test('places an unpositioned node at the middle of the content', () async {
      // Content spans 0..300 on both axes, so the centre is (150,150) and a
      // 250x60 node centred there starts at (25, 120).
      final r = await call('canvas.add-text', const {'path': path});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect((r.data['x'], r.data['y']), (25.0, 120.0));
      expect((r.data['width'], r.data['height']), (250.0, 60.0));

      final saved = docs.applied.single.doc;
      expect(saved.nodes, hasLength(3));
      expect(saved.nodes.last.id, r.data['id'], reason: 'appended, so it paints on top');
    });

    test('honours explicit position, size, text and colour', () async {
      final r = await call('canvas.add-text', const {'path': path, 'text': 'hello', 'x': 10, 'y': 20, 'width': 80, 'height': 40, 'color': '4'});
      expect(r.ok, isTrue, reason: r.error?.message);
      final node = docs.applied.single.doc.node(r.data['id']! as String)! as TextNode;
      expect((node.x, node.y, node.width, node.height), (10.0, 20.0, 80.0, 40.0));
      expect(node.text, 'hello');
      expect(node.color, '4');
    });

    test('coerces numeric flags arriving as argv strings', () async {
      final r = await call('canvas.add-text', const {
        'positional': [path, 'from cli'],
        'flags': {'x': '12', 'y': '34'},
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect((r.data['x'], r.data['y']), (12.0, 34.0));
      expect((docs.applied.single.doc.node(r.data['id']! as String)! as TextNode).text, 'from cli');
    });

    test('the new id is unique within the document', () async {
      final first = await call('canvas.add-text', const {'path': path});
      final second = await call('canvas.add-text', const {'path': path});
      expect(first.data['id'], isNot(second.data['id']));
      expect(docs.doc(path)!.nodes, hasLength(4));
    });

    test('rejects a non-positive size', () async {
      final r = await call('canvas.add-text', const {'path': path, 'width': 0});
      expect(r.ok, isFalse);
    });
  });

  group('canvas.add-note', () {
    test('adds a file node referencing the given path', () async {
      final r = await call('canvas.add-note', const {'path': path, 'file': 'docs/design.md', 'subpath': '#intro'});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['file'], 'docs/design.md');

      final node = docs.applied.single.doc.node(r.data['id']! as String)! as FileNode;
      expect(node.file, 'docs/design.md');
      expect(node.subpath, '#intro');
      expect((node.x, node.y), (25.0, 120.0), reason: 'centred on the content, like add-text');
    });

    test('requires a file to reference', () async {
      final r = await call('canvas.add-note', const {'path': path});
      expect(r.ok, isFalse);
      expect(docs.applied, isEmpty);
    });

    test('does not require the referenced file to exist', () async {
      // A .canvas may point at a file that isn't written yet; Obsidian
      // allows it, and the daemon has no business second-guessing it.
      final r = await call('canvas.add-note', const {'path': path, 'file': 'not/written/yet.md'});
      expect(r.ok, isTrue, reason: r.error?.message);
    });

    test('CLI positionals bind path then file', () async {
      final r = await call('canvas.add-note', const {
        'positional': [path, 'docs/a.md'],
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['file'], 'docs/a.md');
    });
  });

  group('canvas.delete', () {
    test('removes the node and reports the edges that went with it', () async {
      final r = await call('canvas.delete', const {'path': path, 'id': 'a'});
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['removed'], isTrue);
      expect(r.data['edgesRemoved'], 1, reason: 'edge e ran a→b');

      final saved = docs.applied.single.doc;
      expect(saved.node('a'), isNull);
      expect(saved.edges, isEmpty);
    });

    test('an unknown node is not-found and points at canvas list', () async {
      final r = await call('canvas.delete', const {'path': path, 'id': 'ghost'});
      expect(r.ok, isFalse);
      expect(r.error!.kind, IpcErrorKind.notFound);
      expect(r.error!.hint, contains('canvas list'));
      expect(docs.applied, isEmpty);
    });
  });

  group('canvas.connect', () {
    test('joins two nodes, honouring the anchor sides', () async {
      final r = await call('canvas.connect', const {'path': path, 'from': 'b', 'to': 'a', 'from-side': 'right', 'to-side': 'left', 'label': 'see'});
      expect(r.ok, isTrue, reason: r.error?.message);

      final edge = docs.applied.single.doc.edges.last;
      expect((edge.fromNode, edge.toNode), ('b', 'a'));
      expect((edge.fromSide, edge.toSide), (CanvasSide.right, CanvasSide.left));
      expect(edge.label, 'see');
      expect(edge.id, r.data['id']);
    });

    test('refuses a duplicate in the same direction, but not the reverse', () async {
      final dup = await call('canvas.connect', const {'path': path, 'from': 'a', 'to': 'b'});
      expect(dup.ok, isFalse);
      expect(dup.error!.message, contains('already connected'));
      expect(docs.applied, isEmpty);

      final reverse = await call('canvas.connect', const {'path': path, 'from': 'b', 'to': 'a'});
      expect(reverse.ok, isTrue, reason: reverse.error?.message);
    });

    test('refuses a self-connection', () async {
      final r = await call('canvas.connect', const {'path': path, 'from': 'a', 'to': 'a'});
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('itself'));
    });

    test('an unknown endpoint is not-found', () async {
      expect((await call('canvas.connect', const {'path': path, 'from': 'ghost', 'to': 'a'})).error!.kind, IpcErrorKind.notFound);
      expect((await call('canvas.connect', const {'path': path, 'from': 'a', 'to': 'ghost'})).error!.kind, IpcErrorKind.notFound);
      expect(docs.applied, isEmpty);
    });

    test('rejects an unknown anchor side', () async {
      final r = await call('canvas.connect', const {'path': path, 'from': 'a', 'to': 'b', 'from-side': 'sideways'});
      expect(r.ok, isFalse);
    });
  });

  group('canvas.move / canvas.resize', () {
    test('move sets the position and leaves the size alone', () async {
      final r = await call('canvas.move', const {'path': path, 'id': 'a', 'x': 40, 'y': 50});
      expect(r.ok, isTrue, reason: r.error?.message);
      final node = docs.applied.single.doc.node('a')!;
      expect((node.x, node.y), (40.0, 50.0));
      expect((node.width, node.height), (100.0, 100.0));
    });

    test('move accepts one axis on its own', () async {
      await call('canvas.move', const {'path': path, 'x': 40, 'id': 'a'});
      final node = docs.applied.single.doc.node('a')!;
      expect((node.x, node.y), (40.0, 0.0));
    });

    test('move with neither axis is a user error', () async {
      final r = await call('canvas.move', const {'path': path, 'id': 'a'});
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('--x'));
      expect(docs.applied, isEmpty);
    });

    test('resize sets the size and leaves the position alone', () async {
      final r = await call('canvas.resize', const {'path': path, 'id': 'b', 'width': 300, 'height': 90});
      expect(r.ok, isTrue, reason: r.error?.message);
      final node = docs.applied.single.doc.node('b')!;
      expect((node.width, node.height), (300.0, 90.0));
      expect((node.x, node.y), (200.0, 200.0));
    });

    test('resize with neither dimension is a user error', () async {
      final r = await call('canvas.resize', const {'path': path, 'id': 'b'});
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('--width'));
    });

    test('editing keeps the node payload', () async {
      await call('canvas.move', const {'path': path, 'id': 'a', 'x': 1});
      expect((docs.applied.single.doc.node('a')! as TextNode).text, 'a');
    });
  });

  group('preconditions', () {
    test('a document that is not open is not-found, and lists what is', () async {
      final r = await call('canvas.list', const {'path': 'other.canvas'});
      expect(r.ok, isFalse);
      expect(r.error!.kind, IpcErrorKind.notFound);
      expect(r.error!.message, contains('not open'));
      expect(r.error!.hint, contains(path), reason: 'tell the caller what IS open');
    });

    test('with nothing open the hint says how to open one', () async {
      final empty = DaemonDispatcher();
      registerCanvasCommands(empty, () => _FakeDocuments({}));
      final r = await empty.dispatch(IpcRequest(id: '1', cmd: 'canvas.list', args: const {'path': path}));
      expect(r.error!.hint, contains('clide ui open canvas'));
    });

    test('no live UI is a tool error, not a hang', () async {
      final headless = DaemonDispatcher();
      registerCanvasCommands(headless, () => null);
      for (final cmd in ['canvas.list', 'canvas.add-text', 'canvas.add-note', 'canvas.delete', 'canvas.connect', 'canvas.move', 'canvas.resize']) {
        // Every required arg is supplied: the schema validates before the
        // handler runs, so a missing one would mask the no-UI answer.
        final r = await headless.dispatch(IpcRequest(id: '1', cmd: cmd, args: const {'path': path, 'id': 'a', 'from': 'a', 'to': 'b', 'file': 'x.md'}));
        expect(r.ok, isFalse, reason: cmd);
        expect(r.error!.kind, IpcErrorKind.toolError, reason: cmd);
        expect(r.error!.message, contains('no live UI'), reason: cmd);
      }
    });

    test('every verb requires a path', () async {
      for (final cmd in ['canvas.list', 'canvas.add-text', 'canvas.add-note', 'canvas.delete', 'canvas.connect', 'canvas.move', 'canvas.resize']) {
        final r = await call(cmd, const {'id': 'a', 'from': 'a', 'to': 'b'});
        expect(r.ok, isFalse, reason: cmd);
      }
    });

    test('the edit is applied to the path that was asked for', () async {
      docs = _FakeDocuments({path: seed(), 'second.canvas': seed()});
      dispatcher = DaemonDispatcher();
      registerCanvasCommands(dispatcher, () => docs);

      await call('canvas.move', const {'path': 'second.canvas', 'id': 'a', 'x': 9});
      expect(docs.applied.single.path, 'second.canvas');
      expect(docs.doc(path)!.node('a')!.x, 0, reason: 'the other document is untouched');
    });
  });
}
