import 'package:clide/src/svg/svg_style.dart';
import 'package:clide/src/svg/svg_xml.dart';
import 'package:test/test.dart';

void main() {
  group('parseCss', () {
    test('class and tag rules', () {
      final r = parseCss('.fill-B1 { fill: #0D32B2 } text { font-weight: bold }');
      expect(r['.fill-B1'], {'fill': '#0D32B2'});
      expect(r['text'], {'font-weight': 'bold'});
    });

    test('comma-separated selectors share a block', () {
      final r = parseCss('.a, .b { stroke: none }');
      expect(r['.a'], {'stroke': 'none'});
      expect(r['.b'], {'stroke': 'none'});
    });

    test('comments are stripped', () {
      final r = parseCss('/* c */ .a { fill: red /* x */ }');
      expect(r['.a'], {'fill': 'red'});
    });

    test('compound / descendant / id selectors are ignored', () {
      final r = parseCss('.a .b { fill: red } .a.b { fill: blue } #id { fill: green }');
      expect(r, isEmpty);
    });
  });

  group('inlineStyles', () {
    XmlElement norm(String svg) {
      final root = parseXml(svg)!;
      inlineStyles(root);
      return root;
    }

    XmlElement only(XmlElement e) => e.children.whereType<XmlElement>().single;

    test('folds a class into an inline presentation attribute', () {
      final r = norm('<svg><style>.fill-B1{fill:#0D32B2}</style><rect class="shape fill-B1"/></svg>');
      final rect = only(r);
      expect(rect.attrs['fill'], '#0D32B2');
      expect(rect.attrs.containsKey('class'), isFalse);
    });

    test('removes <style> elements', () {
      final r = norm('<svg><style>.a{fill:red}</style><rect class="a"/></svg>');
      expect(r.children.whereType<XmlElement>().map((e) => e.name), ['rect']);
    });

    test('cascade: class overrides presentation attr, style="" overrides class', () {
      final r = norm('<svg><style>.c{fill:green}</style><rect fill="red" class="c" style="fill:blue"/></svg>');
      expect(only(r).attrs['fill'], 'blue');
    });

    test('class order: the later class wins', () {
      final r = norm('<svg><style>.a{fill:red}.b{fill:blue}</style><rect class="a b"/></svg>');
      expect(only(r).attrs['fill'], 'blue');
    });

    test('tag rule applies and a class overrides it', () {
      final r = norm('<svg><style>rect{stroke:black}.s{stroke:red}</style><rect class="s"/></svg>');
      expect(only(r).attrs['stroke'], 'red');
    });

    test('geometry attributes are left untouched', () {
      final r = norm('<svg><style>.a{fill:red}</style><rect class="a" x="1" y="2" transform="translate(5,5)"/></svg>');
      final rect = only(r);
      expect(rect.attrs['x'], '1');
      expect(rect.attrs['transform'], 'translate(5,5)');
      expect(rect.attrs['fill'], 'red');
    });

    test('nested elements are folded too', () {
      final r = norm('<svg><style>.a{fill:red}</style><g><rect class="a"/></g></svg>');
      expect(only(only(r)).attrs['fill'], 'red');
    });
  });
}
