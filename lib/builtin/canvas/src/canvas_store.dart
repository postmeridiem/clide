/// The canvas extension's document store (T-570).
///
/// Lifted out of `_CanvasDocumentTabState` so the working document is
/// reachable from outside the widget tree: the `canvas.*` CLI verbs drive
/// the very same state the pane renders, which is what keeps them from
/// diverging. Editing the file on disk instead would be silently undone the
/// next time the user dragged anything.
///
/// App-scoped on the extension, next to the `MultitabController` it mirrors
/// (the diff/T-233 pattern), so open documents survive the pane being torn
/// down while another workspace tab is active.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:clide/src/daemon/canvas_commands.dart' show CanvasDocuments;
import 'package:flutter/foundation.dart';

/// One open document: loading, loaded, or failed. Exactly one of [doc] and
/// [error] is set once [loading] is false.
class CanvasDocumentEntry {
  const CanvasDocumentEntry({this.doc, this.error, this.loading = false});

  final CanvasDoc? doc;
  final String? error;
  final bool loading;
}

class CanvasDocumentStore extends ChangeNotifier implements CanvasDocuments {
  CanvasDocumentStore({required this.ipc, required this.messages, required this.i18n});

  final DaemonClient ipc;
  final MessageBus messages;
  final I18n i18n;

  final Map<String, CanvasDocumentEntry> _entries = {};

  /// One write at a time per document. [CanvasView] reports once per
  /// gesture, but a fast sequence of drags (or a burst of CLI verbs) would
  /// otherwise overlap writes to one file and land in completion order
  /// rather than edit order.
  final Set<String> _writing = {};
  final Map<String, CanvasDoc> _queued = {};

  @override
  List<String> get openPaths => _entries.keys.toList();

  @override
  CanvasDoc? doc(String path) => _entries[path]?.doc;

  CanvasDocumentEntry? entry(String path) => _entries[path];

  /// Load [path] unless it's already open. Idempotent — the pane calls this
  /// every time a tab builds.
  Future<void> open(String path) async {
    if (_entries.containsKey(path)) return;
    // Recorded but NOT announced: open() is called from the tab's
    // didChangeDependencies, i.e. during build, and notifying there would
    // mark an already-building widget dirty. Nothing is missed — a tab with
    // no loaded document renders the loading state either way, and the load
    // completing notifies for real.
    _entries[path] = const CanvasDocumentEntry(loading: true);

    final resp = await ipc.request('files.read', args: {'path': path});
    if (!resp.ok) {
      _entries[path] = CanvasDocumentEntry(error: resp.error?.message ?? path);
      notifyListeners();
      return;
    }
    try {
      _entries[path] = CanvasDocumentEntry(doc: CanvasDoc.parse(resp.data['content'] as String? ?? ''));
    } on FormatException catch (e) {
      _entries[path] = CanvasDocumentEntry(error: e.message);
    }
    notifyListeners();
  }

  /// Forget [path] — the tab closed, or the workspace switched.
  void close(String path) {
    if (_entries.remove(path) == null) return;
    _queued.remove(path);
    notifyListeners();
  }

  void closeAll() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _queued.clear();
    notifyListeners();
  }

  /// Replace [path]'s document and persist it. A no-op when the path isn't
  /// open — the CLI checks first and reports a proper error, and the pane
  /// can't edit a document it isn't showing.
  @override
  Future<void> apply(String path, CanvasDoc next) async {
    final current = _entries[path];
    if (current == null) return;
    _entries[path] = CanvasDocumentEntry(doc: next);
    notifyListeners();
    await _save(path, next);
  }

  /// Persist, coalescing anything that arrives mid-write down to the latest
  /// — an intermediate drag position isn't worth a second round trip.
  Future<void> _save(String path, CanvasDoc doc) async {
    if (_writing.contains(path)) {
      _queued[path] = doc;
      return;
    }
    _writing.add(path);
    try {
      var pending = doc;
      while (true) {
        final resp = await ipc.request('files.write', args: {'path': path, 'text': pending.encode()});
        if (!resp.ok) _reportSaveFailure(path, resp.error?.message ?? '');
        final next = _queued.remove(path);
        if (next == null) return;
        pending = next;
      }
    } finally {
      _writing.remove(path);
    }
  }

  /// A failed save is a toast, not a pane replacement: the canvas on screen
  /// is still the user's work, and blanking it would lose the edit they were
  /// trying to keep.
  void _reportSaveFailure(String path, String reason) {
    publishToast(
      messages,
      'builtin.canvas',
      i18n.interpolated(
        'save.failed',
        namespace: 'builtin.canvas',
        placeholder: 'Could not save {path}: {reason}',
        replacers: [
          I18nReplacer(from: '{path}', replace: path),
          I18nReplacer(from: '{reason}', replace: reason),
        ],
      ),
      severity: ToastSeverity.error,
    );
  }

  @override
  void dispose() {
    _entries.clear();
    _queued.clear();
    super.dispose();
  }
}
