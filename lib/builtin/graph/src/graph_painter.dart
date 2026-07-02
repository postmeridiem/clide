/// Paints a laid-out [VaultGraph] (T-323): edges as lines, nodes as labelled
/// dots, with a hover neighbourhood lit and everything else dimmed.
///
/// The [ForceLayout] solver produces [positions] in a [layoutSize] space; the
/// painter fits that into the canvas (aspect-preserving, centered). The graph is
/// clide's own UI here (not arbitrary content), so it paints through
/// [SurfaceTokens] — theme chrome, per D-7.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/graph/force_layout.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:flutter/widgets.dart';

/// The aspect-preserving, centered fit of the solver's [layoutSize] space into a
/// canvas — shared by the painter and hit-testing so hover/click land exactly on
/// what's drawn.
class GraphViewport {
  GraphViewport(this.scale, this.dx, this.dy);
  final double scale, dx, dy;

  /// Fits the solver's [layout] space into [canvas] (aspect-preserving), then
  /// applies the user's [zoom] (about the canvas centre) and [pan]. At
  /// `zoom: 1, pan: zero` this is the plain centered fit.
  factory GraphViewport.fit(Size canvas, Size layout, {double zoom = 1, Offset pan = Offset.zero}) {
    final scale = math.min(canvas.width / layout.width, canvas.height / layout.height) * zoom;
    // Pin the layout centre to the canvas centre so zoom scales about it, then
    // translate by the pan.
    final dx = canvas.width / 2 + pan.dx - scale * layout.width / 2;
    final dy = canvas.height / 2 + pan.dy - scale * layout.height / 2;
    return GraphViewport(scale, dx, dy);
  }

  Offset toPixel(GraphPoint p) => Offset(dx + p.x * scale, dy + p.y * scale);
}

/// The node id nearest [local] within [hitRadius] px, or null — the inverse of
/// [GraphViewport], so it matches what [GraphPainter] drew.
String? hitTestNode(
  VaultGraph graph,
  Map<String, GraphPoint> positions,
  Offset local,
  Size size, {
  Size layoutSize = const Size(800, 600),
  double hitRadius = 12,
  double zoom = 1,
  Offset pan = Offset.zero,
}) {
  if (positions.isEmpty) return null;
  final vp = GraphViewport.fit(size, layoutSize, zoom: zoom, pan: pan);
  String? best;
  var bestD = hitRadius;
  for (final n in graph.nodes) {
    final p = positions[n.id];
    if (p == null) continue;
    final d = (vp.toPixel(p) - local).distance;
    if (d <= bestD) {
      bestD = d;
      best = n.id;
    }
  }
  return best;
}

class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.graph,
    required this.positions,
    required this.tokens,
    this.highlight,
    this.layoutSize = const Size(800, 600),
    this.zoom = 1,
    this.pan = Offset.zero,
  });

  final VaultGraph graph;
  final Map<String, GraphPoint> positions;
  final SurfaceTokens tokens;

  /// When non-null, only these node ids (a hovered node's neighbourhood) render
  /// at full strength; the rest dim.
  final Set<String>? highlight;

  final Size layoutSize;

  /// User pan/zoom over the base fit — kept in lockstep with [hitTestNode].
  final double zoom;
  final Offset pan;

  static const double nodeRadius = 5;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (graph.isEmpty || positions.isEmpty) return;
    final vp = GraphViewport.fit(size, layoutSize, zoom: zoom, pan: pan);
    Offset at(GraphPoint p) => vp.toPixel(p);
    bool lit(String id) => highlight == null || highlight!.contains(id);

    final edge = Paint()
      ..strokeWidth = 1
      ..color = tokens.dividerColor;
    final edgeDim = Paint()
      ..strokeWidth = 1
      ..color = tokens.dividerColor.withValues(alpha: 0.2);
    for (final e in graph.edges) {
      final a = positions[e.from], b = positions[e.to];
      if (a == null || b == null) continue;
      canvas.drawLine(at(a), at(b), lit(e.from) && lit(e.to) ? edge : edgeDim);
    }

    for (final n in graph.nodes) {
      final p = positions[n.id];
      if (p == null) continue;
      final o = at(p);
      final on = lit(n.id);
      canvas.drawCircle(o, nodeRadius, Paint()..color = on ? tokens.globalForeground : tokens.globalTextMuted.withValues(alpha: 0.35));
      if (on) _label(canvas, n.label, o);
    }
  }

  void _label(ui.Canvas canvas, String text, Offset o) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: tokens.globalForeground),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy + nodeRadius + 2));
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      !identical(old.graph, graph) ||
      !identical(old.positions, positions) ||
      old.highlight != highlight ||
      old.tokens != tokens ||
      old.zoom != zoom ||
      old.pan != pan;
}
