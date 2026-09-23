/// [EditorRegistry] — daemon-side state for open editor buffers.
///
/// Owns a set of [EditorBuffer]s keyed by id. At most one buffer is
/// `active` at a time — the UI tells the daemon which one it's
/// focused on via `editor.activate`. All state transitions emit
/// events through the [DaemonEventSink].
library;

import 'dart:async';
import 'dart:io';

import '../files/path_safety.dart';
import '../ipc/content_args.dart' as ipc_content;
import '../ipc/envelope.dart';
import '../panes/event_sink.dart';
import 'buffer.dart';
import 'editor_settings_resolver.dart';

class EditorRegistry {
  EditorRegistry({required this.events, required this.workspaceRoot, this.editorConfigDebounce = const Duration(milliseconds: 200)});

  final DaemonEventSink events;

  /// How long [onFileChanged] waits for `.editorconfig` changes to settle.
  final Duration editorConfigDebounce;

  /// Workspace root used to resolve repo-relative paths to disk.
  final Directory workspaceRoot;

  final Map<String, EditorBuffer> _buffers = {};
  final Map<String, String> _pathToId = {}; // repo-rel path → id
  int _nextId = 1;
  String? _activeId;
  Timer? _configDebounce;
  final Set<String> _pendingConfigDirs = {}; // dirs of changed .editorconfigs

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
    final buf = EditorBuffer(id: id, path: path, content: content, settings: resolveEditorSettings(workspaceRoot, path));
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
    final clamped = Selection(start: sel.start.clamp(0, buf.content.length), end: sel.end.clamp(0, buf.content.length));
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
      buf.selection = Selection(start: selection.start.clamp(0, content.length), end: selection.end.clamp(0, content.length));
    } else {
      buf.selection = Selection(start: buf.selection.start.clamp(0, content.length), end: buf.selection.end.clamp(0, content.length));
    }
    buf.dirty = true;
    _emit('editor.edited', {'id': id, 'kind': 'replace', 'length': content.length, 'selection': buf.selection.toJson()});
  }

  /// Persist [id] to disk. Applies the buffer's on-save settings (EOL,
  /// trailing-whitespace, final-newline) first, and — when those changed the
  /// text — reconciles the in-memory buffer + UI so disk and buffer agree.
  /// Clears the dirty flag on success. Saving a `.editorconfig` re-resolves the
  /// settings of every open buffer (its rules just changed).
  Future<bool> save(String id) async {
    final buf = _buffers[id];
    if (buf == null) return false;

    final normalized = buf.settings.applyOnSave(buf.content);
    final changed = normalized != buf.content;

    final absolute = _absolutePathOf(buf.path);
    await File(absolute).writeAsString(normalized);

    if (changed) {
      buf.content = normalized;
      buf.selection = Selection(start: buf.selection.start.clamp(0, normalized.length), end: buf.selection.end.clamp(0, normalized.length));
      // Re-broadcast so the UI reloads the normalized text (the editor.edited
      // handler re-reads the buffer); emitted before editor.saved clears dirty.
      buf.dirty = false;
      _emit('editor.edited', {'id': id, 'kind': 'replace', 'length': normalized.length, 'selection': buf.selection.toJson()});
    }

    buf.dirty = false;
    _emit('editor.saved', {'id': id, 'path': buf.path});

    if (_isEditorConfigPath(buf.path)) reresolveSettings();
    return true;
  }

  /// Tell the registry a workspace file changed on disk (repo-relative path,
  /// from the files watcher). A `.editorconfig` change made outside clide — another
  /// editor, a branch switch — re-resolves the open buffers it can affect
  /// (T-291). Debounced: a checkout touching several configs, or an editor's
  /// write-rename dance, settles into one pass.
  void onFileChanged(String path) {
    if (!_isEditorConfigPath(path)) return;
    final slash = path.lastIndexOf('/');
    _pendingConfigDirs.add(slash == -1 ? '' : path.substring(0, slash));
    _configDebounce?.cancel();
    _configDebounce = Timer(editorConfigDebounce, () {
      _configDebounce = null;
      final dirs = _pendingConfigDirs.toList();
      _pendingConfigDirs.clear();
      reresolveSettings(under: dirs);
    });
  }

  /// Recompute open buffers' effective settings from their sources and tell
  /// the UI about the ones that changed. Called when a `.editorconfig` is saved
  /// in-app or changes on disk (the file's rules changed under the open
  /// buffers). With [under], only buffers inside one of those repo-relative
  /// directories are checked (`''` is the workspace root) — a config can only
  /// affect files at or below its own directory.
  void reresolveSettings({Iterable<String>? under}) {
    for (final buf in _buffers.values) {
      if (under != null && !under.any((dir) => _isUnder(buf.path, dir))) continue;
      final next = resolveEditorSettings(workspaceRoot, buf.path);
      if (next.toJson().toString() == buf.settings.toJson().toString()) continue;
      buf.settings = next;
      _emit('editor.settings-changed', {'id': buf.id, 'path': buf.path, 'editorSettings': next.toJson()});
    }
  }

  bool _isEditorConfigPath(String path) => path == '.editorconfig' || path.endsWith('/.editorconfig');

  /// Whether buffer [path] sits in repo-relative directory [dir]. Buffers may be
  /// opened by absolute path, so strip the workspace prefix first.
  bool _isUnder(String path, String dir) {
    if (dir.isEmpty) return true;
    final rootPrefix = '${workspaceRoot.absolute.path}/';
    final rel = path.startsWith(rootPrefix) ? path.substring(rootPrefix.length) : path;
    return rel.startsWith('$dir/');
  }

  /// Close a buffer. Idempotent.
  void close(String id) {
    final buf = _buffers.remove(id);
    if (buf == null) return;
    _pathToId.remove(buf.path);
    if (_activeId == id) {
      // Promote the next buffer, or clear to null when this was the last one.
      // Emit active-changed in BOTH cases: a null id is the signal the editor
      // split collapses on (T-459). Guarding the emit on `_activeId != null`
      // suppressed exactly the last-buffer-closed event, leaving editorOpen
      // stuck true and the top split orphaned over the primary pane.
      _activeId = _buffers.values.isEmpty ? null : _buffers.values.first.id;
      _emitActive();
    }
    _emit('editor.closed', {'id': id, 'path': buf.path});
  }

  Future<void> shutdown() async {
    _configDebounce?.cancel();
    _configDebounce = null;
    _pendingConfigDirs.clear();
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
    _emit('editor.active-changed', {'id': buf?.id, 'path': buf?.path});
  }

  void _emitSelection(EditorBuffer buf) {
    _emit('editor.selection-changed', {'id': buf.id, 'selection': buf.selection.toJson()});
  }

  void _emit(String kind, Map<String, Object?> data) {
    events.emit(IpcEvent(subsystem: 'editor', kind: kind, timestamp: DateTime.now().toUtc(), data: data));
  }

  /// Resolve a buffer path to disk under the workspace root, with the
  /// same traversal/symlink containment as files.* (T-363). A buffer is
  /// a WRITE surface (save), so the D-80 extra read roots do not apply —
  /// strictly workspace-confined. Throws [PathOutsideRoot] on escape.
  String _absolutePathOf(String repoRelative) {
    final sep = Platform.pathSeparator;
    return resolveUnderRootFollowingSymlinks(workspaceRoot, repoRelative.replaceAll('/', sep));
  }

  // Support JSON decode of Selection from IPC args.
  static Selection selectionFromArgs(Object? raw) {
    if (raw is! Map) return const Selection.collapsed(0);
    return Selection.fromJson(raw.cast<String, Object?>());
  }

  // Support JSON decode of content payloads (base64 for binary safety
  // or plain text). Shared with `files.write` — see [contentFromArgs].
  static String contentFromArgs(Map<String, Object?> args) => ipc_content.contentFromArgs(args);
}
