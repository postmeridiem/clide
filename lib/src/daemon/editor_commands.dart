/// Registers `editor.*` command handlers on a [DaemonDispatcher].
///
/// Verb list matches CLAUDE.md's tier-2 surface:
///   editor.open editor.active editor.activate editor.insert
///   editor.replace-selection editor.save editor.close editor.list
///   editor.read editor.set-selection editor.set-content
///
/// Single-word CLI shortcuts (`clide open`, `clide active`, …) map
/// one-to-one onto these in `bin/clide.dart`.
library;

import '../editor/registry.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

export '../editor/buffer.dart' show Selection;

void registerEditorCommands(DaemonDispatcher d, EditorRegistry registry) {
  d.register('editor.open', (req) => _open(req, registry));
  d.register('editor.active', (req) => _active(req, registry));
  d.register('editor.activate', (req) => _activate(req, registry));
  d.register('editor.list', (req) => _list(req, registry));
  d.register('editor.read', (req) => _read(req, registry));
  d.register('editor.insert', (req) => _insert(req, registry));
  d.register('editor.replace-selection', (req) => _replace(req, registry));
  d.register('editor.set-selection', (req) => _setSelection(req, registry));
  d.register('editor.set-content', (req) => _setContent(req, registry));
  d.register('editor.save', (req) => _save(req, registry));
  d.register('editor.close', (req) => _close(req, registry));
}

IpcResponse _userErr(String id, String msg, {String? hint}) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: msg,
        hint: hint,
      ),
    );

IpcResponse _notFound(String id, String msg) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.notFound,
        kind: IpcErrorKind.notFound,
        message: msg,
      ),
    );

String? _resolveId(IpcRequest req, EditorRegistry r) {
  final id = req.args['id'] as String?;
  if (id != null) return id;
  // CLI shortcut: omitting `id` means the active buffer.
  return r.active?.id;
}

Future<IpcResponse> _open(IpcRequest req, EditorRegistry r) async {
  final path = req.args['path'] as String?;
  if (path == null || path.isEmpty) {
    return _userErr(req.id, 'path is required');
  }
  try {
    final buf = await r.open(path);
    return IpcResponse.ok(id: req.id, data: buf.toJson());
  } catch (e) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: 'editor.open failed: $e',
      ),
    );
  }
}

Future<IpcResponse> _active(IpcRequest req, EditorRegistry r) async {
  final buf = r.active;
  if (buf == null) {
    return IpcResponse.ok(id: req.id, data: const {'active': null});
  }
  return IpcResponse.ok(id: req.id, data: {'active': buf.toJson()});
}

Future<IpcResponse> _activate(IpcRequest req, EditorRegistry r) async {
  final id = req.args['id'] as String?;
  if (id == null) return _userErr(req.id, 'id is required');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  r.activate(id);
  return IpcResponse.ok(id: req.id, data: {'active': id});
}

Future<IpcResponse> _list(IpcRequest req, EditorRegistry r) async {
  return IpcResponse.ok(
    id: req.id,
    data: {'buffers': [for (final b in r.buffers) b.toJson()]},
  );
}

Future<IpcResponse> _read(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  final buf = r.get(id);
  if (buf == null) return _notFound(req.id, 'no such buffer: $id');
  return IpcResponse.ok(id: req.id, data: buf.toFullJson());
}

Future<IpcResponse> _insert(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  final text = EditorRegistry.contentFromArgs(req.args);
  r.insert(id, text);
  return IpcResponse.ok(id: req.id, data: {'id': id, 'inserted': text.length});
}

Future<IpcResponse> _replace(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  final text = EditorRegistry.contentFromArgs(req.args);
  r.replaceSelection(id, text);
  return IpcResponse.ok(id: req.id, data: {'id': id, 'length': text.length});
}

Future<IpcResponse> _setSelection(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  final sel = EditorRegistry.selectionFromArgs(req.args['selection']);
  r.setSelection(id, sel);
  return IpcResponse.ok(id: req.id, data: {'id': id});
}

Future<IpcResponse> _setContent(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  final content = EditorRegistry.contentFromArgs(req.args);
  final sel = req.args['selection'] == null
      ? null
      : EditorRegistry.selectionFromArgs(req.args['selection']);
  r.setContent(id, content, selection: sel);
  return IpcResponse.ok(id: req.id, data: {'id': id, 'length': content.length});
}

Future<IpcResponse> _save(IpcRequest req, EditorRegistry r) async {
  final id = _resolveId(req, r);
  if (id == null) return _notFound(req.id, 'no active buffer');
  final ok = await r.save(id);
  if (!ok) return _notFound(req.id, 'no such buffer: $id');
  return IpcResponse.ok(id: req.id, data: {'id': id, 'saved': true});
}

Future<IpcResponse> _close(IpcRequest req, EditorRegistry r) async {
  final id = req.args['id'] as String?;
  if (id == null) return _userErr(req.id, 'id is required');
  if (r.get(id) == null) return _notFound(req.id, 'no such buffer: $id');
  r.close(id);
  return IpcResponse.ok(id: req.id, data: {'id': id});
}

