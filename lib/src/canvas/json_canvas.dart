/// The Obsidian JSONCanvas format (`.canvas` files) as a pure Dart model
/// (T-322). Parses the on-disk JSON into typed nodes + edges and serialises
/// back, so the canvas pane can load, edit, and persist a `.canvas`.
///
/// Per D-91 `.canvas` is an import format, not clide's native schema — this
/// model is the faithful parse. The interactive pane paints this model
/// directly via `CanvasPainter` (the D-103 live-widget exception, like the
/// graph); only the display-only drawing card lowers to the SVG substrate.
/// Pure data — no Flutter, no I/O here — so it runs under `dart test`.
/// Spec: https://jsoncanvas.org/spec/1.0/
library;

import 'dart:convert';
import 'dart:math' as math;

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

  /// This node with its rect replaced field-wise, everything else carried
  /// over — the whole mutation surface an editing pane needs (drag moves
  /// x/y, resize moves the edge it grabbed). Returns the same subtype, so
  /// callers keep their `TextNode`/`GroupNode` payload without a cast.
  CanvasNode withRect({double? x, double? y, double? width, double? height});

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
  TextNode withRect({double? x, double? y, double? width, double? height}) =>
      TextNode(id: id, x: x ?? this.x, y: y ?? this.y, width: width ?? this.width, height: height ?? this.height, color: color, text: text);

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
  FileNode withRect({double? x, double? y, double? width, double? height}) =>
      FileNode(id: id, x: x ?? this.x, y: y ?? this.y, width: width ?? this.width, height: height ?? this.height, color: color, file: file, subpath: subpath);

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
  LinkNode withRect({double? x, double? y, double? width, double? height}) =>
      LinkNode(id: id, x: x ?? this.x, y: y ?? this.y, width: width ?? this.width, height: height ?? this.height, color: color, url: url);

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
  GroupNode withRect({double? x, double? y, double? width, double? height}) => GroupNode(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    color: color,
    label: label,
    background: background,
    backgroundStyle: backgroundStyle,
  );

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

  /// The node with [id], or null.
  CanvasNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// This doc with [node] swapped in for the node of the same id, keeping
  /// paint order (z-order is list order, so an edited node must not jump to
  /// the front). Returns `this` unchanged when the id isn't present.
  CanvasDoc replaceNode(CanvasNode node) {
    final i = nodes.indexWhere((n) => n.id == node.id);
    if (i < 0) return this;
    final next = [...nodes];
    next[i] = node;
    return CanvasDoc(nodes: next, edges: edges);
  }

  /// This doc with [node] appended — last in list order, so a newly added
  /// node paints on top of what's already there.
  CanvasDoc addNode(CanvasNode node) => CanvasDoc(nodes: [...nodes, node], edges: edges);

  /// This doc without the node [id], **and without any edge that referenced
  /// it**. A dangling edge parses fine and simply doesn't paint, so leaving
  /// them behind would quietly grow the file with invisible junk.
  CanvasDoc removeNode(String id) {
    if (node(id) == null) return this;
    return CanvasDoc(
      nodes: [
        for (final n in nodes)
          if (n.id != id) n,
      ],
      edges: [
        for (final e in edges)
          if (e.fromNode != id && e.toNode != id) e,
      ],
    );
  }

  /// This doc with [edge] appended. Returns `this` unchanged when either
  /// endpoint is missing, or when an edge already joins the same two nodes
  /// in the same direction — connecting twice is a slip, not an intent.
  CanvasDoc addEdge(CanvasEdge edge) {
    if (node(edge.fromNode) == null || node(edge.toNode) == null) return this;
    if (edges.any((e) => e.fromNode == edge.fromNode && e.toNode == edge.toNode)) return this;
    return CanvasDoc(nodes: nodes, edges: [...edges, edge]);
  }

  /// An id not already used by a node or an edge in this document.
  /// Obsidian writes 16 hex characters; [random] is injectable so a test can
  /// pin the value.
  String freshId([math.Random? random]) {
    final rng = random ?? math.Random();
    final taken = {for (final n in nodes) n.id, for (final e in edges) e.id};
    while (true) {
      final id = [for (var i = 0; i < 16; i++) rng.nextInt(16).toRadixString(16)].join();
      if (taken.add(id)) return id;
    }
  }

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
