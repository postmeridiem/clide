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
  final EventBus events;

  StreamSubscription<DaemonEvent>? _eventSub;

  List<Map<String, Object?>> _diffs = const [];
  List<Map<String, Object?>> get diffs => _diffs;

  bool _staged = false;
  bool get showStaged => _staged;

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  /// Load diffs. Optionally filter to [paths] and toggle [staged].
  Future<void> load({
    bool staged = false,
    List<String> paths = const [],
  }) async {
    _staged = staged;
    _loading = true;
    notifyListeners();

    final r = await ipc.request('git.diff', args: {
      'staged': staged,
      if (paths.isNotEmpty) 'paths': paths,
    });

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message ?? 'git.diff failed';
      notifyListeners();
      return;
    }

    _error = null;
    _diffs = _castList(r.data['diffs']);
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
