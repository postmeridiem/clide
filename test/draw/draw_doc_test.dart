import 'package:clide/src/draw/draw_doc.dart';
import 'package:test/test.dart';

void main() {
  group('parseDrawingCardDoc', () {
    test('primitive mode: inline svg', () {
      final d = parseDrawingCardDoc({'svg': '<svg/>'})!;
      expect(d.isPrimitive, isTrue);
      expect(d.svg, '<svg/>');
      expect(d.template, isNull);
    });

    test('card metadata via the card object', () {
      final d = parseDrawingCardDoc({
        'card': {'label': 'Build pipeline', 'description': 'how it connects'},
        'svgPath': 'd.svg',
      })!;
      expect(d.label, 'Build pipeline');
      expect(d.description, 'how it connects');
      expect(d.svgPath, 'd.svg');
    });

    test('card metadata also accepted at the top level', () {
      final d = parseDrawingCardDoc({'label': 'L', 'description': 'D', 'svg': '<svg/>'})!;
      expect(d.label, 'L');
      expect(d.description, 'D');
    });

    test('the card object wins over a top-level field', () {
      final d = parseDrawingCardDoc({
        'card': {'label': 'inner'},
        'label': 'outer',
        'svg': '<svg/>',
      })!;
      expect(d.label, 'inner');
    });

    test('template mode exposes its fields', () {
      final d = parseDrawingCardDoc({'template': 'd2', 'source': 'a -> b'})!;
      expect(d.template, 'd2');
      expect(d.isPrimitive, isFalse);
      expect(d.fields['source'], 'a -> b');
    });

    test('template "svg" is still primitive', () {
      final d = parseDrawingCardDoc({'template': 'svg', 'svg': '<svg/>'})!;
      expect(d.isPrimitive, isTrue);
    });

    test('compare template carries its items list', () {
      final d = parseDrawingCardDoc({
        'template': 'compare',
        'items': [
          {'path': 'a.png', 'label': 'Before'},
          {'path': 'b.png', 'label': 'After'},
        ],
      })!;
      expect(d.template, 'compare');
      expect((d.fields['items'] as List).length, 2);
    });

    test('empty object is a valid (primitive, empty) doc', () {
      final d = parseDrawingCardDoc(const {})!;
      expect(d.isPrimitive, isTrue);
      expect(d.svg, isNull);
      expect(d.label, isNull);
    });

    test('a non-object payload is null, never throws', () {
      expect(parseDrawingCardDoc('nope'), isNull);
      expect(parseDrawingCardDoc(42), isNull);
      expect(parseDrawingCardDoc(null), isNull);
    });

    test('blank strings are treated as absent', () {
      final d = parseDrawingCardDoc({'label': '', 'svg': ''})!;
      expect(d.label, isNull);
      expect(d.svg, isNull);
    });
  });
}
