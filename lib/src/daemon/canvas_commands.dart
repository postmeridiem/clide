/// Registers the `canvas.*` verbs — the CLI half of the canvas pane's edit
/// actions (T-570, per D-6 "every UI action has a CLI").
///
/// ```
/// clide canvas list     notes/map.canvas
/// clide canvas add-text notes/map.canvas "a thought" --x 100 --y 40
/// clide canvas add-note notes/map.canvas docs/design.md
/// clide canvas move     notes/map.canvas <nodeId> --x 100 --y 40
/// clide canvas resize   notes/map.canvas <nodeId> --width 300 --height 90
/// clide canvas connect  notes/map.canvas <fromId> <toId> --from-side right
/// clide canvas delete   notes/map.canvas <nodeId>
/// ```
///
/// These drive the **open** document, not the file on disk. The pane holds
/// its own copy and writes it back on the next edit, so a verb that edited
/// the file behind the pane's back would simply be overwritten. Editing a
/// `.canvas` that isn't open is therefore a clean error with a hint, not a
/// silent disk write — the same stance `ui.open` and `ui.filter` take about
/// needing a live GUI.
///
/// Flutter-free: the handlers speak only [CanvasDoc] (pure Dart) and reach
/// the live documents through the injected [CanvasDocuments], which the
/// canvas extension's store implements. So this file runs under `dart test`.
library;

import '../canvas/json_canvas.dart';
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// The live canvas documents the `canvas.*` verbs drive. Implemented by the
/// canvas extension's document store; the supplier returns null when there
/// is no GUI (headless / CLI-only).
abstract class CanvasDocuments {
  /// Workspace paths of the documents currently open in the pane.
  List<String> get openPaths;

  /// The working document for [path], or null when it isn't open (or hasn't
  /// finished loading).
  CanvasDoc? doc(String path);

  /// Replace [path]'s working document and persist it. The pane re-renders
  /// from the same state, so the CLI and the UI can't diverge.
  Future<void> apply(String path, CanvasDoc next);
}

/// Default size of a node created from the CLI — matches the pane's button.
const double _newNodeWidth = 250, _newNodeHeight = 60;

const _sides = {'top', 'right', 'bottom', 'left'};

void registerCanvasCommands(DaemonDispatcher d, CanvasDocuments? Function() documents) {
  d.register(
    'canvas.list',
    (req) => _list(req, documents),
    schema: const CommandSchema(positional: ['path'], args: {'path': ArgSpec(required: true)}),
  );

  d.register(
    'canvas.add-text',
    (req) => _addText(req, documents),
    schema: const CommandSchema(
      positional: ['path', 'text'],
      args: {
        'path': ArgSpec(required: true),
        'text': ArgSpec(),
        'x': ArgSpec(type: ArgType.number),
        'y': ArgSpec(type: ArgType.number),
        'width': ArgSpec(type: ArgType.number, min: 1),
        'height': ArgSpec(type: ArgType.number, min: 1),
        'color': ArgSpec(),
      },
    ),
  );

  d.register(
    'canvas.add-note',
    (req) => _addNote(req, documents),
    schema: const CommandSchema(
      positional: ['path', 'file'],
      args: {
        'path': ArgSpec(required: true),
        'file': ArgSpec(required: true),
        'x': ArgSpec(type: ArgType.number),
        'y': ArgSpec(type: ArgType.number),
        'width': ArgSpec(type: ArgType.number, min: 1),
        'height': ArgSpec(type: ArgType.number, min: 1),
        'subpath': ArgSpec(),
        'color': ArgSpec(),
      },
    ),
  );

  d.register(
    'canvas.delete',
    (req) => _delete(req, documents),
    schema: const CommandSchema(positional: ['path', 'id'], args: {'path': ArgSpec(required: true), 'id': ArgSpec(required: true)}),
  );

  d.register(
    'canvas.connect',
    (req) => _connect(req, documents),
    schema: const CommandSchema(
      positional: ['path', 'from', 'to'],
      args: {
        'path': ArgSpec(required: true),
        'from': ArgSpec(required: true),
        'to': ArgSpec(required: true),
        'from-side': ArgSpec(allowed: _sides),
        'to-side': ArgSpec(allowed: _sides),
        'label': ArgSpec(),
        'color': ArgSpec(),
      },
    ),
  );

  d.register(
    'canvas.move',
    (req) => _move(req, documents),
    schema: const CommandSchema(
      positional: ['path', 'id'],
      args: {
        'path': ArgSpec(required: true),
        'id': ArgSpec(required: true),
        'x': ArgSpec(type: ArgType.number),
        'y': ArgSpec(type: ArgType.number),
      },
    ),
  );

  d.register(
    'canvas.resize',
    (req) => _resize(req, documents),
    schema: const CommandSchema(
      positional: ['path', 'id'],
      args: {
        'path': ArgSpec(required: true),
        'id': ArgSpec(required: true),
        'width': ArgSpec(type: ArgType.number, min: 1),
        'height': ArgSpec(type: ArgType.number, min: 1),
      },
    ),
  );
}

IpcResponse _userErr(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);

IpcResponse _notFound(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: message, hint: hint),
);

IpcResponse _noUi(String id) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'no live UI to drive (clide is not running a GUI)'),
);

/// Resolve the open document named by `path` and hand it to [body], or
/// return the error explaining why that wasn't possible.
Future<IpcResponse> _withDoc(
  IpcRequest req,
  CanvasDocuments? Function() source,
  Future<IpcResponse> Function(CanvasDocuments docs, String path, CanvasDoc doc) body,
) async {
  final path = req.args['path'] as String?;
  if (path == null || path.isEmpty) return _userErr(req.id, 'a .canvas path is required');
  final docs = source();
  if (docs == null) return _noUi(req.id);
  final doc = docs.doc(path);
  if (doc == null) {
    final open = docs.openPaths;
    return _notFound(
      req.id,
      'canvas not open: $path',
      hint: open.isEmpty ? 'open one first: clide ui open canvas <path>' : 'open documents: ${open.join(', ')}',
    );
  }
  return body(docs, path, doc);
}

/// Resolve a node id argument against [doc].
IpcResponse? _missingNode(IpcRequest req, CanvasDoc doc, String key) {
  final id = req.args[key] as String?;
  if (id == null || id.isEmpty) return _userErr(req.id, '$key is required');
  if (doc.node(id) == null) {
    return _notFound(req.id, 'no such node: $id', hint: 'ids come from `clide canvas list <path>`');
  }
  return null;
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

Future<IpcResponse> _list(IpcRequest req, CanvasDocuments? Function() source) =>
    _withDoc(req, source, (docs, path, doc) async => IpcResponse.ok(id: req.id, data: {'path': path, ...doc.toJson()}));

Future<IpcResponse> _addText(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  final width = _num(req.args['width']) ?? _newNodeWidth;
  final height = _num(req.args['height']) ?? _newNodeHeight;
  // No viewport out here, so an unplaced node goes to the middle of the
  // existing content — the closest CLI analogue of the button's "middle of
  // what you're looking at".
  final (cx, cy) = CanvasBounds.of(doc).centre;
  final node = TextNode(
    id: doc.freshId(),
    x: _num(req.args['x']) ?? cx - width / 2,
    y: _num(req.args['y']) ?? cy - height / 2,
    width: width,
    height: height,
    color: req.args['color'] as String?,
    text: req.args['text'] as String? ?? '',
  );
  await docs.apply(path, doc.addNode(node));
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': node.id, 'x': node.x, 'y': node.y, 'width': node.width, 'height': node.height});
});

/// The CLI peer of the toolbar's add-note button. The UI gets its path from
/// the file picker (T-571); out here the caller names it directly. The path
/// is NOT checked against the workspace — a `.canvas` may legitimately
/// reference a file that doesn't exist yet, and Obsidian allows it too.
Future<IpcResponse> _addNote(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  final file = req.args['file'] as String?;
  if (file == null || file.isEmpty) return _userErr(req.id, 'a file to reference is required');
  final width = _num(req.args['width']) ?? _newNodeWidth;
  final height = _num(req.args['height']) ?? _newNodeHeight;
  final (cx, cy) = CanvasBounds.of(doc).centre;
  final node = FileNode(
    id: doc.freshId(),
    x: _num(req.args['x']) ?? cx - width / 2,
    y: _num(req.args['y']) ?? cy - height / 2,
    width: width,
    height: height,
    color: req.args['color'] as String?,
    file: file,
    subpath: req.args['subpath'] as String?,
  );
  await docs.apply(path, doc.addNode(node));
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': node.id, 'file': file, 'x': node.x, 'y': node.y});
});

Future<IpcResponse> _delete(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  final bad = _missingNode(req, doc, 'id');
  if (bad != null) return bad;
  final id = req.args['id']! as String;
  final next = doc.removeNode(id);
  await docs.apply(path, next);
  // Edges that referenced the node go with it — report how many, since that
  // is a side effect the caller didn't explicitly ask for.
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': id, 'removed': true, 'edgesRemoved': doc.edges.length - next.edges.length});
});

Future<IpcResponse> _connect(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  for (final key in ['from', 'to']) {
    final bad = _missingNode(req, doc, key);
    if (bad != null) return bad;
  }
  final from = req.args['from']! as String, to = req.args['to']! as String;
  if (from == to) return _userErr(req.id, 'a node cannot connect to itself');
  final edge = CanvasEdge(
    id: doc.freshId(),
    fromNode: from,
    toNode: to,
    fromSide: CanvasSide.parse(req.args['from-side']),
    toSide: CanvasSide.parse(req.args['to-side']),
    color: req.args['color'] as String?,
    label: req.args['label'] as String?,
  );
  final next = doc.addEdge(edge);
  if (identical(next, doc)) {
    return _userErr(req.id, '$from is already connected to $to', hint: 'the reverse direction is a separate edge');
  }
  await docs.apply(path, next);
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': edge.id, 'from': from, 'to': to});
});

Future<IpcResponse> _move(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  final bad = _missingNode(req, doc, 'id');
  if (bad != null) return bad;
  final node = doc.node(req.args['id']! as String)!;
  final x = _num(req.args['x']), y = _num(req.args['y']);
  if (x == null && y == null) return _userErr(req.id, 'at least one of --x or --y is required');
  final moved = node.withRect(x: x, y: y);
  await docs.apply(path, doc.replaceNode(moved));
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': moved.id, 'x': moved.x, 'y': moved.y});
});

Future<IpcResponse> _resize(IpcRequest req, CanvasDocuments? Function() source) => _withDoc(req, source, (docs, path, doc) async {
  final bad = _missingNode(req, doc, 'id');
  if (bad != null) return bad;
  final node = doc.node(req.args['id']! as String)!;
  final w = _num(req.args['width']), h = _num(req.args['height']);
  if (w == null && h == null) return _userErr(req.id, 'at least one of --width or --height is required');
  final sized = node.withRect(width: w, height: h);
  await docs.apply(path, doc.replaceNode(sized));
  return IpcResponse.ok(id: req.id, data: {'path': path, 'id': sized.id, 'width': sized.width, 'height': sized.height});
});
