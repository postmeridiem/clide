/// A bounded, most-recent-first list of repo-relative file paths opened
/// this session. Backs the quick-open overlay's empty-query state
/// (T-51). In-memory only — recents reset per app run, matching the
/// session-scoped "recently opened within a workspace" convention.
library;

import 'package:flutter/foundation.dart';

class RecentFilesService extends ChangeNotifier {
  RecentFilesService({this.cap = 20});

  /// Maximum number of paths retained; the oldest fall off the end.
  final int cap;

  final List<String> _paths = [];

  /// Most-recent-first snapshot of the retained paths.
  List<String> get paths => List.unmodifiable(_paths);

  /// Record [path] as the most-recently opened file: moves an existing
  /// entry to the front (no duplicates) and trims to [cap].
  void push(String path) {
    if (path.isEmpty) return;
    _paths.remove(path);
    _paths.insert(0, path);
    if (_paths.length > cap) _paths.removeRange(cap, _paths.length);
    notifyListeners();
  }

  void clear() {
    if (_paths.isEmpty) return;
    _paths.clear();
    notifyListeners();
  }
}
