/// Tracks the active file and fetches its backlinks + outlinks
/// from pql. Subscribes to editor.active-changed to auto-refresh.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

class BacklinksController extends ChangeNotifier {
  BacklinksController({required this.ipc, required this.events}) {
    _eventSub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final EventBus events;

  StreamSubscription<DaemonEvent>? _eventSub;

  String? _activePath;
  String? get activePath => _activePath;

  List<Map<String, Object?>> _backlinks = const [];
  List<Map<String, Object?>> get backlinks => _backlinks;

  List<Map<String, Object?>> _outlinks = const [];
  List<Map<String, Object?>> get outlinks => _outlinks;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> loadForPath(String path) async {
    _activePath = path;
    _loading = true;
    _error = null;
    notifyListeners();

    final bl = await ipc.request('pql.backlinks', args: {'path': path});
    final ol = await ipc.request('pql.outlinks', args: {'path': path});

    _loading = false;
    _backlinks = bl.ok ? _castList(bl.data['links']) : const [];
    _outlinks = ol.ok ? _castList(ol.data['links']) : const [];
    if (!bl.ok && !ol.ok) {
      _error = bl.error?.message ?? 'backlinks failed';
    }
    notifyListeners();
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'editor') return;
    if (e.kind != 'editor.active-changed') return;
    final path = e.data['path'] as String?;
    if (path != null && path != _activePath) {
      unawaited(loadForPath(path));
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
