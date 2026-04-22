/// State model for the git sidebar panel.
///
/// Hydrates from `git.status` IPC on load, subscribes to `git.changed`
/// events to auto-refresh. Exposes stage/unstage/discard/commit actions
/// that call git.* IPC verbs and let the event-driven refresh handle
/// state reconciliation.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class GitController extends ChangeNotifier {
  GitController({required this.ipc, required this.events}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final EventBus events;

  StreamSubscription<DaemonEvent>? _eventSub;

  String? _branch;
  String? get branch => _branch;

  String? _upstream;
  String? get upstream => _upstream;

  int _ahead = 0;
  int get ahead => _ahead;

  int _behind = 0;
  int get behind => _behind;

  bool _clean = true;
  bool get isClean => _clean;

  bool _hasConflicts = false;
  bool get hasConflicts => _hasConflicts;

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  List<Map<String, Object?>> _staged = const [];
  List<Map<String, Object?>> get staged => _staged;

  List<Map<String, Object?>> _unstaged = const [];
  List<Map<String, Object?>> get unstaged => _unstaged;

  List<Map<String, Object?>> _untracked = const [];
  List<Map<String, Object?>> get untracked => _untracked;

  List<Map<String, Object?>> _conflicted = const [];
  List<Map<String, Object?>> get conflicted => _conflicted;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final r = await ipc.request('git.status');
    _loading = false;
    if (!r.ok) {
      _error = r.error?.message ?? 'git.status failed';
      notifyListeners();
      return;
    }

    _applyStatus(r.data);
    notifyListeners();
  }

  Future<bool> stage(List<String> paths) async {
    final r = await ipc.request('git.stage', args: {'paths': paths});
    return r.ok;
  }

  Future<bool> stageAll() async {
    final r = await ipc.request('git.stage-all');
    return r.ok;
  }

  Future<bool> unstage(List<String> paths) async {
    final r = await ipc.request('git.unstage', args: {'paths': paths});
    return r.ok;
  }

  Future<bool> discard(List<String> paths) async {
    final r = await ipc.request('git.discard', args: {'paths': paths});
    return r.ok;
  }

  Future<String?> commit(String message) async {
    final r = await ipc.request('git.commit', args: {'message': message});
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return null;
    }
    return r.data['hash'] as String?;
  }

  Future<bool> stash({String? message}) async {
    final r = await ipc.request('git.stash', args: {
      if (message != null) 'message': message,
    });
    return r.ok;
  }

  Future<bool> pull() async {
    final r = await ipc.request('git.pull');
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
    }
    return r.ok;
  }

  Future<bool> push() async {
    final r = await ipc.request('git.push');
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
    }
    return r.ok;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'git') return;
    if (e.kind == 'git.changed') {
      unawaited(load());
    }
  }

  void _applyStatus(Map<String, Object?> data) {
    _branch = data['branch'] as String?;
    _upstream = data['upstream'] as String?;
    _ahead = (data['ahead'] as num?)?.toInt() ?? 0;
    _behind = (data['behind'] as num?)?.toInt() ?? 0;
    _clean = data['clean'] as bool? ?? true;
    _hasConflicts = data['hasConflicts'] as bool? ?? false;
    _staged = _castList(data['staged']);
    _unstaged = _castList(data['unstaged']);
    _untracked = _castList(data['untracked']);
    _conflicted = _castList(data['conflicted']);
    _error = null;
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
