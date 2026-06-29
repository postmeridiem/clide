/// The `graph` drawing-card template (T-321 / D-91 / D-103).
///
/// Lowers a `{nodes:[{id,label}], edges:[{from,to}]}` payload to an SVG the
/// shared renderer (T-320) paints: a deterministic circular layout — nodes on a
/// ring as labelled `<circle>`s, edges as `<line>`s between them. Display-only
/// per D-78; the card-level label/description (T-318) renders beneath. Distinct
/// from the interactive force-directed graph PANE (T-323) — this is a static
/// graph dropped into the conversation.
///
/// Self-contained like a d2 diagram: it carries its own light backdrop + content
/// colors (the graph is content, not clide chrome — its own palette). Honest
/// [DrawErr] on an empty node set, a duplicate id, or an edge to an unknown node.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'dart:math' as math;

import 'draw_dispatch.dart';

const _nodeR = 9.0; // node circle radius
const _ringR = 140.0; // layout ring radius
const _pad = 52.0; // room for labels around the ring

DrawingTemplateHandler graphTemplateHandler() {
  return (doc) async {
    final nodesRaw = doc.fields['nodes'];
    if (nodesRaw is! List || nodesRaw.isEmpty) {
      return const DrawErr('the graph template needs a non-empty "nodes" array of {id,label}');
    }

    final ids = <String>[];
    final labels = <String>[];
    for (final node in nodesRaw) {
      if (node is! Map) return const DrawErr('each graph node must be a JSON object {id,label}');
      final id = _str(node['id']);
      if (id == null) return const DrawErr('each graph node needs an "id"');
      if (ids.contains(id)) return DrawErr('duplicate node id: $id');
      ids.add(id);
      labels.add(_str(node['label']) ?? id);
    }

    final n = ids.length;
    final cx = _ringR + _pad, cy = _ringR + _pad;
    final px = List<double>.filled(n, cx), py = List<double>.filled(n, cy);
    for (var i = 0; i < n && n > 1; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n; // start at top, clockwise
      px[i] = cx + _ringR * math.cos(a);
      py[i] = cy + _ringR * math.sin(a);
    }
    final index = {for (var i = 0; i < n; i++) ids[i]: i};

    // Edges first so nodes paint on top of them.
    final edges = StringBuffer();
    final edgesRaw = doc.fields['edges'];
    if (edgesRaw is List) {
      for (final edge in edgesRaw) {
        if (edge is! Map) return const DrawErr('each graph edge must be a JSON object {from,to}');
        final from = _str(edge['from']), to = _str(edge['to']);
        if (from == null || to == null) return const DrawErr('each graph edge needs a "from" and a "to"');
        final fi = index[from], ti = index[to];
        if (fi == null) return DrawErr('edge references unknown node: $from');
        if (ti == null) return DrawErr('edge references unknown node: $to');
        edges.write('<line x1="${_fmt(px[fi])}" y1="${_fmt(py[fi])}" x2="${_fmt(px[ti])}" y2="${_fmt(py[ti])}" stroke="#9aa4b2" stroke-width="1.5"/>');
      }
    }

    final nodes = StringBuffer();
    for (var i = 0; i < n; i++) {
      nodes.write('<circle cx="${_fmt(px[i])}" cy="${_fmt(py[i])}" r="$_nodeR" fill="#4a90d9"/>');
      nodes.write('<text x="${_fmt(px[i])}" y="${_fmt(py[i] - _nodeR - 5)}" text-anchor="middle" font-size="13" fill="#33373d">${_esc(labels[i])}</text>');
    }

    final size = 2 * (_ringR + _pad);
    return DrawOk(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_fmt(size)} ${_fmt(size)}">'
      '<rect width="${_fmt(size)}" height="${_fmt(size)}" fill="#fafafa"/>'
      '$edges$nodes</svg>',
    );
  };
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
