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

class GraphPainter extends CustomPainter {
  GraphPainter({required this.graph, required this.positions, required this.tokens, this.highlight, this.layoutSize = const Size(800, 600)});

  final VaultGraph graph;
  final Map<String, GraphPoint> positions;
  final SurfaceTokens tokens;

  /// When non-null, only these node ids (a hovered node's neighbourhood) render
  /// at full strength; the rest dim.
  final Set<String>? highlight;

  final Size layoutSize;

  static const double nodeRadius = 5;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (graph.isEmpty || positions.isEmpty) return;
    final scale = math.min(size.width / layoutSize.width, size.height / layoutSize.height);
    final dx = (size.width - layoutSize.width * scale) / 2;
    final dy = (size.height - layoutSize.height * scale) / 2;
    Offset at(GraphPoint p) => Offset(dx + p.x * scale, dy + p.y * scale);
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
      !identical(old.graph, graph) || !identical(old.positions, positions) || old.highlight != highlight || old.tokens != tokens;
}
