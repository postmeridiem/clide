/// Builds the typed [SvgDocument] scene from raw SVG text (T-320 / D-103).
///
/// Pipeline: [parseXml] → [inlineStyles] (flatten classes to inline attrs) →
/// walk the tree into typed [SvgNode]s, resolving each element's geometry,
/// `transform` ([Affine]), and presentation [SvgStyle] with inheritance applied
/// down the tree. Colours resolve to packed ARGB ([parseSvgColor]); paths to
/// [SvgPathSeg]s ([parseSvgPath]).
///
/// Tolerant: a non-`<svg>` root yields [SvgDocument.empty]; unknown elements
/// (and `defs`/`marker`, deferred this slice) are skipped. Never throws.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'svg_color.dart';
import 'svg_node.dart';
import 'svg_path.dart';
import 'svg_style.dart';
import 'svg_transform.dart';
import 'svg_xml.dart';

/// Parse raw SVG into the typed scene model.
SvgDocument buildSvgDocument(String src) {
  final root = parseXml(src);
  if (root == null || root.name != 'svg') return SvgDocument.empty;
  inlineStyles(root);

  final markers = <String, SvgMarker>{};
  _collectMarkers(root, markers);

  final annotations = <SvgAnnotation>[];
  final style = _resolveStyle(root.attrs, SvgStyle.initial);
  final rootTf = _transform(root.attrs['transform']);
  final children = _children(root, style, rootTf ?? Affine.identity, annotations);
  return SvgDocument(
    width: _lenN(root.attrs['width']),
    height: _lenN(root.attrs['height']),
    viewBox: _viewBox(root.attrs['viewBox']),
    root: SvgGroup(style, rootTf, children),
    markers: markers,
    annotations: annotations,
  );
}

void _collectMarkers(XmlElement el, Map<String, SvgMarker> into) {
  if (el.name == 'marker') {
    final id = el.attrs['id'];
    if (id != null && id.isNotEmpty) into[id] = _marker(el);
  }
  for (final c in el.children) {
    if (c is XmlElement) _collectMarkers(c, into);
  }
}

SvgMarker _marker(XmlElement el) {
  final orient = el.attrs['orient'];
  final auto = orient == 'auto' || orient == 'auto-start-reverse';
  return SvgMarker(
    refX: _num(el.attrs['refX']),
    refY: _num(el.attrs['refY']),
    orientAuto: auto,
    orientAngle: (orient != null && !auto) ? (_stripNum(orient) ?? 0) : 0,
    strokeScaled: el.attrs['markerUnits'] != 'userSpaceOnUse', // default = strokeWidth
    viewBox: _viewBox(el.attrs['viewBox']),
    children: _children(el, SvgStyle.initial, Affine.identity, []), // markers don't carry annotations
  );
}

/// Extract the id from a `marker-*` value like `url(#id)`.
String? _markerRef(String? v) {
  if (v == null) return null;
  final m = RegExp(r'url\(\s*#([^)\s]+)\s*\)').firstMatch(v);
  return m?.group(1) ?? (v.startsWith('#') ? v.substring(1) : null);
}

List<SvgNode> _children(XmlElement el, SvgStyle inherited, Affine accumulated, List<SvgAnnotation> annotations) {
  final out = <SvgNode>[];
  for (final c in el.children) {
    if (c is XmlElement) {
      final n = _node(c, inherited, accumulated, annotations);
      if (n != null) out.add(n);
    }
  }
  return out;
}

SvgNode? _node(XmlElement el, SvgStyle inherited, Affine accumulated, List<SvgAnnotation> annotations) {
  final style = _resolveStyle(el.attrs, inherited);
  final tf = _transform(el.attrs['transform']);
  final acc = tf == null ? accumulated : accumulated.multiply(tf);
  final node = _build(el, style, tf, acc, annotations);
  if (node != null) _maybeAnnotate(el, node, acc, annotations);
  return node;
}

SvgNode? _build(XmlElement el, SvgStyle style, Affine? tf, Affine acc, List<SvgAnnotation> annotations) {
  final a = el.attrs;
  switch (el.name) {
    case 'g':
    case 'a':
    case 'svg':
      return SvgGroup(style, tf, _children(el, style, acc, annotations));
    case 'rect':
      final rx = _numN(a['rx']), ry = _numN(a['ry']);
      return SvgRect(style, tf, _num(a['x']), _num(a['y']), _num(a['width']), _num(a['height']), rx ?? ry ?? 0, ry ?? rx ?? 0);
    case 'circle':
      final r = _num(a['r']);
      return SvgEllipse(style, tf, _num(a['cx']), _num(a['cy']), r, r);
    case 'ellipse':
      return SvgEllipse(style, tf, _num(a['cx']), _num(a['cy']), _num(a['rx']), _num(a['ry']));
    case 'line':
      return SvgLine(style, tf, _num(a['x1']), _num(a['y1']), _num(a['x2']), _num(a['y2']));
    case 'polyline':
      return SvgPolyline(style, tf, _points(a['points']), false);
    case 'polygon':
      return SvgPolyline(style, tf, _points(a['points']), true);
    case 'path':
      return SvgPath(
        style,
        tf,
        parseSvgPath(a['d'] ?? ''),
        markerStart: _markerRef(a['marker-start']),
        markerMid: _markerRef(a['marker-mid']),
        markerEnd: _markerRef(a['marker-end']),
      );
    case 'text':
      return SvgText(style, tf, _num(a['x']), _num(a['y']), _textOf(el));
    case 'image':
      return SvgImage(style, tf, _num(a['x']), _num(a['y']), _num(a['width']), _num(a['height']), a['href'] ?? a['xlink:href'] ?? '');
    default:
      return null; // defs, marker, title, desc, unknown — skipped
  }
}

void _maybeAnnotate(XmlElement el, SvgNode node, Affine acc, List<SvgAnnotation> annotations) {
  final label = el.attrs['data-label'];
  final desc = el.attrs['data-description'];
  final lightbox = el.attrs.containsKey('data-lightbox');
  if (label == null && desc == null && !lightbox) return;
  final box = _localBBox(node);
  if (box == null) return;
  final r = _transformedAABB(box, acc);
  annotations.add(
    SvgAnnotation(x: r[0], y: r[1], width: r[2], height: r[3], label: label, description: desc, lightbox: lightbox, href: node is SvgImage ? node.href : null),
  );
}

/// Axis-aligned bounding box of [node] in its own local coordinates. Groups are
/// not bounded (anchor leaf shapes); text degenerates to its anchor point.
List<double>? _localBBox(SvgNode node) {
  switch (node) {
    case SvgRect r:
      return [r.x, r.y, r.width, r.height];
    case SvgImage i:
      return [i.x, i.y, i.width, i.height];
    case SvgEllipse e:
      return [e.cx - e.rx, e.cy - e.ry, e.rx * 2, e.ry * 2];
    case SvgLine l:
      return _aabbOfPoints([l.x1, l.y1, l.x2, l.y2]);
    case SvgPolyline p:
      return _aabbOfPoints(p.points);
    case SvgPath p:
      return _aabbOfPoints(_pathPoints(p.segments));
    case SvgText t:
      return [t.x, t.y, 0, 0];
    case SvgGroup _:
      return null;
  }
}

List<double> _pathPoints(List<SvgPathSeg> segs) {
  final pts = <double>[];
  for (final s in segs) {
    switch (s.op) {
      case SvgPathOp.moveTo:
      case SvgPathOp.lineTo:
        pts.addAll([s.args[0], s.args[1]]);
      case SvgPathOp.cubicTo:
        pts.addAll([s.args[0], s.args[1], s.args[2], s.args[3], s.args[4], s.args[5]]);
      case SvgPathOp.quadTo:
        pts.addAll([s.args[0], s.args[1], s.args[2], s.args[3]]);
      case SvgPathOp.arcTo:
        pts.addAll([s.args[5], s.args[6]]);
      case SvgPathOp.close:
        break;
    }
  }
  return pts;
}

List<double>? _aabbOfPoints(List<double> pts) {
  if (pts.length < 2) return null;
  var minX = pts[0], minY = pts[1], maxX = pts[0], maxY = pts[1];
  for (var i = 0; i + 1 < pts.length; i += 2) {
    minX = pts[i] < minX ? pts[i] : minX;
    maxX = pts[i] > maxX ? pts[i] : maxX;
    minY = pts[i + 1] < minY ? pts[i + 1] : minY;
    maxY = pts[i + 1] > maxY ? pts[i + 1] : maxY;
  }
  return [minX, minY, maxX - minX, maxY - minY];
}

/// Transform [box] = `[x, y, w, h]` by [m]; return the AABB `[x, y, w, h]`.
List<double> _transformedAABB(List<double> box, Affine m) {
  final x = box[0], y = box[1], w = box[2], h = box[3];
  final corners = [m.apply(x, y), m.apply(x + w, y), m.apply(x, y + h), m.apply(x + w, y + h)];
  var minX = corners[0].$1, minY = corners[0].$2, maxX = corners[0].$1, maxY = corners[0].$2;
  for (final c in corners) {
    minX = c.$1 < minX ? c.$1 : minX;
    maxX = c.$1 > maxX ? c.$1 : maxX;
    minY = c.$2 < minY ? c.$2 : minY;
    maxY = c.$2 > maxY ? c.$2 : maxY;
  }
  return [minX, minY, maxX - minX, maxY - minY];
}

SvgStyle _resolveStyle(Map<String, String> a, SvgStyle inh) {
  int? color(String k, int? fb) {
    final v = a[k];
    return v == null ? fb : (parseSvgColor(v) ?? fb);
  }

  double? dbl(String k, double? fb) {
    final v = a[k];
    return v == null ? fb : (_stripNum(v) ?? fb);
  }

  return SvgStyle(
    fill: color('fill', inh.fill),
    stroke: color('stroke', inh.stroke),
    strokeWidth: dbl('stroke-width', inh.strokeWidth),
    opacity: _stripNum(a['opacity'] ?? '') ?? 1.0, // not inherited
    fillOpacity: dbl('fill-opacity', inh.fillOpacity),
    strokeOpacity: dbl('stroke-opacity', inh.strokeOpacity),
    dashArray: a.containsKey('stroke-dasharray') ? _dash(a['stroke-dasharray']!) : inh.dashArray,
    lineCap: a.containsKey('stroke-linecap') ? _cap(a['stroke-linecap']!) : inh.lineCap,
    lineJoin: a.containsKey('stroke-linejoin') ? _join(a['stroke-linejoin']!) : inh.lineJoin,
    fontFamily: a['font-family'] ?? inh.fontFamily,
    fontSize: dbl('font-size', inh.fontSize),
    fontWeight: a.containsKey('font-weight') ? _weight(a['font-weight']!) : inh.fontWeight,
    textAnchor: a.containsKey('text-anchor') ? _anchor(a['text-anchor']!) : inh.textAnchor,
    baseline: a.containsKey('dominant-baseline') ? _baseline(a['dominant-baseline']!) : inh.baseline,
  );
}

SvgLineCap _cap(String v) => switch (v.trim()) {
  'round' => SvgLineCap.round,
  'square' => SvgLineCap.square,
  _ => SvgLineCap.butt,
};

SvgLineJoin _join(String v) => switch (v.trim()) {
  'round' => SvgLineJoin.round,
  'bevel' => SvgLineJoin.bevel,
  _ => SvgLineJoin.miter,
};

SvgTextAnchor _anchor(String v) => switch (v.trim()) {
  'middle' => SvgTextAnchor.middle,
  'end' => SvgTextAnchor.end,
  _ => SvgTextAnchor.start,
};

SvgBaseline _baseline(String v) => switch (v.trim()) {
  'middle' || 'central' => SvgBaseline.middle,
  'hanging' || 'text-before-edge' => SvgBaseline.hanging,
  _ => SvgBaseline.auto,
};

int _weight(String v) => switch (v.trim()) {
  'bold' => 700,
  'normal' => 400,
  _ => int.tryParse(v.trim()) ?? 400,
};

List<double> _dash(String v) {
  if (v.trim() == 'none') return const [];
  return v.split(RegExp(r'[\s,]+')).map(_stripNum).whereType<double>().toList();
}

List<double> _points(String? v) {
  if (v == null) return const [];
  return v.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).map(double.tryParse).whereType<double>().toList();
}

SvgViewBox? _viewBox(String? v) {
  if (v == null) return null;
  final n = v.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).map(double.tryParse).toList();
  if (n.length < 4 || n.any((x) => x == null)) return null;
  return SvgViewBox(n[0]!, n[1]!, n[2]!, n[3]!);
}

Affine? _transform(String? v) {
  if (v == null || v.isEmpty) return null;
  final t = parseTransform(v);
  return t.isIdentity ? null : t;
}

String _textOf(XmlElement el) {
  final buf = StringBuffer();
  for (final n in el.descendants()) {
    if (n is XmlText) buf.write(n.text);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Parse a length, ignoring a trailing unit (`12px` → 12); `null` if no number.
double? _stripNum(String v) {
  final m = RegExp(r'[-+]?(?:[0-9]*\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?').firstMatch(v.trim());
  return m == null ? null : double.tryParse(m.group(0)!);
}

double _num(String? v) => v == null ? 0 : (_stripNum(v) ?? 0);

double? _numN(String? v) => v == null ? null : _stripNum(v);

double? _lenN(String? v) => _numN(v);
