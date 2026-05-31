/// Round-trip tests for the search data types (T-52).
library;

import 'package:clide/src/search/match.dart';
import 'package:test/test.dart';

void main() {
  test('SearchMatch JSON round-trips', () {
    const m = SearchMatch(path: 'lib/a.dart', line: 12, matchStart: 4, matchEnd: 8, preview: 'final x = 1;');
    final back = SearchMatch.fromJson(m.toJson());
    expect(back.path, m.path);
    expect(back.line, m.line);
    expect(back.matchStart, m.matchStart);
    expect(back.matchEnd, m.matchEnd);
    expect(back.preview, m.preview);
  });

  test('SearchQuery JSON round-trips', () {
    const q = SearchQuery(pattern: 'foo', regex: true, ignoreCase: true, include: ['*.dart'], exclude: ['build/**']);
    final back = SearchQuery.fromJson(q.toJson());
    expect(back.pattern, 'foo');
    expect(back.regex, isTrue);
    expect(back.ignoreCase, isTrue);
    expect(back.include, ['*.dart']);
    expect(back.exclude, ['build/**']);
  });

  test('SearchQuery.fromJson tolerates missing/odd fields', () {
    final q = SearchQuery.fromJson(const {'pattern': 'x'});
    expect(q.regex, isFalse);
    expect(q.ignoreCase, isFalse);
    expect(q.include, isEmpty);
    expect(q.exclude, isEmpty);
    final q2 = SearchQuery.fromJson(const {});
    expect(q2.pattern, '');
    final q3 = SearchQuery.fromJson(const {'pattern': 'x', 'include': 'not-a-list'});
    expect(q3.include, isEmpty);
  });
}
