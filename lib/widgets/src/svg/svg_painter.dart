/// Renders a typed [SvgDocument] scene onto a Flutter canvas (T-320 / D-103).
///
/// This is the clide-owned `CustomPaint` SVG renderer — the engine the whole
/// drawing card (D-103) lowers onto. It walks the typed model built by
/// `svg_document.dart`, fitting the viewBox into the available size (uniform
/// scale, centred — `xMidYMid meet`) and drawing shapes/text with per-node
/// transforms and opacity.
///
/// v1 scope (matches the builder): groups, rect/ellipse/line/poly/path, text.
/// `image` href resolution is async and deferred (not painted yet); markers
/// (arrowheads) are a follow-on. Default paints follow SVG: fill black, stroke
/// none, stroke-width 1.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clide/src/svg/svg_node.dart';
import 'package:clide/src/svg/svg_path.dart';
import 'package:clide/src/svg/svg_transform.dart';
import 'package:flutter/widgets.dart';

/// Paint [doc] onto [canvas], fitting its viewBox into [size].
void paintSvg(ui.Canvas canvas, Size size, SvgDocument doc) {
  canvas.save();
  _applyViewport(canvas, size, doc);
  _paintNode(canvas, doc.root);
  canvas.restore();
}

void _applyViewport(ui.Canvas canvas, Size size, SvgDocument doc) {
  final vb = doc.viewBox;
  final srcW = vb?.width ?? doc.width ?? size.width;
  final srcH = vb?.height ?? doc.height ?? size.height;
  if (srcW <= 0 || srcH <= 0) return;
  final scale = math.min(size.width / srcW, size.height / srcH);
  canvas.translate((size.width - srcW * scale) / 2, (size.height - srcH * scale) / 2);
  canvas.scale(scale);
  if (vb != null) canvas.translate(-vb.minX, -vb.minY);
}

void _paintNode(ui.Canvas canvas, SvgNode node) {
  canvas.save();
  if (node.transform != null) canvas.transform(_matrix4(node.transform!));
  final layered = node.style.opacity < 1.0;
  if (layered) {
    canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, node.style.opacity.clamp(0, 1)));
  }

  switch (node) {
    case SvgGroup g:
      for (final c in g.children) {
        _paintNode(canvas, c);
      }
    case SvgText t:
      _paintText(canvas, t);
    case SvgImage _:
      break; // async href resolution deferred (v1)
    default:
      _paintShape(canvas, node);
  }

  if (layered) canvas.restore();
  canvas.restore();
}

void _paintShape(ui.Canvas canvas, SvgNode node) {
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

/// A `CustomPainter` that draws an [SvgDocument]. Repaints only when the
/// document instance changes.
class SvgScenePainter extends CustomPainter {
  const SvgScenePainter(this.document);
  final SvgDocument document;

  @override
  void paint(ui.Canvas canvas, Size size) => paintSvg(canvas, size, document);

  @override
  bool shouldRepaint(SvgScenePainter old) => !identical(old.document, document);
}

/// A widget that renders an [SvgDocument], filling its constraints.
class SvgView extends StatelessWidget {
  const SvgView({super.key, required this.document});
  final SvgDocument document;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: SvgScenePainter(document), child: const SizedBox.expand());
}
