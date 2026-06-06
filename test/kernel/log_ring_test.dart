/// T-54: LogRing — bounded drop-oldest retention for Logger records, with
/// per-source / per-level bookkeeping for the panel filter + status badge.
library;

import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:flutter_test/flutter_test.dart';

LogRecord _rec(LogLevel level, String source, String message) =>
    LogRecord(level: level, source: source, message: message, timestamp: DateTime.utc(2026, 6, 6));

void main() {
  test('retains records in arrival order', () {
    final ring = LogRing(capacity: 10);
    ring
      ..add(_rec(LogLevel.info, 'ipc', 'a'))
      ..add(_rec(LogLevel.info, 'mcp', 'b'));
    expect(ring.records.map((r) => r.message), ['a', 'b']);
    expect(ring.length, 2);
  });

  test('drops oldest past capacity', () {
    final ring = LogRing(capacity: 3);
    for (final m in ['a', 'b', 'c', 'd', 'e']) {
      ring.add(_rec(LogLevel.info, 'ipc', m));
    }
    expect(ring.records.map((r) => r.message), ['c', 'd', 'e']);
  });

  test('sources are distinct, sorted, and shrink as records age out', () {
    final ring = LogRing(capacity: 2);
    ring
      ..add(_rec(LogLevel.info, 'git', '1'))
      ..add(_rec(LogLevel.info, 'ipc', '2'));
    expect(ring.sources, ['git', 'ipc']);
    // Pushing past capacity evicts the 'git' record → 'git' leaves the set.
    ring.add(_rec(LogLevel.info, 'pql', '3'));
    expect(ring.sources, ['ipc', 'pql']);
  });

  test('countAtLeast totals retained records at a level or higher', () {
    final ring = LogRing(capacity: 10);
    ring
      ..add(_rec(LogLevel.debug, 'x', 'd'))
      ..add(_rec(LogLevel.info, 'x', 'i'))
      ..add(_rec(LogLevel.warn, 'x', 'w'))
      ..add(_rec(LogLevel.error, 'x', 'e'));
    expect(ring.countAtLeast(LogLevel.warn), 2); // warn + error
    expect(ring.countAtLeast(LogLevel.error), 1);
    expect(ring.countAtLeast(LogLevel.trace), 4);
  });

  test('eviction decrements level counts', () {
    final ring = LogRing(capacity: 2);
    ring
      ..add(_rec(LogLevel.error, 'x', 'e1'))
      ..add(_rec(LogLevel.info, 'x', 'i'))
      ..add(_rec(LogLevel.info, 'x', 'i2')); // evicts the error
    expect(ring.countAtLeast(LogLevel.error), 0);
  });

  test('clear empties records, sources, and counts', () {
    final ring = LogRing(capacity: 10);
    ring
      ..add(_rec(LogLevel.warn, 'pql', 'w'))
      ..clear();
    expect(ring.isEmpty, isTrue);
    expect(ring.sources, isEmpty);
    expect(ring.countAtLeast(LogLevel.trace), 0);
  });

  test('changes fires on add and on clear', () async {
    final ring = LogRing(capacity: 10);
    final events = <void>[];
    final sub = ring.changes.listen(events.add);
    ring.add(_rec(LogLevel.info, 'x', 'a'));
    ring.clear();
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 2);
    await sub.cancel();
    ring.dispose();
  });

  test('clear on an empty ring does not fire changes', () async {
    final ring = LogRing(capacity: 10);
    final events = <void>[];
    final sub = ring.changes.listen(events.add);
    ring.clear();
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await sub.cancel();
    ring.dispose();
  });
}
