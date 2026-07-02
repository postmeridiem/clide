/// Loads the whole vault's link graph from pql (T-323): lists every markdown
/// file (nodes), fetches each file's outlinks (edges), and assembles a
/// [VaultGraph]. Exposes loading/error state and coalesces file-change bursts
/// into one refresh.
///
/// pql has no bulk-outlinks query, so this is 1 `pql.files` + N `pql.outlinks`
/// calls — acceptable for an explicitly-opened, spinner-backed view. Batching
/// is a later optimisation, not a correctness concern.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/graph/vault_graph.dart';
import 'package:flutter/foundation.dart';

class GraphController extends ChangeNotifier {
  GraphController({required this.ipc, required this.events, this.glob = '**/*.md', this.refreshDebounce = const Duration(milliseconds: 400)}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final DaemonBus events;

  /// The file set the graph spans; the default is every markdown note.
  final String glob;

  /// A save touches several `files.changed` events in a burst — coalesce them
  /// into one full reload rather than rebuilding the graph per file.
  final Duration refreshDebounce;

  StreamSubscription<DaemonEvent>? _eventSub;
  Timer? _debounce;

  VaultGraph _graph = const VaultGraph([], []);
  VaultGraph get graph => _graph;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// List every in-scope file, fetch each one's outlinks, and rebuild the
  /// graph. A failed `pql.files` clears the graph and surfaces the error; a
  /// failed per-file `pql.outlinks` just contributes no edges for that file.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final filesResp = await ipc.request('pql.files', args: {'glob': glob});
    if (!filesResp.ok) {
      _graph = const VaultGraph([], []);
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
    for (final path in paths) {
      final resp = await ipc.request('pql.outlinks', args: {'path': path});
      outlinks[path] = resp.ok
          ? [
              for (final l in _castList(resp.data['links']))
                if (l['target'] is String) l['target'] as String,
            ]
          : const [];
    }

    _graph = VaultGraph.fromOutlinks(outlinks);
    _loading = false;
    notifyListeners();
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'files') return;
    _debounce?.cancel();
    _debounce = Timer(refreshDebounce, () => unawaited(load()));
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
