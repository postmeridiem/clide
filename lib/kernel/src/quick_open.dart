/// State for the quick-open overlay (T-51): the workspace file list,
/// the fuzzy filter, and the highlighted row. Pure state — the overlay
/// widget loads the file list (via `files.walk`) and drives the actual
/// open. Mirrors [PaletteController]'s shape so the overlay can reuse
/// the palette's interaction model.
library;

import 'package:clide/kernel/src/fuzzy.dart';
import 'package:flutter/foundation.dart';

class QuickOpenController extends ChangeNotifier {
  QuickOpenController({required this.recentPaths});

  /// Supplies the empty-query suggestions (most-recent-first). Injected
  /// as a callback so the controller stays decoupled from the recents
  /// service itself.
  final List<String> Function() recentPaths;

  /// Cap on rendered results for a non-empty query — keeps the list
  /// widget bounded on large repos.
  static const int resultCap = 200;

  bool _open = false;
  String _filter = '';
  int _selectedIndex = 0;
  List<String> _files = const [];
  bool _loading = false;
  bool _truncated = false;

  bool get isOpen => _open;
  String get filter => _filter;
  bool get isLoading => _loading;

  /// True when the underlying `files.walk` hit its cap — the file list
  /// is incomplete and the UI should say so.
  bool get truncated => _truncated;

  /// Highlighted index, clamped into the current result list.
  int get selectedIndex {
    final n = filtered().length;
    if (n == 0) return 0;
    return _selectedIndex.clamp(0, n - 1);
  }

  /// Open the picker. An optional [seed] pre-fills the filter — used by the
  /// ex-line `:e <path>` command (T-407) to jump straight to a query.
  void open({String? seed}) {
    if (_open) return;
    _open = true;
    _filter = seed ?? '';
    _selectedIndex = 0;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _filter = '';
    _selectedIndex = 0;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  /// Toggle the loading indicator while the widget fetches the file list.
  void setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  /// Install the workspace file list (from `files.walk`).
  void setFiles(List<String> files, {bool truncated = false}) {
    _files = files;
    _truncated = truncated;
    _selectedIndex = 0;
    notifyListeners();
  }

  void setFilter(String f) {
    if (_filter == f) return;
    _filter = f;
    _selectedIndex = 0;
    notifyListeners();
  }

  void selectNext() {
    final n = filtered().length;
    if (n < 2) return;
    _selectedIndex = (selectedIndex + 1) % n;
    notifyListeners();
  }

  void selectPrevious() {
    final n = filtered().length;
    if (n < 2) return;
    _selectedIndex = (selectedIndex - 1 + n) % n;
    notifyListeners();
  }

  /// The path currently highlighted, or null when the result list is
  /// empty.
  String? get selectedPath {
    final list = filtered();
    if (list.isEmpty) return null;
    return list[selectedIndex];
  }

  /// The visible result list. An empty query shows recents; otherwise a
  /// subsequence fuzzy match over the file paths, ranked best-first and
  /// capped at [resultCap].
  List<String> filtered() {
    if (_filter.trim().isEmpty) return recentPaths();
    final q = _filter.toLowerCase().trim();
    final scored = <_Scored>[];
    for (final p in _files) {
      final s = fuzzyScore(p.toLowerCase(), q);
      if (s != null) scored.add(_Scored(p, s));
    }
    scored.sort((a, b) {
      final c = a.score.compareTo(b.score); // lower is better
      if (c != 0) return c;
      return a.path.length.compareTo(b.path.length);
    });
    return [for (final s in scored.take(resultCap)) s.path];
  }
}

class _Scored {
  _Scored(this.path, this.score);
  final String path;
  final int score;
}
