/// State model for the find-in-files panel (T-52, per D-79).
///
/// Holds the query + option state, drives the `search.grep` IPC verb,
/// and accumulates streamed `search.match` events (scoped to the active
/// searchId) into a per-file grouping. Re-running cancels the prior
/// search; results from a stale search id are ignored.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/search/match.dart';
import 'package:flutter/foundation.dart';

class FindInFilesController extends ChangeNotifier {
  FindInFilesController({required this.ipc, required this.events}) {
    _sub = events.on<DaemonEvent>().listen(_onEvent);
  }

  final DaemonClient ipc;
  final DaemonBus events;
  StreamSubscription<DaemonEvent>? _sub;

  // -- Query state ----------------------------------------------------------
  String pattern = '';
  bool regex = false;
  bool ignoreCase = false;
  String includeGlobs = '';
  String excludeGlobs = '';
  String replacement = '';

  // -- Result state ---------------------------------------------------------
  String? _activeSearchId;
  final List<SearchMatch> _matches = [];
  bool _running = false;
  bool _done = false;
  String? _error;

  List<SearchMatch> get matches => List.unmodifiable(_matches);
  bool get running => _running;
  bool get done => _done;
  String? get error => _error;
  int get matchCount => _matches.length;

  /// Matches grouped by file path, preserving first-seen file order.
  Map<String, List<SearchMatch>> grouped() {
    final out = <String, List<SearchMatch>>{};
    for (final m in _matches) {
      (out[m.path] ??= []).add(m);
    }
    return out;
  }

  int get fileCount => grouped().length;

  void setRegex(bool v) {
    if (regex == v) return;
    regex = v;
    notifyListeners();
  }

  void setIgnoreCase(bool v) {
    if (ignoreCase == v) return;
    ignoreCase = v;
    notifyListeners();
  }

  set include(String v) => includeGlobs = v;
  set exclude(String v) => excludeGlobs = v;

  void setReplacement(String v) {
    if (replacement == v) return;
    replacement = v;
    notifyListeners();
  }

  /// True when the git working tree has no changes — the safety gate for
  /// applying a destructive multi-file replace (the user's chosen model:
  /// git is the lossless undo layer).
  Future<bool> isWorkingTreeClean() async {
    final r = await ipc.request('git.status');
    return r.ok && r.data['clean'] == true;
  }

  /// Apply the current replacement across all matches, then refresh the
  /// results. Returns the number of files changed and matches replaced.
  /// Callers must gate on [isWorkingTreeClean] + user confirmation first.
  Future<({int files, int count})> applyReplace() async {
    final r = await ipc.request(
      'search.replace',
      args: {
        'pattern': pattern,
        'regex': regex,
        'ignoreCase': ignoreCase,
        'include': _split(includeGlobs),
        'exclude': _split(excludeGlobs),
        'replacement': replacement,
        'apply': true,
      },
    );
    final files = (r.data['filesChanged'] as num?)?.toInt() ?? 0;
    final count = (r.data['totalCount'] as num?)?.toInt() ?? 0;
    await run(pattern); // refresh the match list against the new content
    return (files: files, count: count);
  }

  /// The query the panel is currently running (for preview rendering).
  SearchQuery get query => SearchQuery(pattern: pattern, regex: regex, ignoreCase: ignoreCase);

  /// Start a search with the current query/options. Cancels any
  /// in-flight search first and clears prior results.
  Future<void> run(String query) async {
    pattern = query;
    if (_activeSearchId != null) {
      unawaited(ipc.request('search.cancel', args: {'searchId': _activeSearchId}));
      _activeSearchId = null;
    }
    _matches.clear();
    _error = null;
    _done = false;
    if (pattern.trim().isEmpty) {
      _running = false;
      notifyListeners();
      return;
    }
    _running = true;
    notifyListeners();

    final resp = await ipc.request(
      'search.grep',
      args: {'pattern': pattern, 'regex': regex, 'ignoreCase': ignoreCase, 'include': _split(includeGlobs), 'exclude': _split(excludeGlobs)},
    );
    if (!resp.ok) {
      _error = resp.error?.message ?? 'search failed';
      _running = false;
      notifyListeners();
      return;
    }
    _activeSearchId = resp.data['searchId'] as String?;
  }

  /// Stop the in-flight search, if any.
  void cancel() {
    if (_activeSearchId != null) {
      unawaited(ipc.request('search.cancel', args: {'searchId': _activeSearchId}));
      _activeSearchId = null;
    }
    _running = false;
    notifyListeners();
  }

  /// Open a match in the editor at its line (search always lands on the
  /// source line, even for `.md`, which the reader can't position).
  void openMatch(SearchMatch m) {
    unawaited(ipc.request('editor.open', args: {'path': m.path, 'line': m.line}));
  }

  void _onEvent(DaemonEvent e) {
    if (e.subsystem != 'search') return;
    if (e.data['searchId'] != _activeSearchId) return; // stale / cancelled
    switch (e.kind) {
      case 'search.match':
        final raw = (e.data['matches'] as List?) ?? const [];
        for (final m in raw.whereType<Map>()) {
          _matches.add(SearchMatch.fromJson(m.cast<String, Object?>()));
        }
        notifyListeners();
      case 'search.done':
        _running = false;
        _done = true;
        _activeSearchId = null;
        notifyListeners();
      case 'search.error':
        _error = e.data['message'] as String? ?? 'search error';
        _running = false;
        _activeSearchId = null;
        notifyListeners();
    }
  }

  static List<String> _split(String s) => s.split(RegExp(r'[,\s]+')).where((x) => x.isNotEmpty).toList();

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
