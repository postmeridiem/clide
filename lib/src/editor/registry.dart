/// [EditorRegistry] — daemon-side state for open editor buffers.
///
/// Owns a set of [EditorBuffer]s keyed by id. At most one buffer is
/// `active` at a time — the UI tells the daemon which one it's
/// focused on via `editor.activate`. All state transitions emit
/// events through the [DaemonEventSink].
library;

import 'dart:convert';
import 'dart:io';

import '../ipc/envelope.dart';
import '../panes/event_sink.dart';
import 'buffer.dart';

class EditorRegistry {
  EditorRegistry({
    required this.events,
    required this.workspaceRoot,
  });

  final DaemonEventSink events;

  /// Workspace root used to resolve repo-relative paths to disk.
  final Directory workspaceRoot;

  final Map<String, EditorBuffer> _buffers = {};
  final Map<String, String> _pathToId = {}; // repo-rel path → id
  int _nextId = 1;
  String? _activeId;

  Iterable<EditorBuffer> get buffers => _buffers.values;
  EditorBuffer? get(String id) => _buffers[id];
  EditorBuffer? get active => _activeId == null ? null : _buffers[_activeId!];

  /// Open a file. If [path] is already open, returns the existing
  /// buffer (no re-read from disk — the in-memory content is the
  /// source of truth between save points).
  Future<EditorBuffer> open(String path) async {
    final existing = _pathToId[path];
    if (existing != null) {
      final buf = _buffers[existing]!;
      _setActive(buf.id);
      return buf;
    }

    final absolute = _absolutePathOf(path);
    final file = File(absolute);
    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    }

    final id = 'b_${_nextId++}';
    final buf = EditorBuffer(id: id, path: path, content: content);
    _buffers[id] = buf;
    _pathToId[path] = id;

    _emit('editor.opened', {
      ...buf.toJson(),
      'content': buf.content, // snapshot at open time
    });
    _setActive(id);
    return buf;
  }

  /// Mark [id] as the active buffer. Idempotent.
  void activate(String id) {
    if (!_buffers.containsKey(id)) return;
    _setActive(id);
  }

  /// Insert [text] at the buffer's cursor (or replace the selection
  /// if one exists). Advances the cursor past the inserted text.
  void insert(String id, String text) {
    final buf = _buffers[id];
    if (buf == null) return;
    final sel = buf.selection;
    final before = buf.content.substring(0, sel.start);
    final after = buf.content.substring(sel.end);
    buf.content = '$before$text$after';
    final newCaret = sel.start + text.length;
    buf.selection = Selection.collapsed(newCaret);
    buf.dirty = true;
    _emit('editor.edited', {
      'id': id,
      'kind': 'insert',
      'inserted': text,
      'at': sel.start,
      'replaced': sel.length,
      'length': buf.content.length,
      'selection': buf.selection.toJson(),
    });
    _emitSelection(buf);
  }

  /// Replace the current selection (or insert at cursor if no
  /// selection) with [text]. Same mechanic as [insert] — kept as a
  /// named verb because the CLI surface exposes it separately per
  /// CLAUDE.md's tier-2 list.
  void replaceSelection(String id, String text) => insert(id, text);

  /// Update the UI's cursor / selection for [id]. Broadcasts so other
  /// subscribers can mirror it.
  void setSelection(String id, Selection sel) {
    final buf = _buffers[id];
    if (buf == null) return;
    final clamped = Selection(
      start: sel.start.clamp(0, buf.content.length),
      end: sel.end.clamp(0, buf.content.length),
    );
    if (clamped.start == buf.selection.start && clamped.end == buf.selection.end) {
      return;
    }
    buf.selection = clamped;
    _emitSelection(buf);
  }

  /// Overwrite [id]'s content (used when the UI owns authoritative
  /// text — diff-style editor, paste, etc.) and reconcile the
  /// registry's view. Emits a single `editor.edited` event with
  /// kind='replace' so subscribers don't need to diff.
  void setContent(String id, String content, {Selection? selection}) {
    final buf = _buffers[id];
    if (buf == null) return;
    buf.content = content;
    if (selection != null) {
      buf.selection = Selection(
        start: selection.start.clamp(0, content.length),
        end: selection.end.clamp(0, content.length),
      );
    } else {
      buf.selection = Selection(
        start: buf.selection.start.clamp(0, content.length),
        end: buf.selection.end.clamp(0, content.length),
      );
    }
    buf.dirty = true;
    _emit('editor.edited', {
      'id': id,
      'kind': 'replace',
      'length': content.length,
      'selection': buf.selection.toJson(),
    });
  }

  /// Persist [id] to disk. Clears the dirty flag on success.
  Future<bool> save(String id) async {
    final buf = _buffers[id];
    if (buf == null) return false;
    final absolute = _absolutePathOf(buf.path);
    await File(absolute).writeAsString(buf.content);
    buf.dirty = false;
    _emit('editor.saved', {'id': id, 'path': buf.path});
    return true;
  }

  /// Close a buffer. Idempotent.
  void close(String id) {
    final buf = _buffers.remove(id);
    if (buf == null) return;
    _pathToId.remove(buf.path);
    if (_activeId == id) {
      _activeId = _buffers.values.isEmpty ? null : _buffers.values.first.id;
      if (_activeId != null) _emitActive();
    }
    _emit('editor.closed', {'id': id, 'path': buf.path});
  }

  Future<void> shutdown() async {
    _buffers.clear();
    _pathToId.clear();
    _activeId = null;
  }

  // -----------------------------------------------------------------

  void _setActive(String id) {
    if (_activeId == id) return;
    _activeId = id;
    _emitActive();
  }

  void _emitActive() {
    final buf = active;
    _emit('editor.active-changed', {
      'id': buf?.id,
      'path': buf?.path,
    });
  }

  void _emitSelection(EditorBuffer buf) {
    _emit('editor.selection-changed', {
      'id': buf.id,
      'selection': buf.selection.toJson(),
    });
  }

  void _emit(String kind, Map<String, Object?> data) {
    events.emit(IpcEvent(
      subsystem: 'editor',
      kind: kind,
      timestamp: DateTime.now().toUtc(),
      data: data,
    ));
  }

  String _absolutePathOf(String repoRelative) {
    if (repoRelative.startsWith('/')) return repoRelative;
    final sep = Platform.pathSeparator;
    return '${workspaceRoot.absolute.path}$sep${repoRelative.replaceAll('/', sep)}';
  }

  // Support JSON decode of Selection from IPC args.
  static Selection selectionFromArgs(Object? raw) {
    if (raw is! Map) return const Selection.collapsed(0);
    return Selection.fromJson(raw.cast<String, Object?>());
  }

  // Support JSON decode of content payloads (base64 for binary safety
  // or plain text).
  static String contentFromArgs(Map<String, Object?> args) {
    final text = args['text'];
    if (text is String) return text;
    final b64 = args['content_b64'];
    if (b64 is String) return utf8.decode(base64Decode(b64));
    return '';
  }
}
