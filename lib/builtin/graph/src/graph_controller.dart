/// Loads the whole vault's link graph from pql (T-323): lists every markdown
/// file (nodes), then fetches each file's `pql.meta` for its outlinks (edges)
/// and tags, assembling a [VaultGraph] plus a per-file tag map. Holds the file
/// glob + a client-side [GraphFilter] (tag include/exclude, depth-from-active)
/// and exposes the filtered [visibleGraph] the pane draws.
///
/// One `pql.meta` per file gives both outlinks and tags in a single call. Link
/// targets carry `#heading` fragments (`foo.md#bar`); those are stripped to the
/// file (`foo.md`) so a heading link still connects the two notes.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/graph/graph_filter.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:flutter/foundation.dart';

class GraphController extends ChangeNotifier {
  GraphController({required this.ipc, required this.events, String glob = '**/*.md', this.refreshDebounce = const Duration(milliseconds: 400)}) : _glob = glob {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final DaemonBus events;

  /// A save touches several `files.changed` events in a burst — coalesce them
  /// into one full reload rather than rebuilding the graph per file.
  final Duration refreshDebounce;

  String _glob;
  String get glob => _glob;

  StreamSubscription<DaemonEvent>? _eventSub;
  Timer? _debounce;

  VaultGraph _graph = const VaultGraph([], []);
  VaultGraph get graph => _graph;

  Map<String, Set<String>> _tagsByPath = const {};

  /// Every tag present in the loaded vault, sorted — what the filter UI offers.
  List<String> get availableTags {
    final all = <String>{for (final s in _tagsByPath.values) ...s};
    return all.toList()..sort();
  }

  String? _activePath;
  String? get activePath => _activePath;

  GraphFilter _filter = const GraphFilter();
  GraphFilter get filter => _filter;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// The graph after the active [filter] — what the pane draws.
  VaultGraph get visibleGraph => _filter.apply(_graph, tagsByPath: _tagsByPath, activePath: _activePath);

  /// List every in-scope file, fetch each one's meta (outlinks + tags), and
  /// rebuild the graph. A failed `pql.files` clears everything and surfaces the
  /// error; a failed per-file `pql.meta` just contributes no edges/tags for it.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final filesResp = await ipc.request('pql.files', args: {'glob': _glob});
    if (!filesResp.ok) {
      _graph = const VaultGraph([], []);
      _tagsByPath = const {};
      _error = filesResp.error?.message ?? 'pql.files failed';
      _loading = false;
      notifyListeners();
      return;
    }

    final paths = [
      for (final f in _castList(filesResp.data['files']))
        if (f['path'] is String) f['path'] as String,
    ];

    final outlinks = <String, List<String>>{};
    final tags = <String, Set<String>>{};
    for (final path in paths) {
      final resp = await ipc.request('pql.meta', args: {'path': path});
      if (!resp.ok) {
        outlinks[path] = const [];
        continue;
      }
      outlinks[path] = [
        for (final l in _castList(resp.data['outlinks']))
          if (l['target'] is String) _stripFragment(l['target'] as String),
      ].where((t) => t.isNotEmpty).toList();
      final t = resp.data['tags'];
      if (t is List) {
        final set = {
          for (final e in t)
            if (e is String) e,
        };
        if (set.isNotEmpty) tags[path] = set;
      }
    }

    _graph = VaultGraph.fromOutlinks(outlinks);
    _tagsByPath = tags;
    _loading = false;
    notifyListeners();
  }

  /// Change the file set the graph spans. An empty glob resets to all markdown.
  /// A real change re-queries pql; the same glob is a no-op.
  void setGlob(String glob) {
    final g = glob.trim().isEmpty ? '**/*.md' : glob.trim();
    if (g == _glob) return;
    _glob = g;
    unawaited(load());
  }

  /// Replace the client-side filter. No reload — [visibleGraph] recomputes.
  void setFilter(GraphFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem == 'editor' && e.kind == 'editor.active-changed') {
      final p = e.data['path'] as String?;
      if (p != _activePath) {
        _activePath = p;
        notifyListeners(); // a depth filter re-centres on the new active note
      }
      return;
    }
    if (e.subsystem != 'files') return;
    _debounce?.cancel();
    _debounce = Timer(refreshDebounce, () => unawaited(load()));
  }

  static String _stripFragment(String target) {
    final hash = target.indexOf('#');
    return hash < 0 ? target : target.substring(0, hash);
  }

  static List<Map<String, Object?>> _castList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) (e as Map).cast<String, Object?>()];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}
