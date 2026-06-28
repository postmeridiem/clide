import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/src/svg/svg_node.dart';
import 'package:clide/src/svg/svg_path.dart';
import 'package:clide/src/svg/svg_transform.dart';
import 'package:test/test.dart';

void main() {
  List<SvgNode> kids(String s) => buildSvgDocument(s).root.children;

  group('buildSvgDocument', () {
    test('a non-svg root yields the empty document', () {
      expect(buildSvgDocument('<div/>').root.children, isEmpty);
      expect(buildSvgDocument('garbage').root.children, isEmpty);
    });

    test('width, height and viewBox', () {
      final d = buildSvgDocument('<svg width="480" height="360" viewBox="0 0 48 36"/>');
      expect(d.width, 480);
      expect(d.height, 360);
      expect(d.viewBox!.width, 48);
      expect(d.viewBox!.height, 36);
    });

    test('rect geometry with rx inheriting to ry', () {
      final r = kids('<svg><rect x="1" y="2" width="3" height="4" rx="5"/></svg>').single as SvgRect;
      expect([r.x, r.y, r.width, r.height], [1, 2, 3, 4]);
      expect(r.rx, 5);
      expect(r.ry, 5);
    });

    test('circle becomes an ellipse with rx == ry', () {
      final e = kids('<svg><circle cx="5" cy="6" r="7"/></svg>').single as SvgEllipse;
      expect([e.cx, e.cy, e.rx, e.ry], [5, 6, 7, 7]);
    });

    test('polygon is closed, polyline is not', () {
      final poly = kids('<svg><polygon points="0,0 10,0 10,10"/></svg>').single as SvgPolyline;
      expect(poly.points, [0, 0, 10, 0, 10, 10]);
      expect(poly.closed, isTrue);
      final line = kids('<svg><polyline points="0,0 5,5"/></svg>').single as SvgPolyline;
      expect(line.closed, isFalse);
    });

    test('path data is parsed into segments', () {
      final p = kids('<svg><path d="M0 0 L10 10"/></svg>').single as SvgPath;
      expect(p.segments, [
        const SvgPathSeg(SvgPathOp.moveTo, [0, 0]),
        const SvgPathSeg(SvgPathOp.lineTo, [10, 10]),
      ]);
    });

    test('fill and stroke resolve to packed ARGB', () {
      final r = kids('<svg><rect fill="#0D32B2" stroke="red"/></svg>').single as SvgRect;
      expect(r.style.fill, 0xFF0D32B2);
      expect(r.style.stroke, 0xFFFF0000);
    });

    test('inheritable style flows from the parent group', () {
      final g = kids('<svg><g fill="red"><rect/></g></svg>').single as SvgGroup;
      expect((g.children.single as SvgRect).style.fill, 0xFFFF0000);
    });

    test('a child overrides an inherited value', () {
      final g = kids('<svg><g fill="red"><rect fill="#00FF00"/></g></svg>').single as SvgGroup;
      expect((g.children.single as SvgRect).style.fill, 0xFF00FF00);
    });

    test('opacity is not inherited', () {
      final g = kids('<svg><g opacity="0.5"><rect/></g></svg>').single as SvgGroup;
      expect(g.style.opacity, 0.5);
      expect((g.children.single as SvgRect).style.opacity, 1.0);
    });

    test('transform parses; identity collapses to null', () {
      final r = kids('<svg><rect transform="translate(5,10)"/></svg>').single as SvgRect;
      expect(r.transform, const Affine(1, 0, 0, 1, 5, 10));
      expect((kids('<svg><rect/></svg>').single as SvgRect).transform, isNull);
    });

    test('text content is collected and whitespace-collapsed', () {
      final t = kids('<svg><text x="1" y="2">  build </text></svg>').single as SvgText;
      expect(t.text, 'build');
      expect([t.x, t.y], [1, 2]);
    });

    test('image reads the xlink:href fallback', () {
      final i = kids('<svg><image x="0" y="0" width="8" height="8" xlink:href="a.png"/></svg>').single as SvgImage;
      expect(i.href, 'a.png');
    });

    test('lengths tolerate units', () {
      final t = kids('<svg><text font-size="12px">x</text></svg>').single as SvgText;
      expect(t.style.fontSize, 12);
    });

    test('end-to-end: a d2-style class resolves through to an ARGB fill', () {
      final p =
          kids(
                '<svg viewBox="0 0 100 100"><style>.fill-B1{fill:#0D32B2}</style>'
                '<path class="connection fill-B1" d="M0 0 L10 10"/></svg>',
              ).single
              as SvgPath;
      expect(p.style.fill, 0xFF0D32B2);
      expect(p.segments.first.op, SvgPathOp.moveTo);
    });

    test('defs and marker are skipped this slice', () {
      final k = kids('<svg><defs><marker id="m"><polygon points="0,0 1,1"/></marker></defs><rect/></svg>');
      expect(k.map((n) => n.runtimeType.toString()), ['SvgRect']);
    });
  });
}
