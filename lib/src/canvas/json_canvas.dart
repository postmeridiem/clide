/// The Obsidian JSONCanvas format (`.canvas` files) as a pure Dart model
/// (T-322). Parses the on-disk JSON into typed nodes + edges and serialises
/// back, so the canvas pane can load, edit, and persist a `.canvas`.
///
/// Per D-91 `.canvas` is an import format, not clide's native schema — this
/// model is the faithful parse; the pane lowers it onto the SVG substrate for
/// rendering. Pure data — no Flutter, no I/O here — so it runs under
/// `dart test`. Spec: https://jsoncanvas.org/spec/1.0/
library;

import 'dart:convert';

/// Which edge of a node an edge attaches to.
enum CanvasSide {
  top,
  right,
  bottom,
  left;

  static CanvasSide? parse(Object? v) => switch (v) {
    'top' => top,
    'right' => right,
    'bottom' => bottom,
    'left' => left,
    _ => null,
  };

  String get wire => name;
}

/// The endpoint decoration of an edge. Obsidian defaults `fromEnd` to none and
/// `toEnd` to arrow.
enum CanvasEnd {
  none,
  arrow;

  static CanvasEnd parse(Object? v, CanvasEnd fallback) => switch (v) {
    'none' => none,
    'arrow' => arrow,
    _ => fallback,
  };

  String get wire => name;
}

/// How a group node's background image is laid out.
enum CanvasBackgroundStyle {
  cover,
  ratio,
  repeat;

  static CanvasBackgroundStyle? parse(Object? v) => switch (v) {
    'cover' => cover,
    'ratio' => ratio,
    'repeat' => repeat,
    _ => null,
  };

  String get wire => name;
}

/// A node in a canvas. Every node has an id, a position, a size, and an
/// optional [color] (a preset `"1".."6"` or a `#rrggbb` hex, per the spec).
sealed class CanvasNode {
  const CanvasNode({required this.id, required this.x, required this.y, required this.width, required this.height, this.color});

  final String id;
  final double x, y, width, height;
  final String? color;

  /// The `type` discriminator written to disk.
  String get type;

  Map<String, Object?> toJson();

  Map<String, Object?> _base() => {'id': id, 'type': type, 'x': x, 'y': y, 'width': width, 'height': height, if (color != null) 'color': color};
}

/// A free-text node holding a markdown string.
class TextNode extends CanvasNode {
  const TextNode({required super.id, required super.x, required super.y, required super.width, required super.height, super.color, this.text = ''});

  final String text;

  @override
  String get type => 'text';

  @override
  Map<String, Object?> toJson() => {..._base(), 'text': text};
}

/// An embedded vault file, optionally scrolled to a [subpath] heading/block.
class FileNode extends CanvasNode {
  const FileNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.color,
    required this.file,
    this.subpath,
  });

  final String file;
  final String? subpath;

  @override
  String get type => 'file';

  @override
  Map<String, Object?> toJson() => {..._base(), 'file': file, if (subpath != null) 'subpath': subpath};
}

/// An external URL card.
class LinkNode extends CanvasNode {
  const LinkNode({required super.id, required super.x, required super.y, required super.width, required super.height, super.color, required this.url});

  final String url;

  @override
  String get type => 'link';

  @override
  Map<String, Object?> toJson() => {..._base(), 'url': url};
}

/// A labelled rectangle that visually groups the nodes inside it. May carry a
/// background image.
class GroupNode extends CanvasNode {
  const GroupNode({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.color,
    this.label,
    this.background,
    this.backgroundStyle,
  });

  final String? label;
  final String? background;
  final CanvasBackgroundStyle? backgroundStyle;

  @override
  String get type => 'group';

  @override
  Map<String, Object?> toJson() => {
    ..._base(),
    if (label != null) 'label': label,
    if (background != null) 'background': background,
    if (backgroundStyle != null) 'backgroundStyle': backgroundStyle!.wire,
  };
}

/// A directed connection between two nodes, optionally anchored to a specific
/// [fromSide]/[toSide] and decorated with end caps, a [color], and a [label].
class CanvasEdge {
  const CanvasEdge({
    required this.id,
    required this.fromNode,
    required this.toNode,
    this.fromSide,
    this.toSide,
    this.fromEnd = CanvasEnd.none,
    this.toEnd = CanvasEnd.arrow,
    this.color,
    this.label,
  });

  final String id;
  final String fromNode, toNode;
  final CanvasSide? fromSide, toSide;
  final CanvasEnd fromEnd, toEnd;
  final String? color;
  final String? label;

  static CanvasEdge? _parse(Map<String, Object?> m) {
    final id = m['id'], from = m['fromNode'], to = m['toNode'];
    if (id is! String || from is! String || to is! String) return null;
    return CanvasEdge(
      id: id,
      fromNode: from,
      toNode: to,
      fromSide: CanvasSide.parse(m['fromSide']),
      toSide: CanvasSide.parse(m['toSide']),
      fromEnd: CanvasEnd.parse(m['fromEnd'], CanvasEnd.none),
      toEnd: CanvasEnd.parse(m['toEnd'], CanvasEnd.arrow),
      color: m['color'] as String?,
      label: m['label'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fromNode': fromNode,
    if (fromSide != null) 'fromSide': fromSide!.wire,
    'toNode': toNode,
    if (toSide != null) 'toSide': toSide!.wire,
    // Only emit end caps when they differ from the spec defaults.
    if (fromEnd != CanvasEnd.none) 'fromEnd': fromEnd.wire,
    if (toEnd != CanvasEnd.arrow) 'toEnd': toEnd.wire,
    if (color != null) 'color': color,
    if (label != null) 'label': label,
  };
}

/// A parsed `.canvas` document: its [nodes] and [edges].
class CanvasDoc {
  const CanvasDoc({this.nodes = const [], this.edges = const []});

  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;

  bool get isEmpty => nodes.isEmpty && edges.isEmpty;

  /// Parse `.canvas` JSON text. Malformed JSON, or a top level that isn't an
  /// object, throws [FormatException]; individual nodes/edges that are
  /// unrecognised or missing required fields are skipped, not fatal.
  factory CanvasDoc.parse(String source) {
    final decoded = source.trim().isEmpty ? const <String, Object?>{} : jsonDecode(source);
    if (decoded is! Map) throw const FormatException('canvas: top level must be a JSON object');
    return CanvasDoc.fromJson(decoded.cast<String, Object?>());
  }

  factory CanvasDoc.fromJson(Map<String, Object?> m) {
    final nodes = <CanvasNode>[];
    for (final raw in (m['nodes'] as List? ?? const [])) {
      if (raw is Map) {
        final node = _parseNode(raw.cast<String, Object?>());
        if (node != null) nodes.add(node);
      }
    }
    final edges = <CanvasEdge>[];
    for (final raw in (m['edges'] as List? ?? const [])) {
      if (raw is Map) {
        final edge = CanvasEdge._parse(raw.cast<String, Object?>());
        if (edge != null) edges.add(edge);
      }
    }
    return CanvasDoc(nodes: nodes, edges: edges);
  }

  /// Serialise back to the on-disk shape. Empty `nodes`/`edges` arrays are
  /// always present, matching what Obsidian writes.
  Map<String, Object?> toJson() => {
    'nodes': [for (final n in nodes) n.toJson()],
    'edges': [for (final e in edges) e.toJson()],
  };

  String encode() => const JsonEncoder.withIndent('\t').convert(toJson());

  static CanvasNode? _parseNode(Map<String, Object?> m) {
    final id = m['id'];
    if (id is! String) return null;
    final x = _num(m['x']), y = _num(m['y']), w = _num(m['width']), h = _num(m['height']);
    if (x == null || y == null || w == null || h == null) return null;
    final color = m['color'] as String?;
    return switch (m['type']) {
      'text' => TextNode(id: id, x: x, y: y, width: w, height: h, color: color, text: m['text'] as String? ?? ''),
      'file' =>
        m['file'] is String
            ? FileNode(id: id, x: x, y: y, width: w, height: h, color: color, file: m['file'] as String, subpath: m['subpath'] as String?)
            : null,
      'link' => m['url'] is String ? LinkNode(id: id, x: x, y: y, width: w, height: h, color: color, url: m['url'] as String) : null,
      'group' => GroupNode(
        id: id,
        x: x,
        y: y,
        width: w,
        height: h,
        color: color,
        label: m['label'] as String?,
        background: m['background'] as String?,
        backgroundStyle: CanvasBackgroundStyle.parse(m['backgroundStyle']),
      ),
      _ => null, // unknown/unsupported node type — skip
    };
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : null;
}
