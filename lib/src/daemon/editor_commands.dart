/// Registers `editor.*` command handlers on a [DaemonDispatcher].
///
/// Verb list matches CLAUDE.md's tier-2 surface:
///   editor.open editor.active editor.activate editor.insert
///   editor.replace-selection editor.save editor.close editor.list
///   editor.read editor.set-selection editor.set-content
///
/// Single-word CLI shortcuts (`clide open`, `clide active`, …) map
/// one-to-one onto these via the IPC dispatch layer.
library;

import 'dart:io' show FileSystemException;

import '../editor/buffer.dart' show Selection;
import '../editor/registry.dart';
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/errno_mapping.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

export '../editor/buffer.dart' show Selection;

// Positional schemas so the CLI binds `clide editor <verb> <args…>` to the
// named keys the handlers read (T-232, via the D-74 normalize hook). Args are
// declared non-required — the handlers keep their own presence checks — so the
// only effect is positional→named mapping plus numeric coercion of `line`.
const _idArg = CommandSchema(positional: ['id'], args: {'id': ArgSpec()});

void registerEditorCommands(DaemonDispatcher d, EditorRegistry registry) {
  d.register(
    'editor.open',
    (req) => _open(req, registry),
    schema: const CommandSchema(
      positional: ['path', 'line'],
      args: {
        'path': ArgSpec(),
        'line': ArgSpec(type: ArgType.number),
      },
    ),
  );
  d.register('editor.active', (req) => _active(req, registry));
  d.register('editor.activate', (req) => _activate(req, registry), schema: _idArg);
  d.register('editor.list', (req) => _list(req, registry));
  d.register('editor.read', (req) => _read(req, registry), schema: _idArg);
  d.register('editor.insert', (req) => _insert(req, registry));
  d.register('editor.replace-selection', (req) => _replace(req, registry));
  d.register('editor.set-selection', (req) => _setSelection(req, registry));
  d.register('editor.set-content', (req) => _setContent(req, registry));
  d.register('editor.save', (req) => _save(req, registry), schema: _idArg);
  d.register('editor.close', (req) => _close(req, registry), schema: _idArg);
}

IpcResponse _userErr(String id, String msg, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: msg, hint: hint),
);

IpcResponse _notFound(String id, String msg) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: msg),
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
    // Optional 1-based line: jump the initial selection to that line's
    // start (used by find-in-files click-to-line, T-52). Out-of-range
    // lines clamp via setSelection. A non-numeric/<1 line is ignored.
    final rawLine = req.args['line'];
    final line = rawLine is num ? rawLine.toInt() : int.tryParse('$rawLine');
    if (line != null && line >= 1) {
      r.setSelection(buf.id, Selection.collapsed(_offsetForLine(buf.content, line)));
    }
    return IpcResponse.ok(id: req.id, data: buf.toJson());
  } on FileSystemException catch (e) {
    final errno = e.osError?.errorCode;
    if (errno != null) {
      return IpcResponse.err(
        id: req.id,
        error: errnoToIpcError(errno: errno, op: 'editor.open', target: path),
      );
    }
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'editor.open failed: ${e.message}'),
    );
  } catch (e) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'editor.open failed: $e'),
    );
  }
}

/// Byte offset of the start of the 1-based [line] in [content]. Lines
/// past the end clamp to the content length.
int _offsetForLine(String content, int line) {
  if (line <= 1) return 0;
  var remaining = line - 1;
  var i = 0;
  while (i < content.length && remaining > 0) {
    if (content.codeUnitAt(i) == 0x0A) remaining--;
    i++;
  }
  return i;
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
    data: {
      'buffers': [for (final b in r.buffers) b.toJson()],
    },
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
  final sel = req.args['selection'] == null ? null : EditorRegistry.selectionFromArgs(req.args['selection']);
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
