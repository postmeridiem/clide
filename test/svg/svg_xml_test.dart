import 'package:clide/src/svg/svg_xml.dart';
import 'package:test/test.dart';

void main() {
  XmlElement parse(String s) {
    final root = parseXml(s);
    expect(root, isNotNull, reason: 'expected an element root for: $s');
    return root!;
  }

  group('parseXml', () {
    test('element with attributes', () {
      final e = parse('<rect x="1" y="2" width="3" height="4"/>');
      expect(e.name, 'rect');
      expect(e.attrs, {'x': '1', 'y': '2', 'width': '3', 'height': '4'});
      expect(e.children, isEmpty);
    });

    test('single-quoted and unquoted attribute values', () {
      final e = parse("<g fill='red' opacity=0.5/>");
      expect(e.attrs['fill'], 'red');
      expect(e.attrs['opacity'], '0.5');
    });

    test('nested children preserve order', () {
      final e = parse('<g><rect/><circle/></g>');
      expect(e.name, 'g');
      expect(e.children.whereType<XmlElement>().map((c) => c.name), ['rect', 'circle']);
    });

    test('text content is captured', () {
      final e = parse('<text>hello</text>');
      final t = e.children.single as XmlText;
      expect(t.text, 'hello');
    });

    test('comments are skipped', () {
      final e = parse('<g><!-- a comment --><rect/></g>');
      expect(e.children.whereType<XmlElement>().map((c) => c.name), ['rect']);
      expect(e.children.whereType<XmlText>(), isEmpty);
    });

    test('xml prolog and doctype are skipped', () {
      final e = parse('<?xml version="1.0"?><!DOCTYPE svg><svg width="10"/>');
      expect(e.name, 'svg');
      expect(e.attrs['width'], '10');
    });

    test('CDATA content is captured verbatim', () {
      final e = parse('<style><![CDATA[ .a { fill: red } ]]></style>');
      expect((e.children.single as XmlText).text, contains('.a { fill: red }'));
    });

    test('entities are decoded in text and attributes', () {
      final e = parse('<text title="a &amp; b">&lt;tag&gt; &#65;</text>');
      expect(e.attrs['title'], 'a & b');
      expect((e.children.single as XmlText).text, '<tag> A');
    });

    test('style body is read as raw text, not markup', () {
      // CSS with > and { } must not be parsed as elements.
      final e = parse('<style>.edge > .head { fill: #0D32B2 } .b{stroke:none}</style>');
      expect(e.name, 'style');
      final css = (e.children.single as XmlText).text;
      expect(css, contains('.edge > .head'));
      expect(css, contains('stroke:none'));
    });

    test('namespaced attribute names are kept verbatim', () {
      final e = parse('<image xlink:href="a.png" href="b.png"/>');
      expect(e.attrs['xlink:href'], 'a.png');
      expect(e.attrs['href'], 'b.png');
    });

    test('mismatched close tag is tolerated, no throw', () {
      final e = parse('<g><rect></wrong></g>');
      expect(e.name, 'g');
      expect(e.children.whereType<XmlElement>().single.name, 'rect');
    });

    test('descendants walks the whole subtree', () {
      final e = parse('<svg><g><rect/></g><circle/></svg>');
      final names = e.descendants().whereType<XmlElement>().map((c) => c.name).toList();
      expect(names, ['g', 'rect', 'circle']);
    });

    test('non-element root returns null, never throws', () {
      expect(parseXml(''), isNull);
      expect(parseXml('   '), isNull);
      expect(parseXml('just text'), isNull);
    });

    test('unterminated tag does not throw', () {
      // Should not hang or throw; returns whatever was understood.
      expect(() => parseXml('<svg><rect x="1"'), returnsNormally);
    });
  });
}
