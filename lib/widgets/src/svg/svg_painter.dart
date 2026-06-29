/// Renders a typed [SvgDocument] scene onto a Flutter canvas (T-320 / D-103).
///
/// This is the clide-owned `CustomPaint` SVG renderer — the engine the whole
/// drawing card (D-103) lowers onto. It walks the typed model built by
/// `svg_document.dart`, fitting the viewBox into the available size (uniform
/// scale, centred — `xMidYMid meet`) and drawing shapes/text with per-node
/// transforms and opacity.
///
/// v1 scope: groups, rect/ellipse/line/poly/path, text, `marker-*` arrowheads
/// (rotated to the path direction), and `<image>` via an injected resolver (the
/// caller owns href loading). Default paints follow SVG: fill black, stroke
/// none, stroke-width 1.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clide/src/svg/svg_node.dart';
import 'package:clide/src/svg/svg_path.dart';
import 'package:clide/src/svg/svg_transform.dart';
import 'package:flutter/widgets.dart';

/// Resolves an `<image>` href to an already-decoded image, or `null` if it
/// isn't available yet. The caller owns loading (file/asset/network) and policy;
/// the painter stays pure rendering. Returning `null` simply paints nothing.
typedef SvgImageResolver = ui.Image? Function(String href);

/// Paint [doc] onto [canvas], fitting its viewBox into [size]. [images] resolves
/// `<image>` hrefs to decoded images.
void paintSvg(ui.Canvas canvas, Size size, SvgDocument doc, {SvgImageResolver? images}) {
  canvas.save();
  _applyViewport(canvas, size, doc);
  _paintNode(canvas, doc.root, _Ctx(doc.markers, images));
  canvas.restore();
}

/// Per-paint context threaded through the walk.
class _Ctx {
  const _Ctx(this.markers, this.images);
  final Map<String, SvgMarker> markers;
  final SvgImageResolver? images;
}

/// The fit of [doc]'s viewBox into [size] — a uniform [scale] plus a [dx]/[dy]
/// offset (xMidYMid meet) and the viewBox origin. Shared by the painter and the
/// DrawingCard overlay so captions land exactly over the painted content.
class SvgViewport {
  const SvgViewport(this.scale, this.dx, this.dy, this.minX, this.minY);
  final double scale, dx, dy, minX, minY;

  /// Map a viewBox-space point to a pixel offset.
  Offset toPixel(double x, double y) => Offset(dx + (x - minX) * scale, dy + (y - minY) * scale);
}

SvgViewport svgViewportFit(Size size, SvgDocument doc) {
  final vb = doc.viewBox;
  final srcW = vb?.width ?? doc.width ?? size.width;
  final srcH = vb?.height ?? doc.height ?? size.height;
  if (srcW <= 0 || srcH <= 0) return const SvgViewport(1, 0, 0, 0, 0);
  final scale = math.min(size.width / srcW, size.height / srcH);
  return SvgViewport(scale, (size.width - srcW * scale) / 2, (size.height - srcH * scale) / 2, vb?.minX ?? 0, vb?.minY ?? 0);
}

void _applyViewport(ui.Canvas canvas, Size size, SvgDocument doc) {
  final v = svgViewportFit(size, doc);
  canvas.translate(v.dx, v.dy);
  canvas.scale(v.scale);
  canvas.translate(-v.minX, -v.minY);
}

void _paintNode(ui.Canvas canvas, SvgNode node, _Ctx ctx) {
  canvas.save();
  if (node.transform != null) canvas.transform(_matrix4(node.transform!));
  final layered = node.style.opacity < 1.0;
  if (layered) {
    canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, node.style.opacity.clamp(0, 1)));
  }

  switch (node) {
    case SvgGroup g:
      for (final c in g.children) {
        _paintNode(canvas, c, ctx);
      }
    case SvgText t:
      _paintText(canvas, t);
    case SvgImage im:
      _paintImage(canvas, im, ctx);
    default:
      _paintShape(canvas, node, ctx);
  }

  if (layered) canvas.restore();
  canvas.restore();
}

void _paintImage(ui.Canvas canvas, SvgImage im, _Ctx ctx) {
  final img = ctx.images?.call(im.href);
  if (img == null) return; // not loaded / no resolver — paint nothing
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  // Aspect-fit (contain) the image within its target rect, centered — so a
  // compare card never distorts images of differing shapes (T-319). A degenerate
  // (zero-size) image or rect falls back to the plain rect.
  canvas.drawImageRect(img, src, _containRect(im.x, im.y, im.width, im.height, img.width.toDouble(), img.height.toDouble()), ui.Paint());
}

/// The largest rect with the source's aspect ratio that fits inside the target
/// box [x],[y],[w],[h], centered within it.
Rect _containRect(double x, double y, double w, double h, double srcW, double srcH) {
  if (srcW <= 0 || srcH <= 0 || w <= 0 || h <= 0) return Rect.fromLTWH(x, y, w, h);
  final scale = (w / srcW) < (h / srcH) ? w / srcW : h / srcH;
  final fitW = srcW * scale, fitH = srcH * scale;
  return Rect.fromLTWH(x + (w - fitW) / 2, y + (h - fitH) / 2, fitW, fitH);
}

void _paintShape(ui.Canvas canvas, SvgNode node, _Ctx ctx) {
  final path = _shapePath(node);
  if (path == null) return;
  final s = node.style;

  // Fill — SVG default is black; a line is never filled.
  if (node is! SvgLine) {
    final fill = s.fill ?? 0xFF000000;
    if (_alpha(fill) != 0) {
      canvas.drawPath(path, ui.Paint()..color = _color(fill, s.fillOpacity));
    }
  }
  // Stroke — only when specified and not none.
  final stroke = s.stroke;
  if (stroke != null && _alpha(stroke) != 0) {
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..color = _color(stroke, s.strokeOpacity)
        ..strokeWidth = s.strokeWidth ?? 1.0
        ..strokeCap = _cap(s.lineCap)
        ..strokeJoin = _join(s.lineJoin),
    );
  }

  // Markers (arrowheads) at the path ends, rotated to the path direction.
  if (node is SvgPath && ctx.markers.isNotEmpty) {
    final ends = _pathEnds(node.segments);
    if (ends != null) {
      final (sx, sy, sAngle, ex, ey, eAngle) = ends;
      final sw = s.strokeWidth ?? 1.0;
      final end = node.markerEnd == null ? null : ctx.markers[node.markerEnd];
      if (end != null) _paintMarker(canvas, end, ex, ey, eAngle, sw, ctx);
      final start = node.markerStart == null ? null : ctx.markers[node.markerStart];
      if (start != null) _paintMarker(canvas, start, sx, sy, sAngle, sw, ctx);
    }
  }
}

void _paintMarker(ui.Canvas canvas, SvgMarker m, double x, double y, double angle, double strokeWidth, _Ctx ctx) {
  canvas.save();
  canvas.translate(x, y);
  canvas.rotate(m.orientAuto ? angle : m.orientAngle * math.pi / 180);
  if (m.strokeScaled) canvas.scale(strokeWidth);
  // viewBox→viewport scaling is approximated 1:1 (holds for d2's markers).
  canvas.translate(-m.refX, -m.refY);
  for (final c in m.children) {
    _paintNode(canvas, c, ctx);
  }
  canvas.restore();
}

/// Start/end points and tangent angles of a path: `(sx, sy, startAngle, ex, ey,
/// endAngle)`, or `null` if the path has no drawing segments.
(double, double, double, double, double, double)? _pathEnds(List<SvgPathSeg> segs) {
  double cx = 0, cy = 0, sx = 0, sy = 0;
  double startAngle = 0, fx = 0, fy = 0;
  var seenDraw = false, seenEnd = false;
  for (final s in segs) {
    final a = s.args;
    switch (s.op) {
      case SvgPathOp.moveTo:
        cx = a[0];
        cy = a[1];
        sx = cx;
        sy = cy;
      case SvgPathOp.lineTo:
        if (!seenDraw) startAngle = math.atan2(a[1] - cy, a[0] - cx);
        fx = cx;
        fy = cy;
        cx = a[0];
        cy = a[1];
        seenDraw = seenEnd = true;
      case SvgPathOp.cubicTo:
        if (!seenDraw) startAngle = math.atan2(a[1] - cy, a[0] - cx);
        fx = a[2];
        fy = a[3];
        cx = a[4];
        cy = a[5];
        seenDraw = seenEnd = true;
      case SvgPathOp.quadTo:
        if (!seenDraw) startAngle = math.atan2(a[1] - cy, a[0] - cx);
        fx = a[0];
        fy = a[1];
        cx = a[2];
        cy = a[3];
        seenDraw = seenEnd = true;
      case SvgPathOp.arcTo:
        if (!seenDraw) startAngle = math.atan2(a[6] - cy, a[5] - cx);
        fx = cx;
        fy = cy;
        cx = a[5];
        cy = a[6];
        seenDraw = seenEnd = true;
      case SvgPathOp.close:
        if (!seenDraw) startAngle = math.atan2(sy - cy, sx - cx);
        fx = cx;
        fy = cy;
        cx = sx;
        cy = sy;
        seenDraw = seenEnd = true;
    }
  }
  if (!seenEnd) return null;
  return (sx, sy, startAngle, cx, cy, math.atan2(cy - fy, cx - fx));
}

ui.Path? _shapePath(SvgNode node) {
  switch (node) {
    case SvgRect r:
      final rect = Rect.fromLTWH(r.x, r.y, r.width, r.height);
      return Path()..addRRect(
        (r.rx > 0 || r.ry > 0) ? RRect.fromRectXY(rect, r.rx == 0 ? r.ry : r.rx, r.ry == 0 ? r.rx : r.ry) : RRect.fromRectAndRadius(rect, Radius.zero),
      );
    case SvgEllipse e:
      return Path()..addOval(Rect.fromCenter(center: Offset(e.cx, e.cy), width: e.rx * 2, height: e.ry * 2));
    case SvgLine l:
      return Path()
        ..moveTo(l.x1, l.y1)
        ..lineTo(l.x2, l.y2);
    case SvgPolyline p:
      if (p.points.length < 4) return null;
      final path = Path()..moveTo(p.points[0], p.points[1]);
      for (var i = 2; i + 1 < p.points.length; i += 2) {
        path.lineTo(p.points[i], p.points[i + 1]);
      }
      if (p.closed) path.close();
      return path;
    case SvgPath p:
      return _segPath(p.segments);
    default:
      return null;
  }
}

ui.Path _segPath(List<SvgPathSeg> segs) {
  final path = Path();
  for (final s in segs) {
    final a = s.args;
    switch (s.op) {
      case SvgPathOp.moveTo:
        path.moveTo(a[0], a[1]);
      case SvgPathOp.lineTo:
        path.lineTo(a[0], a[1]);
      case SvgPathOp.cubicTo:
        path.cubicTo(a[0], a[1], a[2], a[3], a[4], a[5]);
      case SvgPathOp.quadTo:
        path.quadraticBezierTo(a[0], a[1], a[2], a[3]);
      case SvgPathOp.arcTo:
        path.arcToPoint(Offset(a[5], a[6]), radius: Radius.elliptical(a[0], a[1]), rotation: a[2], largeArc: a[3] != 0, clockwise: a[4] != 0);
      case SvgPathOp.close:
        path.close();
    }
  }
  return path;
}

void _paintText(ui.Canvas canvas, SvgText t) {
  if (t.text.isEmpty) return;
  final s = t.style;
  final fontSize = s.fontSize ?? 16.0;
  final tp = TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(fontFamily: s.fontFamily, fontSize: fontSize, fontWeight: _weight(s.fontWeight), color: _color(s.fill ?? 0xFF000000, s.fillOpacity)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final dx = switch (s.textAnchor) {
    SvgTextAnchor.middle => -tp.width / 2,
    SvgTextAnchor.end => -tp.width,
    _ => 0.0,
  };
  final dy = switch (s.baseline) {
    SvgBaseline.middle => -tp.height / 2,
    SvgBaseline.hanging => 0.0,
    _ => -tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
  };
  tp.paint(canvas, Offset(t.x + dx, t.y + dy));
}

int _alpha(int argb) => (argb >> 24) & 0xFF;

ui.Color _color(int argb, double? extraOpacity) {
  if (extraOpacity == null || extraOpacity >= 1) return ui.Color(argb);
  final a = (((argb >> 24) & 0xFF) * extraOpacity.clamp(0, 1)).round() & 0xFF;
  return ui.Color((a << 24) | (argb & 0x00FFFFFF));
}

ui.StrokeCap _cap(SvgLineCap? c) => switch (c) {
  SvgLineCap.round => ui.StrokeCap.round,
  SvgLineCap.square => ui.StrokeCap.square,
  _ => ui.StrokeCap.butt,
};

ui.StrokeJoin _join(SvgLineJoin? j) => switch (j) {
  SvgLineJoin.round => ui.StrokeJoin.round,
  SvgLineJoin.bevel => ui.StrokeJoin.bevel,
  _ => ui.StrokeJoin.miter,
};

FontWeight _weight(int? w) => w == null ? FontWeight.w400 : FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

Float64List _matrix4(Affine m) => Float64List.fromList([
  m.a, m.b, 0, 0, //
  m.c, m.d, 0, 0, //
  0, 0, 1, 0, //
  m.e, m.f, 0, 1, //
]);

/// A `CustomPainter` that draws an [SvgDocument]. Repaints when the document
/// instance or the [images] resolver changes.
class SvgScenePainter extends CustomPainter {
  const SvgScenePainter(this.document, {this.images});
  final SvgDocument document;
  final SvgImageResolver? images;

  @override
  void paint(ui.Canvas canvas, Size size) => paintSvg(canvas, size, document, images: images);

  @override
  bool shouldRepaint(SvgScenePainter old) => !identical(old.document, document) || old.images != images;
}

/// A widget that renders an [SvgDocument], filling its constraints. [images]
/// resolves `<image>` hrefs to decoded images (loading is the caller's job).
class SvgView extends StatelessWidget {
  const SvgView({super.key, required this.document, this.images});
  final SvgDocument document;
  final SvgImageResolver? images;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SvgScenePainter(document, images: images),
    child: const SizedBox.expand(),
  );
}
