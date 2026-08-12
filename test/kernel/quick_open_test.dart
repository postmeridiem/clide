/// Unit tests for [QuickOpenController] — state, fuzzy ranking, recents
/// fallback, and selection wrapping (T-51).
library;

import 'package:clide/kernel/src/quick_open.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> recents;
  QuickOpenController make() => QuickOpenController(recentPaths: () => recents);

  setUp(() => recents = ['recent_a.dart', 'recent_b.dart']);

  test('open/close/toggle track isOpen and reset the filter', () {
    final c = make();
    expect(c.isOpen, isFalse);
    c.open();
    expect(c.isOpen, isTrue);
    c.setFilter('main');
    c.close();
    expect(c.isOpen, isFalse);
    expect(c.filter, isEmpty);
    c.toggle();
    expect(c.isOpen, isTrue);
  });

  test('empty query shows recents', () {
    final c = make()..open();
    c.setFiles(['lib/main.dart', 'lib/app.dart']);
    expect(c.filtered(), recents);
    expect(c.selectedPath, 'recent_a.dart');
  });

  test('non-empty query fuzzy-matches the file list, not recents', () {
    final c = make()..open();
    c.setFiles(['lib/main.dart', 'lib/app.dart', 'README.md']);
    c.setFilter('main');
    expect(c.filtered(), contains('lib/main.dart'));
    expect(c.filtered(), isNot(contains('README.md')));
  });

  test('subsequence match ranks contiguous/early hits above scattered', () {
    final c = make()..open();
    c.setFiles(['x/abc_extra.dart', 'abc.dart', 'a_b_c.dart']);
    c.setFilter('abc');
    // 'abc.dart' (contiguous, earliest) should rank first.
    expect(c.filtered().first, 'abc.dart');
  });

  test('non-matching query yields an empty result list', () {
    final c = make()..open();
    c.setFiles(['lib/main.dart']);
    c.setFilter('zzzzz');
    expect(c.filtered(), isEmpty);
    expect(c.selectedPath, isNull);
  });

  test('selectNext/Previous wrap around the result list', () {
    final c = make()..open();
    c.setFiles(['a.dart', 'b.dart', 'c.dart']);
    c.setFilter('dart'); // matches all three
    expect(c.selectedIndex, 0);
    c.selectPrevious(); // wraps to last
    expect(c.selectedIndex, c.filtered().length - 1);
    c.selectNext(); // wraps back to 0
    expect(c.selectedIndex, 0);
  });

  test('selection is a no-op with fewer than two results', () {
    final c = make()..open();
    c.setFiles(['only.dart']);
    c.setFilter('only');
    c.selectNext();
    expect(c.selectedIndex, 0);
  });

  test('setFiles records truncation', () {
    final c = make()..open();
    c.setFiles(['a.dart'], truncated: true);
    expect(c.truncated, isTrue);
  });

  test('result list is capped at resultCap', () {
    final c = make()..open();
    c.setFiles([for (var i = 0; i < QuickOpenController.resultCap + 50; i++) 'f$i.dart']);
    c.setFilter('dart');
    expect(c.filtered(), hasLength(QuickOpenController.resultCap));
  });

  test('setLoading toggles the flag and notifies', () {
    final c = make();
    var n = 0;
    c.addListener(() => n++);
    c.setLoading(true);
    expect(c.isLoading, isTrue);
    expect(n, 1);
    c.setLoading(true); // no change → no notify
    expect(n, 1);
  });

  group('picker mode (T-571)', () {
    test('pick opens the surface and resolves with the chosen path', () async {
      final c = make();
      final future = c.pick(prompt: 'Choose a note');

      expect(c.isOpen, isTrue);
      expect(c.isPicking, isTrue);
      expect(c.prompt, 'Choose a note');

      expect(c.resolvePick('notes/a.md'), isTrue);
      expect(await future, 'notes/a.md');
      expect(c.isOpen, isFalse);
      expect(c.isPicking, isFalse);
      expect(c.prompt, isNull);
    });

    test('dismissing resolves null rather than hanging the caller', () async {
      final c = make();
      final future = c.pick();
      c.close();
      expect(await future, isNull);
      expect(c.isPicking, isFalse);
    });

    test('accepting nothing resolves null', () async {
      final c = make();
      final future = c.pick();
      expect(c.resolvePick(null), isTrue);
      expect(await future, isNull);
    });

    test('pick honours a seed filter', () {
      final c = make();
      c.pick(seed: 'notes/');
      expect(c.filter, 'notes/');
      c.close();
    });

    test('resolvePick is false in ordinary quick-open, so the overlay opens', () {
      final c = make();
      c.open();
      expect(c.isPicking, isFalse);
      expect(c.resolvePick('a.dart'), isFalse, reason: 'nothing was waiting');
      expect(c.isOpen, isTrue, reason: 'a false result must not have closed it');
    });

    test('a second pick takes over and resolves the first with null', () async {
      final c = make();
      final first = c.pick(prompt: 'one');
      final second = c.pick(prompt: 'two');

      expect(await first, isNull, reason: 'the superseded caller must not hang');
      expect(c.prompt, 'two');
      c.resolvePick('chosen.md');
      expect(await second, 'chosen.md');
    });

    test('an ordinary open over a pending pick resolves it with null', () async {
      final c = make();
      final future = c.pick();
      c.close(); // open() is a no-op while already open, so close first
      c.open();
      expect(await future, isNull);
      expect(c.isPicking, isFalse);
      expect(c.prompt, isNull);
    });

    test('dispose resolves a pending pick', () async {
      final c = make();
      final future = c.pick();
      c.dispose();
      expect(await future, isNull);
    });

    test('an ordinary open carries no prompt', () {
      final c = make();
      c.open();
      expect(c.prompt, isNull);
      expect(c.isPicking, isFalse);
    });

    test('pick notifies listeners so the overlay shows', () {
      final c = make();
      var n = 0;
      c.addListener(() => n++);
      c.pick();
      expect(n, 1);
      c.resolvePick('x.dart');
      expect(n, 2);
    });
  });
}
