/// Force-directed graph layout (T-323) — a clide-owned Fruchterman-Reingold
/// solver (own-the-rendering-stack: no layout package).
///
/// Nodes repel each other (an inverse-distance "Coulomb" force); edges pull
/// their endpoints together (a "spring"). Iterating with a cooling temperature
/// settles the graph into a readable layout. DETERMINISTIC — a fixed circular
/// seed (no RNG) means the same graph always lays out identically, so the view
/// is stable across rebuilds and the solver is unit-testable.
///
/// Flutter-free: pure Dart (dart:math), runs under `dart test`. The graph PANE
/// (rendering, pan/zoom, hover, filter) builds on top of this.
library;

import 'dart:math' as math;

/// A laid-out 2D point.
typedef GraphPoint = ({double x, double y});

class _Vec {
  _Vec(this.x, this.y);
  double x, y;
}

class ForceLayout {
  /// Lay out [nodeIds] connected by [edges] (pairs of node ids) in a
  /// [width]×[height] area over [iterations] steps. Edges referencing an unknown
  /// node are ignored. Returns each node's settled position, clamped to the area.
  static Map<String, GraphPoint> compute(List<String> nodeIds, List<(String, String)> edges, {double width = 800, double height = 600, int iterations = 200}) {
    final n = nodeIds.length;
    if (n == 0) return const {};
    final cx = width / 2, cy = height / 2;
    if (n == 1) return {nodeIds.first: (x: cx, y: cy)};

    // Deterministic circular seed.
    final pos = <String, _Vec>{};
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      pos[nodeIds[i]] = _Vec(cx + math.cos(a) * width / 4, cy + math.sin(a) * height / 4);
    }

    final valid = edges.where((e) => pos.containsKey(e.$1) && pos.containsKey(e.$2) && e.$1 != e.$2).toList();
    final k = math.sqrt(width * height / n); // ideal edge length
    var temp = width / 10;

    for (var iter = 0; iter < iterations; iter++) {
      final disp = {for (final id in nodeIds) id: _Vec(0, 0)};

      // Repulsion between every pair.
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          final a = pos[nodeIds[i]]!, b = pos[nodeIds[j]]!;
          var dx = a.x - b.x, dy = a.y - b.y;
          var dist = math.sqrt(dx * dx + dy * dy);
          if (dist < 0.01) {
            dx = 0.01 * (i.isEven ? 1 : -1);
            dy = 0.01;
            dist = 0.01;
          }
          final force = k * k / dist;
          final ux = dx / dist, uy = dy / dist;
          disp[nodeIds[i]]!
            ..x += ux * force
            ..y += uy * force;
          disp[nodeIds[j]]!
            ..x -= ux * force
            ..y -= uy * force;
        }
      }

      // Attraction along edges.
      for (final e in valid) {
        final a = pos[e.$1]!, b = pos[e.$2]!;
        final dx = a.x - b.x, dy = a.y - b.y;
        final dist = math.max(0.01, math.sqrt(dx * dx + dy * dy));
        final force = dist * dist / k;
        final ux = dx / dist, uy = dy / dist;
        disp[e.$1]!
          ..x -= ux * force
          ..y -= uy * force;
        disp[e.$2]!
          ..x += ux * force
          ..y += uy * force;
      }

      // Apply, capped by the temperature, clamped to the area.
      for (final id in nodeIds) {
        final d = disp[id]!;
        final len = math.max(0.01, math.sqrt(d.x * d.x + d.y * d.y));
        final step = math.min(len, temp);
        final p = pos[id]!;
        p.x = (p.x + d.x / len * step).clamp(0.0, width);
        p.y = (p.y + d.y / len * step).clamp(0.0, height);
      }
      temp *= 0.95; // cool
    }

    return {for (final id in nodeIds) id: (x: pos[id]!.x, y: pos[id]!.y)};
  }
}
