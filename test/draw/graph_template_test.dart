import 'package:clide/src/draw/draw_dispatch.dart';
import 'package:clide/src/draw/draw_doc.dart';
import 'package:clide/src/draw/graph_template.dart';
import 'package:test/test.dart';

void main() {
  final handler = graphTemplateHandler();
  DrawingCardDoc doc(Map<String, Object?> fields) => DrawingCardDoc(template: 'graph', fields: {'template': 'graph', ...fields});

  test('lays out nodes as labelled circles and edges as lines', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'a', 'label': 'Alpha'},
          {'id': 'b', 'label': 'Beta'},
        ],
        'edges': [
          {'from': 'a', 'to': 'b'},
        ],
      }),
    );
    final svg = (r as DrawOk).svg;
    expect('<circle'.allMatches(svg).length, 2);
    expect('<line'.allMatches(svg).length, 1);
    expect(svg, contains('>Alpha<'));
    expect(svg, contains('>Beta<'));
  });

  test('a node label defaults to its id', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'solo'},
        ],
      }),
    );
    expect((r as DrawOk).svg, contains('>solo<'));
  });

  test('empty or missing nodes is an honest error', () async {
    expect(await handler(doc({'nodes': const []})), isA<DrawErr>());
    expect(await handler(doc(const {})), isA<DrawErr>());
  });

  test('a duplicate node id is an error', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'x'},
          {'id': 'x'},
        ],
      }),
    );
    expect((r as DrawErr).message, contains('duplicate'));
  });

  test('an edge from an unknown node is an error', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'a'},
        ],
        'edges': [
          {'from': 'ghost', 'to': 'a'},
        ],
      }),
    );
    expect((r as DrawErr).message, contains('ghost'));
  });

  test('an edge to an unknown node is an error', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'a'},
        ],
        'edges': [
          {'from': 'a', 'to': 'ghost'},
        ],
      }),
    );
    expect((r as DrawErr).message, contains('ghost'));
  });

  test('escapes label text', () async {
    final r = await handler(
      doc({
        'nodes': [
          {'id': 'a', 'label': '<b>&'},
        ],
      }),
    );
    expect((r as DrawOk).svg, contains('&lt;b&gt;&amp;'));
  });
}
