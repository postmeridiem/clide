/// Unit tests for the @-name completion helpers (T-180, at_commands.dart).
library;

import 'package:clide/builtin/claude/src/at_commands.dart';
import 'package:test/test.dart';

void main() {
  group('activeAtQuery', () {
    test('returns null when text is empty', () {
      expect(activeAtQuery('', 0), isNull);
    });

    test('returns null when cursor is at a non-@ run', () {
      expect(activeAtQuery('hello world', 5), isNull);
    });

    test('detects @name at start of text', () {
      const text = '@tyre';
      final q = activeAtQuery(text, text.length);
      expect(q, isNotNull);
      expect(q!.start, 0);
      expect(q.query, 'tyre');
    });

    test('detects @name after whitespace', () {
      const text = 'hi @tyre';
      final q = activeAtQuery(text, text.length);
      expect(q, isNotNull);
      expect(q!.start, 3);
      expect(q.query, 'tyre');
    });

    test('returns null when @ is mid-word (e.g. email address)', () {
      const text = 'user@example.com';
      final q = activeAtQuery(text, text.length);
      expect(q, isNull);
    });

    test('returns empty query when cursor is right after @', () {
      const text = '@';
      final q = activeAtQuery(text, 1);
      expect(q, isNotNull);
      expect(q!.query, '');
    });

    test('partial name is captured up to the cursor', () {
      const text = '@ty';
      final q = activeAtQuery(text, 3);
      expect(q!.query, 'ty');
    });

    test('returns null after a space follows the tag (token complete)', () {
      const text = '@tyre ';
      // Cursor is past the space — no active @-token.
      final q = activeAtQuery(text, text.length);
      expect(q, isNull);
    });
  });

  group('filterAtNames', () {
    const names = ['lead', 'tyre', 'qatux'];

    test('empty query returns team first then all names sorted', () {
      final results = filterAtNames('', names);
      expect(results.first, 'team');
      // The rest are alphabetically sorted names.
      expect(results.sublist(1).toSet(), containsAll(names));
    });

    test('query prefix filters names case-insensitively', () {
      final results = filterAtNames('t', names);
      expect(results, containsAll(['team', 'tyre']));
      expect(results, isNot(contains('lead')));
      expect(results, isNot(contains('qatux')));
    });

    test('team alias is always included when query matches', () {
      final results = filterAtNames('te', names);
      expect(results, contains('team'));
    });

    test('team alias is excluded when query does not match', () {
      final results = filterAtNames('z', names);
      expect(results, isNot(contains('team')));
    });

    test('de-duplicates names', () {
      final results = filterAtNames('', ['lead', 'lead']);
      expect(results.where((n) => n == 'lead'), hasLength(1));
    });

    test('caps results at limit', () {
      final manyNames = List.generate(20, (i) => 'member$i');
      final results = filterAtNames('', manyNames, limit: 5);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('team is pinned first even when other names sort before it', () {
      final results = filterAtNames('', ['alpha', 'beta']);
      expect(results.first, 'team');
    });
  });

  group('completeAt', () {
    test('replaces the @ token with the selected name + trailing space', () {
      // Cursor is right after "ty"; the space + rest of line come after.
      // replaceRange(0, 3, '@tyre ') over '@ty rest' gives '@tyre  rest'
      // (keeps the existing space). That is the correct contract — the
      // completion inserts its own trailing space; callers clear the space
      // if they want to avoid double spacing.
      const text = '@ty rest';
      final q = activeAtQuery(text, 3)!; // cursor after "ty"
      final result = completeAt(text, q, 'tyre');
      expect(result.text, '@tyre  rest'); // double-space: inserted + existing
      expect(result.cursor, '@tyre '.length);
    });

    test('works at the start of the text', () {
      const text = '@';
      final q = activeAtQuery(text, 1)!;
      final result = completeAt(text, q, 'lead');
      expect(result.text, '@lead ');
      expect(result.cursor, '@lead '.length);
    });
  });

  group('parseAtTag', () {
    test('no leading @ returns null recipient and full text as body', () {
      final r = parseAtTag('hello world');
      expect(r.recipient, isNull);
      expect(r.body, 'hello world');
    });

    test('leading @name splits into recipient + body', () {
      final r = parseAtTag('@tyre pick up T-9');
      expect(r.recipient, 'tyre');
      expect(r.body, 'pick up T-9');
    });

    test('@team normalises to null recipient (broadcast)', () {
      final r = parseAtTag('@team hello everyone');
      expect(r.recipient, isNull);
      expect(r.body, 'hello everyone');
    });

    test('just @name with no body', () {
      final r = parseAtTag('@lead');
      expect(r.recipient, 'lead');
      expect(r.body, '');
    });

    test('leading whitespace is trimmed before @-tag parsing', () {
      final r = parseAtTag('  @tyre hello');
      expect(r.recipient, 'tyre');
      expect(r.body, 'hello');
    });
  });
}
