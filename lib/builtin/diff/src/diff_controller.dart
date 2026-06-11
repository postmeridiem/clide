/// State model for the diff workspace tab.
///
/// Holds the parsed diff data for a single file (or all files). Hydrates
/// via `git.diff` IPC, subscribes to `git.changed` events to refresh.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class DiffController extends ChangeNotifier {
  DiffController({required this.ipc, required this.events}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final DaemonBus events;

  StreamSubscription<DaemonEvent>? _eventSub;

  List<Map<String, Object?>> _diffs = const [];
  List<Map<String, Object?>> get diffs => _diffs;

  bool _staged = false;
  bool get showStaged => _staged;

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  String? _focusPath;

  /// The file the view should scroll into view + highlight (T-233), set by
  /// [focus] when `clide ui open diff <path>` (or a UI reveal) targets a file.
  /// Null until something focuses a path; cleared when that file leaves the
  /// diff (e.g. its changes are reverted).
  String? get focusPath => _focusPath;

  /// Focus [path] within the working-tree diff (T-233): record it so the view
  /// scrolls it into view + highlights it, and reload so the latest edits to
  /// that file are present even if the `git.changed` refresh hasn't landed yet.
  /// Revealing the diff tab itself is the caller's job (the diff extension).
  void focus(String path) {
    _focusPath = path;
    notifyListeners();
    unawaited(load(staged: _staged));
  }

  /// Load diffs. Optionally filter to [paths] and toggle [staged].
  Future<void> load({bool staged = false, List<String> paths = const []}) async {
    _staged = staged;
    _loading = true;
    notifyListeners();

    final r = await ipc.request('git.diff', args: {'staged': staged, if (paths.isNotEmpty) 'paths': paths});

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message ?? 'git.diff failed';
      notifyListeners();
      return;
    }

    _error = null;
    _diffs = _castList(r.data['diffs']);
    // Drop a focus whose file no longer has changes, so the view doesn't keep
    // a highlight on something that's gone.
    if (_focusPath != null && !_diffs.any((d) => d['path'] == _focusPath)) {
      _focusPath = null;
    }
    notifyListeners();
  }

  void toggleStaged() {
    unawaited(load(staged: !_staged));
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'git') return;
    if (e.kind == 'git.changed') {
      unawaited(load(staged: _staged));
    }
  }

  static List<Map<String, Object?>> _castList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) (e as Map).cast<String, Object?>()];
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    super.dispose();
  }
}
