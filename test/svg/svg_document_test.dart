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

    test('marker defs are collected (not drawn inline) with the path marker-end ref', () {
      final d = buildSvgDocument(
        '<svg><defs><marker id="arrow" refX="7" refY="6" orient="auto" markerUnits="userSpaceOnUse">'
        '<polygon points="0,0 10,6 0,12" fill="#0D32B2"/></marker></defs>'
        '<path d="M0 0 L10 0" marker-end="url(#arrow)"/></svg>',
      );
      // defs/marker are not drawable children — only the path is.
      expect(d.root.children.map((n) => n.runtimeType.toString()), ['SvgPath']);
      // …but the marker is collected, with its content style resolved.
      final m = d.markers['arrow']!;
      expect(m.refX, 7);
      expect(m.orientAuto, isTrue);
      expect(m.strokeScaled, isFalse); // markerUnits=userSpaceOnUse
      expect((m.children.single as SvgPolyline).style.fill, 0xFF0D32B2);
      expect((d.root.children.single as SvgPath).markerEnd, 'arrow');
    });

    test('a rect with data-label/data-description yields one annotation at its bbox', () {
      final d = buildSvgDocument('<svg viewBox="0 0 100 100"><rect x="10" y="20" width="30" height="40" data-label="Box" data-description="a box"/></svg>');
      final a = d.annotations.single;
      expect([a.x, a.y, a.width, a.height], [10, 20, 30, 40]);
      expect(a.label, 'Box');
      expect(a.description, 'a box');
      expect(a.lightbox, isFalse);
    });

    test('data-lightbox on an image yields a lightbox annotation carrying the href', () {
      final d = buildSvgDocument('<svg><image x="0" y="0" width="8" height="8" href="pic.png" data-lightbox=""/></svg>');
      final a = d.annotations.single;
      expect(a.lightbox, isTrue);
      expect(a.href, 'pic.png');
    });

    test('the annotation bbox respects the element transform', () {
      final d = buildSvgDocument('<svg><rect x="0" y="0" width="10" height="10" transform="translate(5,5)" data-label="x"/></svg>');
      expect([d.annotations.single.x, d.annotations.single.y], [5, 5]);
    });

    test('the annotation bbox respects an inherited group transform', () {
      final d = buildSvgDocument('<svg><g transform="translate(100,0)"><rect x="0" y="0" width="10" height="10" data-label="x"/></g></svg>');
      final a = d.annotations.single;
      expect([a.x, a.y, a.width, a.height], [100, 0, 10, 10]);
    });

    test('elements without data-* produce no annotations', () {
      expect(buildSvgDocument('<svg><rect width="10" height="10"/></svg>').annotations, isEmpty);
    });

    test('a group with data-label is skipped — annotations anchor leaf shapes', () {
      expect(buildSvgDocument('<svg><g data-label="grp"><rect width="10" height="10"/></g></svg>').annotations, isEmpty);
    });
  });
}
