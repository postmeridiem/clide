/// Flutter-side mirror of the daemon's active-editor state.
///
/// Listens to `editor.*` events over IPC and tracks: the active
/// buffer's id/path/content/selection, and whether the buffer is
/// dirty. The widget layer consumes this via [ListenableBuilder].
///
/// User edits flow the other way — the widget calls into the
/// controller, which calls `editor.set-content` / `editor.save` on
/// the daemon. The daemon is the source of truth; the widget is a
/// reconciled view.
library;

import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class EditorController extends ChangeNotifier {
  EditorController({required this.ipc, required EventBus events})
      : _events = events {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  // ignore: unused_field  — kept for future subscription changes
  final EventBus _events;

  StreamSubscription<DaemonEvent>? _eventSub;

  String? _activeId;
  String? _activePath;
  String _content = '';
  Selection _selection = const Selection.collapsed(0);
  bool _dirty = false;
  String? _error;

  bool _suppressNextRemoteEdit = false;
  int _pendingLocalEdits = 0;

  String? get activeId => _activeId;
  String? get activePath => _activePath;
  String get content => _content;
  Selection get selection => _selection;
  bool get dirty => _dirty;
  String? get error => _error;

  /// On first mount we don't know what (if anything) is already
  /// active. Ask the daemon.
  Future<void> hydrate() async {
    final r = await ipc.request('editor.active');
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return;
    }
    final active = r.data['active'];
    if (active is! Map) {
      _activeId = null;
      _activePath = null;
      _content = '';
      notifyListeners();
      return;
    }
    final id = active['id']! as String;
    await _loadBuffer(id);
  }

  Future<void> _loadBuffer(String id) async {
    final r = await ipc.request('editor.read', args: {'id': id});
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return;
    }
    _activeId = r.data['id']! as String;
    _activePath = r.data['path']! as String;
    _content = (r.data['content'] as String?) ?? '';
    final sel = r.data['selection'];
    _selection = sel is Map
        ? Selection.fromJson(sel.cast<String, Object?>())
        : const Selection.collapsed(0);
    _dirty = (r.data['dirty'] as bool?) ?? false;
    _error = null;
    notifyListeners();
  }

  /// Called by the widget on every local text edit.
  void pushLocalEdit({
    required String newContent,
    required Selection newSelection,
  }) {
    final id = _activeId;
    if (id == null) return;

    _content = newContent;
    _selection = newSelection;
    _dirty = true;
    notifyListeners();

    // Mirror to daemon. Use editor.set-content for the first cut —
    // it's coarse but simple and avoids diff computation. Future
    // tuning: diff + editor.insert / editor.replace-selection for
    // large buffers, so event broadcasts stay small.
    _pendingLocalEdits++;
    _suppressNextRemoteEdit = true;
    ipc.request('editor.set-content', args: {
      'id': id,
      'text': newContent,
      'selection': newSelection.toJson(),
    }).whenComplete(() => _pendingLocalEdits--);
  }

  Future<void> save() async {
    final id = _activeId;
    if (id == null) return;
    await ipc.request('editor.save', args: {'id': id});
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'editor') return;
    switch (e.kind) {
      case 'editor.opened':
      case 'editor.active-changed':
        final id = e.data['id'] as String?;
        if (id == null) {
          _activeId = null;
          _activePath = null;
          _content = '';
          _selection = const Selection.collapsed(0);
          _dirty = false;
          notifyListeners();
        } else if (id != _activeId) {
          _loadBuffer(id);
        }
      case 'editor.edited':
        // Our own set-content echoes back as editor.edited. Skip one
        // bounce so we don't clobber the caret the user just moved.
        if (_suppressNextRemoteEdit) {
          _suppressNextRemoteEdit = false;
          return;
        }
        // Remote edit (another client, or the CLI inserting bytes).
        // Reload the authoritative buffer.
        final id = e.data['id'] as String?;
        if (id != null && id == _activeId && _pendingLocalEdits == 0) {
          _loadBuffer(id);
        }
      case 'editor.saved':
        if (e.data['id'] == _activeId) {
          _dirty = false;
          notifyListeners();
        }
      case 'editor.closed':
        if (e.data['id'] == _activeId) {
          _activeId = null;
          _activePath = null;
          _content = '';
          _dirty = false;
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}
