/// Paints a [CanvasDoc] (T-322): group frames, edges, and node cards fitted
/// into the pane with a shared pan/zoom [CanvasViewport] — so hit-testing (a
/// later slice) lands exactly on what's drawn.
///
/// A `.canvas` is arbitrary user content, so node *colours* come from the file
/// (Obsidian presets `1`..`6` or `#rrggbb`), NOT clide's theme tokens; only the
/// chrome — the surface, default card, selection ring — is themed.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:flutter/widgets.dart';

/// The axis-aligned bounds of a doc's node rects, in canvas coordinates.
class CanvasBounds {
  const CanvasBounds(this.left, this.top, this.right, this.bottom);

  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;

  factory CanvasBounds.of(CanvasDoc doc) {
    if (doc.nodes.isEmpty) return const CanvasBounds(0, 0, 1, 1);
    var l = double.infinity, t = double.infinity, r = double.negativeInfinity, b = double.negativeInfinity;
    for (final n in doc.nodes) {
      l = math.min(l, n.x);
      t = math.min(t, n.y);
      r = math.max(r, n.x + n.width);
      b = math.max(b, n.y + n.height);
    }
    return CanvasBounds(l, t, r, b);
  }

  // Value equality so a repaint check compares the fit, not the instance.
  @override
  bool operator ==(Object other) =>
      other is CanvasBounds && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Fits a doc's [content] bounds into the pane (aspect-preserving, padded, and
/// centred), then applies the user's [zoom] (about the pane centre) and [pan].
class CanvasViewport {
  CanvasViewport(this.scale, this.dx, this.dy);
  final double scale, dx, dy;

  factory CanvasViewport.fit(Size canvas, CanvasBounds content, {double zoom = 1, Offset pan = Offset.zero, double padding = 24}) {
    final cw = content.width <= 0 ? 1.0 : content.width;
    final ch = content.height <= 0 ? 1.0 : content.height;
    final avw = math.max(1.0, canvas.width - 2 * padding);
    final avh = math.max(1.0, canvas.height - 2 * padding);
    final base = math.min(avw / cw, avh / ch);
    final scale = (base.isFinite && base > 0 ? base : 1.0) * zoom;
    final dx = canvas.width / 2 + pan.dx - scale * (content.left + cw / 2);
    final dy = canvas.height / 2 + pan.dy - scale * (content.top + ch / 2);
    return CanvasViewport(scale, dx, dy);
  }

  Offset toPixel(double x, double y) => Offset(dx + x * scale, dy + y * scale);

  Rect rectOf(CanvasNode n) => Rect.fromLTWH(dx + n.x * scale, dy + n.y * scale, n.width * scale, n.height * scale);
}

/// The content colour of a node/edge: an Obsidian preset `"1".."6"`, a
/// `#rgb`/`#rrggbb` hex, or null when unset. Kept theme-independent on purpose.
Color? canvasContentColor(String? spec) {
  if (spec == null || spec.isEmpty) return null;
  if (spec.startsWith('#')) return _hex(spec);
  return switch (spec) {
    '1' => const Color(0xFFFB464C), // red
    '2' => const Color(0xFFE9973F), // orange
    '3' => const Color(0xFFE0DE71), // yellow
    '4' => const Color(0xFF44CF6E), // green
    '5' => const Color(0xFF53DFDD), // cyan
    '6' => const Color(0xFFA882FF), // purple
    _ => null,
  };
}

/// The id of the topmost node under [local], or null. Uses the same
/// [CanvasViewport.fit] the painter draws with, so a click lands on what's
/// shown. Cards (drawn last) win over the group frames behind them.
///
/// [bounds] must match what the painter was given — pass the editing pane's
/// frozen bounds, or omit it to re-derive from [doc] as the viewer does.
String? hitTestCanvasNode(CanvasDoc doc, Offset local, Size size, {CanvasBounds? bounds, double zoom = 1, Offset pan = Offset.zero}) {
  if (doc.isEmpty) return null;
  final vp = CanvasViewport.fit(size, bounds ?? CanvasBounds.of(doc), zoom: zoom, pan: pan);
  for (final n in doc.nodes.reversed) {
    if (n is! GroupNode && vp.rectOf(n).contains(local)) return n.id;
  }
  for (final n in doc.nodes.reversed) {
    if (n is GroupNode && vp.rectOf(n).contains(local)) return n.id;
  }
  return null;
}

Color? _hex(String s) {
  var h = s.substring(1);
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Half-width of a corner resize handle, in pixels. The grab area is the
/// same square inflated by [canvasHandleGrabSlop].
const double canvasHandleRadius = 4;

/// Extra pixels around a handle that still count as grabbing it — a 4px
/// square is drawable but not reliably clickable.
const double canvasHandleGrabSlop = 4;

/// The four corner handle centres of a node's screen [rect], in the order
/// [CanvasCorner] declares.
List<Offset> canvasHandleCentres(Rect rect) => [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];

/// Which corner of a node a resize gesture grabbed.
enum CanvasCorner { topLeft, topRight, bottomLeft, bottomRight }

/// The corner handle of [rect] under [local], or null. Only meaningful for
/// the selected node — handles are drawn for that node alone.
CanvasCorner? canvasHandleAt(Rect rect, Offset local) {
  final centres = canvasHandleCentres(rect);
  const reach = canvasHandleRadius + canvasHandleGrabSlop;
  for (var i = 0; i < centres.length; i++) {
    if ((local - centres[i]).dx.abs() <= reach && (local - centres[i]).dy.abs() <= reach) {
      return CanvasCorner.values[i];
    }
  }
  return null;
}

class CanvasPainter extends CustomPainter {
  CanvasPainter({required this.doc, required this.tokens, this.bounds, this.zoom = 1, this.pan = Offset.zero, this.selected, this.showHandles = false});

  final CanvasDoc doc;
  final SurfaceTokens tokens;

  /// Content bounds to fit into the pane. The editing pane freezes these at
  /// load so moving a node doesn't re-fit — and so re-scale — the whole
  /// canvas under the cursor. Null re-derives per paint (the viewer).
  final CanvasBounds? bounds;

  final double zoom;
  final Offset pan;

  /// The id of the currently-selected node, drawn with a focus ring.
  final String? selected;

  /// Draw corner resize handles on the selected node (editing panes only —
  /// a display-only viewer offers no resize).
  final bool showHandles;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (doc.isEmpty) return;
    final vp = CanvasViewport.fit(size, bounds ?? CanvasBounds.of(doc), zoom: zoom, pan: pan);
    final byId = {for (final n in doc.nodes) n.id: n};

    // Groups sit behind everything as translucent framed regions.
    for (final n in doc.nodes.whereType<GroupNode>()) {
      _group(canvas, vp, n);
    }
    for (final e in doc.edges) {
      _edge(canvas, vp, e, byId);
    }
    for (final n in doc.nodes) {
      if (n is! GroupNode) _card(canvas, vp, n);
    }
    // Handles last, so they sit above any node that overlaps the selection.
    final sel = selected == null ? null : byId[selected];
    if (showHandles && sel != null) _handles(canvas, vp.rectOf(sel));
  }

  void _handles(ui.Canvas canvas, Rect rect) {
    final fill = Paint()..color = tokens.globalFocus;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.panelBackground;
    for (final c in canvasHandleCentres(rect)) {
      final box = Rect.fromCenter(center: c, width: canvasHandleRadius * 2, height: canvasHandleRadius * 2);
      canvas.drawRect(box, fill);
      canvas.drawRect(box, ring);
    }
  }

  void _group(ui.Canvas canvas, CanvasViewport vp, GroupNode n) {
    final rect = vp.rectOf(n);
    final tint = canvasContentColor(n.color) ?? tokens.globalTextMuted;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = tint.withValues(alpha: 0.06));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint.withValues(alpha: 0.5),
    );
    if (n.label != null && n.label!.isNotEmpty) {
      _text(canvas, n.label!, Offset(rect.left + 6, rect.top + 4), tint, maxWidth: rect.width - 12, size: 11);
    }
  }

  void _card(ui.Canvas canvas, CanvasViewport vp, CanvasNode n) {
    final rect = vp.rectOf(n);
    final content = canvasContentColor(n.color);
    final border = content ?? tokens.globalBorder;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = content?.withValues(alpha: 0.10) ?? tokens.panelBackground);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = n.id == selected ? 2 : 1
        ..color = n.id == selected ? tokens.globalFocus : border,
    );
    final label = switch (n) {
      TextNode(:final text) => text,
      FileNode(:final file) => _basename(file),
      LinkNode(:final url) => url,
      _ => '',
    };
    if (label.isNotEmpty && rect.width > 16 && rect.height > 12) {
      _text(canvas, label, Offset(rect.left + 6, rect.top + 5), tokens.globalForeground, maxWidth: rect.width - 12, maxLines: (rect.height ~/ 16).clamp(1, 6));
    }
  }

  void _edge(ui.Canvas canvas, CanvasViewport vp, CanvasEdge e, Map<String, CanvasNode> byId) {
    final from = byId[e.fromNode], to = byId[e.toNode];
    if (from == null || to == null) return;
    final a = _anchor(vp.rectOf(from), e.fromSide);
    final b = _anchor(vp.rectOf(to), e.toSide);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = canvasContentColor(e.color) ?? tokens.dividerColor;
    canvas.drawLine(a, b, paint);
    if (e.toEnd == CanvasEnd.arrow) _arrowhead(canvas, b, a, paint.color);
    if (e.fromEnd == CanvasEnd.arrow) _arrowhead(canvas, a, b, paint.color);
  }

  /// The attach point on a node rect: the midpoint of [side], or the centre.
  Offset _anchor(Rect r, CanvasSide? side) => switch (side) {
    CanvasSide.top => r.topCenter,
    CanvasSide.bottom => r.bottomCenter,
    CanvasSide.left => r.centerLeft,
    CanvasSide.right => r.centerRight,
    null => r.center,
  };

  void _arrowhead(ui.Canvas canvas, Offset tip, Offset from, Color color) {
    final dir = (tip - from);
    final len = dir.distance;
    if (len < 0.01) return;
    final u = dir / len;
    const size = 7.0;
    final base = tip - u * size;
    final perp = Offset(-u.dy, u.dx) * (size * 0.5);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
      ..lineTo(base.dx - perp.dx, base.dy - perp.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _text(ui.Canvas canvas, String text, Offset at, Color color, {required double maxWidth, int maxLines = 1, double size = 12}) {
    if (maxWidth < 4) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  static String _basename(String path) {
    final slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  @override
  bool shouldRepaint(CanvasPainter old) =>
      !identical(old.doc, doc) ||
      old.tokens != tokens ||
      old.bounds != bounds ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.selected != selected ||
      old.showHandles != showHandles;
}
