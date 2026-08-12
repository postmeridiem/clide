/// State for the quick-open overlay (T-51): the workspace file list,
/// the fuzzy filter, and the highlighted row. Pure state — the overlay
/// widget loads the file list (via `files.walk`) and drives the actual
/// open. Mirrors [PaletteController]'s shape so the overlay can reuse
/// the palette's interaction model.
///
/// Two modes (T-571). [open] is the T-51 behaviour: accepting a row opens
/// the file. [pick] instead *returns* the chosen path to a caller and opens
/// nothing — what the canvas needs to add a note node. It is a mode rather
/// than a second controller-and-overlay pair because everything else about
/// the surface (the walk, the fuzzy filter, recents, the keymap scope, the
/// list widget) is identical; a sibling would be a 230-line copy.
library;

import 'dart:async';

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

  /// Set while a [pick] is in flight — the caller waiting for a path.
  Completer<String?>? _pending;

  /// Optional caller-supplied line shown above the results, so a picker
  /// doesn't look like an ordinary quick-open.
  String? _prompt;

  bool get isOpen => _open;
  String get filter => _filter;
  bool get isLoading => _loading;

  /// True when the overlay is collecting a path for a caller rather than
  /// opening the file itself.
  bool get isPicking => _pending != null;

  /// The picker's prompt line, or null in ordinary quick-open.
  String? get prompt => _prompt;

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
    // A stale pick would otherwise leave its caller waiting forever while
    // the surface it was watching now belongs to an ordinary open.
    _resolve(null);
    _prompt = null;
    _open = true;
    _filter = seed ?? '';
    _selectedIndex = 0;
    notifyListeners();
  }

  /// Show the picker and resolve to the path the user chooses, or null if
  /// they dismiss it. Nothing is opened — the caller decides what the path
  /// means (the canvas turns it into a file node).
  ///
  /// Taking over an already-open picker resolves the previous request with
  /// null rather than refusing: the newest request wins and, more
  /// importantly, no caller is ever left awaiting a future that can't
  /// complete.
  Future<String?> pick({String? seed, String? prompt}) {
    _resolve(null);
    final completer = Completer<String?>();
    _pending = completer;
    _prompt = prompt;
    _open = true;
    _filter = seed ?? '';
    _selectedIndex = 0;
    notifyListeners();
    return completer.future;
  }

  void close() {
    if (!_open) {
      // Defensive: a pick can only exist while open, but resolving here too
      // means no code path can strand a caller.
      _resolve(null);
      return;
    }
    _open = false;
    _filter = '';
    _selectedIndex = 0;
    _prompt = null;
    _resolve(null);
    notifyListeners();
  }

  /// Hand [path] to a waiting [pick] and close. Returns false when nothing
  /// was waiting, which tells the overlay to perform the ordinary open
  /// instead.
  bool resolvePick(String? path) {
    if (_pending == null) return false;
    _open = false;
    _filter = '';
    _selectedIndex = 0;
    _prompt = null;
    _resolve(path);
    notifyListeners();
    return true;
  }

  void _resolve(String? path) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(path);
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

  /// Teardown (workspace switch, app exit) must not strand a caller mid-await.
  @override
  void dispose() {
    _resolve(null);
    super.dispose();
  }
}

class _Scored {
  _Scored(this.path, this.score);
  final String path;
  final int score;
}
