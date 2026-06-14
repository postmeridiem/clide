/// Bounded in-memory retention for [Logger] records — the history the
/// output dock (T-54 / D-87) reads on open.
///
/// The [Logger] only live-broadcasts to its stream; a panel that opens late
/// would see nothing. [LogRing] is a sink that keeps the last `capacity`
/// records (drop-oldest, same shape as the D-85 event ring) plus enough
/// bookkeeping to drive the panel's filter dropdown (distinct `sources`) and
/// the status-bar health badge (level counts).
///
/// Flutter-free (only `dart:async`/`dart:collection` + the [LogRecord] type)
/// so it unit-tests without a widget harness. The UI wraps it; the ring
/// itself holds no view concerns.
library;

import 'dart:async';
import 'dart:collection';

import 'log.dart';

class LogRing {
  LogRing({this.capacity = 2000}) : assert(capacity > 0, 'capacity must be positive');

  /// Maximum retained records. Oldest are dropped past this.
  final int capacity;

  final ListQueue<LogRecord> _records = ListQueue<LogRecord>();
  // Per-source / per-level counts over the *retained* window, so [sources]
  // and [countAtLeast] stay accurate as records age out.
  final Map<String, int> _sourceCounts = {};
  final List<int> _levelCounts = List<int>.filled(LogLevel.values.length, 0);
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after any mutation (add or clear). Listeners re-read [records].
  Stream<void> get changes => _changes.stream;

  /// Snapshot of retained records, oldest first.
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// Distinct sources currently retained, sorted — drives the filter dropdown.
  List<String> get sources => _sourceCounts.keys.toList()..sort();

  int get length => _records.length;
  bool get isEmpty => _records.isEmpty;

  /// Append a record (the [Logger] sink). Drops the oldest past `capacity`.
  void add(LogRecord r) {
    _records.addLast(r);
    _sourceCounts.update(r.source, (n) => n + 1, ifAbsent: () => 1);
    _levelCounts[r.level.index]++;
    while (_records.length > capacity) {
      _decr(_records.removeFirst());
    }
    _notify();
  }

  /// Drop everything (the panel's "Clear" action).
  void clear() {
    if (_records.isEmpty) return;
    _records.clear();
    _sourceCounts.clear();
    for (var i = 0; i < _levelCounts.length; i++) {
      _levelCounts[i] = 0;
    }
    _notify();
  }

  /// Count of retained records at [level] or higher — e.g.
  /// `countAtLeast(LogLevel.warn)` for the status-badge warn+error total.
  int countAtLeast(LogLevel level) {
    var n = 0;
    for (var i = level.index; i < _levelCounts.length; i++) {
      n += _levelCounts[i];
    }
    return n;
  }

  void _decr(LogRecord r) {
    final c = _sourceCounts[r.source];
    if (c != null) {
      if (c <= 1) {
        _sourceCounts.remove(r.source);
      } else {
        _sourceCounts[r.source] = c - 1;
      }
    }
    _levelCounts[r.level.index]--;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}
