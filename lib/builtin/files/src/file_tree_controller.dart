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
import 'dart:io' show Platform;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

/// One row in the flattened, currently-visible tree (T-406). The visible set is
/// a pre-order walk of the root plus the children of every expanded directory —
/// the same order the tree renders — so a selection cursor can move over it with
/// j/k.
@immutable
class TreeNode {
  const TreeNode({required this.path, required this.name, required this.isDirectory, required this.depth});

  final String path;
  final String name;
  final bool isDirectory;
  final int depth;
}

class FileTreeController extends ChangeNotifier {
  FileTreeController({required this.ipc, required this.events}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final DaemonBus events;

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

  /// Display name of the workspace root row ('' path).
  String get rootName => _rootPath?.split(Platform.pathSeparator).last ?? '';

  // -- Keyboard selection cursor (T-406) -------------------------------------

  /// The path of the currently selected row, or null when nothing is selected.
  /// '' is the workspace-root row.
  String? _selectedPath;
  String? get selectedPath => _selectedPath;

  /// The flattened, currently-visible rows in render order: the root, then the
  /// children of every expanded directory, depth-first.
  List<TreeNode> visibleNodes() {
    final out = <TreeNode>[];
    if (_rootPath == null) return out;
    out.add(TreeNode(path: '', name: rootName, isDirectory: true, depth: 0));
    if (isExpanded('')) _appendChildren('', 1, out);
    return out;
  }

  void _appendChildren(String path, int depth, List<TreeNode> out) {
    final entries = _entries[path];
    if (entries == null) return;
    for (final e in entries) {
      out.add(TreeNode(path: e.path, name: e.name, isDirectory: e.isDirectory, depth: depth));
      if (e.isDirectory && _expanded.contains(e.path)) _appendChildren(e.path, depth + 1, out);
    }
  }

  TreeNode? _selectedNode([List<TreeNode>? nodes]) {
    final list = nodes ?? visibleNodes();
    for (final n in list) {
      if (n.path == _selectedPath) return n;
    }
    return null;
  }

  /// Move the selection cursor [delta] rows (negative = up), clamped to the
  /// visible list. A first move with nothing selected lands on the first row
  /// (down) or last row (up).
  void moveSelection(int delta) {
    final nodes = visibleNodes();
    if (nodes.isEmpty) return;
    final cur = nodes.indexWhere((n) => n.path == _selectedPath);
    final next = cur < 0 ? (delta > 0 ? 0 : nodes.length - 1) : (cur + delta).clamp(0, nodes.length - 1);
    if (nodes[next].path == _selectedPath) return;
    _selectedPath = nodes[next].path;
    notifyListeners();
  }

  /// Select the first ([top]) or last visible row — vim gg / G.
  void selectEdge({required bool top}) {
    final nodes = visibleNodes();
    if (nodes.isEmpty) return;
    final path = (top ? nodes.first : nodes.last).path;
    if (path == _selectedPath) return;
    _selectedPath = path;
    notifyListeners();
  }

  /// Collapse the selected directory, or — if it's already collapsed (or a
  /// file) — step the selection out to its parent row (vim `h`).
  Future<void> collapseOrOut() async {
    final node = _selectedNode();
    if (node == null) return;
    if (node.isDirectory && node.path != '' && _expanded.contains(node.path)) {
      await toggle(node.path); // collapse in place; selection stays on the dir
      return;
    }
    if (node.path == '') return; // already at root
    _selectedPath = _parentOf(node.path);
    notifyListeners();
  }

  /// Expand the selected directory, or — if it's already expanded — step the
  /// selection into its first child (vim `l`). A file is a no-op.
  Future<void> expandOrInto() async {
    final node = _selectedNode();
    if (node == null || !node.isDirectory) return;
    if (!_expanded.contains(node.path)) {
      await toggle(node.path); // expand
      return;
    }
    final children = _entries[node.path];
    if (children != null && children.isNotEmpty) {
      _selectedPath = children.first.path;
      notifyListeners();
    }
  }

  /// Resolve the selected row to an action target for the view: a directory to
  /// toggle, or a file path to open (vim `o` / `enter`). Returns null when
  /// nothing is selected.
  ({bool isDirectory, String path})? activateTarget() {
    final node = _selectedNode();
    if (node == null) return null;
    return (isDirectory: node.isDirectory, path: node.path);
  }

  List<FileEntry> allLoadedEntries() {
    final out = <FileEntry>[];
    for (final list in _entries.values) {
      out.addAll(list.where((e) => !e.isDirectory));
    }
    return out;
  }

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
