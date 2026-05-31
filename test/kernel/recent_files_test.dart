/// Unit tests for [RecentFilesService] — the session-scoped recent
/// files list backing quick-open's empty-query state (T-51).
library;

import 'package:clide/kernel/src/recent_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push records most-recent-first', () {
    final r = RecentFilesService();
    r.push('a.dart');
    r.push('b.dart');
    expect(r.paths, ['b.dart', 'a.dart']);
  });

  test('push de-duplicates and moves an existing entry to the front', () {
    final r = RecentFilesService();
    r.push('a.dart');
    r.push('b.dart');
    r.push('a.dart');
    expect(r.paths, ['a.dart', 'b.dart']);
  });

  test('trims to the cap, dropping the oldest', () {
    final r = RecentFilesService(cap: 2);
    r.push('a');
    r.push('b');
    r.push('c');
    expect(r.paths, ['c', 'b']);
  });

  test('empty path is ignored', () {
    final r = RecentFilesService();
    r.push('');
    expect(r.paths, isEmpty);
  });

  test('clear empties the list and notifies once', () {
    final r = RecentFilesService();
    var notifications = 0;
    r.addListener(() => notifications++);
    r.push('a');
    r.clear();
    expect(r.paths, isEmpty);
    expect(notifications, 2);
    // A second clear on an empty list is a no-op (no extra notify).
    r.clear();
    expect(notifications, 2);
  });

  test('paths is an unmodifiable snapshot', () {
    final r = RecentFilesService();
    r.push('a');
    expect(() => r.paths.add('b'), throwsUnsupportedError);
  });
}
