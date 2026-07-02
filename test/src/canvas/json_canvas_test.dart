import 'package:clide/src/canvas/json_canvas.dart';
import 'package:test/test.dart';

void main() {
  const sample = '''
{
  "nodes": [
    { "id": "t1", "type": "text", "x": 0, "y": 0, "width": 200, "height": 120, "text": "hello", "color": "3" },
    { "id": "f1", "type": "file", "x": 300, "y": 0, "width": 260, "height": 300, "file": "notes/a.md", "subpath": "#intro" },
    { "id": "l1", "type": "link", "x": 0, "y": 200, "width": 240, "height": 100, "url": "https://example.com" },
    { "id": "g1", "type": "group", "x": -40, "y": -40, "width": 700, "height": 500, "label": "Cluster", "backgroundStyle": "cover" }
  ],
  "edges": [
    { "id": "e1", "fromNode": "t1", "fromSide": "right", "toNode": "f1", "toSide": "left", "color": "2", "label": "see" }
  ]
}
''';

  test('parses every node type with its fields', () {
    final doc = CanvasDoc.parse(sample);
    expect(doc.nodes.map((n) => n.id), ['t1', 'f1', 'l1', 'g1']);

    final t = doc.nodes.whereType<TextNode>().single;
    expect(t.text, 'hello');
    expect(t.color, '3');
    expect((t.x, t.y, t.width, t.height), (0.0, 0.0, 200.0, 120.0));

    final f = doc.nodes.whereType<FileNode>().single;
    expect(f.file, 'notes/a.md');
    expect(f.subpath, '#intro');

    expect(doc.nodes.whereType<LinkNode>().single.url, 'https://example.com');

    final g = doc.nodes.whereType<GroupNode>().single;
    expect(g.label, 'Cluster');
    expect(g.backgroundStyle, CanvasBackgroundStyle.cover);
  });

  test('parses edges with sides, colour, label and default end caps', () {
    final e = CanvasDoc.parse(sample).edges.single;
    expect((e.fromNode, e.toNode), ('t1', 'f1'));
    expect((e.fromSide, e.toSide), (CanvasSide.right, CanvasSide.left));
    expect(e.color, '2');
    expect(e.label, 'see');
    expect((e.fromEnd, e.toEnd), (CanvasEnd.none, CanvasEnd.arrow)); // spec defaults
  });

  test('skips unknown node types and nodes missing required fields', () {
    final doc = CanvasDoc.parse('''
      { "nodes": [
        { "id": "ok", "type": "text", "x": 0, "y": 0, "width": 10, "height": 10 },
        { "id": "weird", "type": "portal", "x": 0, "y": 0, "width": 10, "height": 10 },
        { "id": "nofile", "type": "file", "x": 0, "y": 0, "width": 10, "height": 10 },
        { "id": "noxy", "type": "text", "width": 10, "height": 10 }
      ] }''');
    expect(doc.nodes.map((n) => n.id), ['ok']); // the other three are dropped
    expect(doc.nodes.single, isA<TextNode>());
  });

  test('skips edges missing an id or endpoint', () {
    final doc = CanvasDoc.parse('''
      { "edges": [
        { "id": "good", "fromNode": "a", "toNode": "b" },
        { "fromNode": "a", "toNode": "b" },
        { "id": "dangling", "fromNode": "a" }
      ] }''');
    expect(doc.edges.map((e) => e.id), ['good']);
  });

  test('blank source is an empty document', () {
    expect(CanvasDoc.parse('   ').isEmpty, isTrue);
    expect(CanvasDoc.parse('{}').isEmpty, isTrue);
  });

  test('a non-object top level is a FormatException', () {
    expect(() => CanvasDoc.parse('[1, 2, 3]'), throwsFormatException);
    expect(() => CanvasDoc.parse('not json'), throwsFormatException);
  });

  test('round-trips through encode without losing fields', () {
    final doc = CanvasDoc.parse(sample);
    final reparsed = CanvasDoc.parse(doc.encode());
    expect(reparsed.toJson(), doc.toJson());
  });

  test('toJson always carries both arrays; default end caps are omitted', () {
    const doc = CanvasDoc();
    expect(doc.toJson(), {'nodes': <Object?>[], 'edges': <Object?>[]});

    const edge = CanvasEdge(id: 'e', fromNode: 'a', toNode: 'b'); // defaults none/arrow
    expect(edge.toJson().containsKey('fromEnd'), isFalse);
    expect(edge.toJson().containsKey('toEnd'), isFalse);

    const flipped = CanvasEdge(id: 'e', fromNode: 'a', toNode: 'b', fromEnd: CanvasEnd.arrow, toEnd: CanvasEnd.none);
    expect(flipped.toJson()['fromEnd'], 'arrow');
    expect(flipped.toJson()['toEnd'], 'none');
  });
}
