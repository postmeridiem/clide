/// State model for the file-tree panel.
///
/// Owns a map of expanded directory → entries (lazy-loaded), the
/// workspace root path, and an IPC subscription to `files.changed`
/// events. Invalidation on events is coarse today — a change under
/// `a/b/` invalidates every currently-expanded directory that could
/// have been affected. Refinement (per-dir change tracking) is a
/// clear win once the tree gets large.
library;

import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class FileTreeController extends ChangeNotifier {
  FileTreeController({required this.ipc, required this.events}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final EventBus events;

  StreamSubscription<DaemonEvent>? _eventSub;

  String? _rootPath;
  String? get rootPath => _rootPath;

  String? _error;
  String? get error => _error;

  bool _watchSubscribed = false;

  final Set<String> _expanded = {''}; // '' = workspace root
  bool isExpanded(String path) => _expanded.contains(path);

  final Map<String, List<FileEntry>> _entries = {};
  List<FileEntry>? entriesFor(String path) => _entries[path];

  /// Initial boot: resolve the workspace root, load the root dir,
  /// subscribe to `files.changed` events.
  Future<void> load() async {
    final rootResp = await ipc.request('files.root');
    if (!rootResp.ok) {
      _error = rootResp.error?.message ?? 'files.root failed';
      notifyListeners();
      return;
    }
    _rootPath = rootResp.data['path'] as String?;

    final watchResp = await ipc.request('files.watch');
    _watchSubscribed = watchResp.ok;

    await _loadDir('');
    notifyListeners();
  }

  Future<void> toggle(String path) async {
    if (_expanded.contains(path)) {
      _expanded.remove(path);
      notifyListeners();
    } else {
      _expanded.add(path);
      if (!_entries.containsKey(path)) {
        await _loadDir(path);
      }
      notifyListeners();
    }
  }

  Future<void> refresh(String path) async {
    await _loadDir(path);
    notifyListeners();
  }

  Future<void> _loadDir(String path) async {
    final r = await ipc.request('files.ls', args: {'path': path});
    if (!r.ok) {
      _error = r.error?.message ?? 'files.ls($path) failed';
      return;
    }
    final raw = (r.data['entries'] as List?) ?? const [];
    _entries[path] = [
      for (final e in raw.whereType<Map>())
        FileEntry(
          name: e['name']! as String,
          path: e['path']! as String,
          isDirectory: e['isDirectory']! as bool,
          isSymlink: (e['isSymlink'] as bool?) ?? false,
          sizeBytes: (e['sizeBytes'] as num?)?.toInt(),
          modifiedMs: (e['modifiedMs'] as num?)?.toInt(),
        ),
    ];
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'files') return;
    if (e.kind != 'files.changed') return;
    // Coarse invalidation: reload the parent directory of the change,
    // plus the root if the change is at top-level. This keeps the
    // tree accurate without optimistic local mutation.
    final path = (e.data['path'] as String?) ?? '';
    final parent = _parentOf(path);
    if (_entries.containsKey(parent)) {
      unawaited(refresh(parent));
    }
  }

  static String _parentOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  bool get watchSubscribed => _watchSubscribed;

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}
