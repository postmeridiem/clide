import 'package:clide/widgets/src/multitab_controller.dart';
import 'package:flutter_test/flutter_test.dart';

MultitabEntry<String> entry(String id, {bool closeable = true, bool reorderable = true}) {
  return MultitabEntry<String>(
    id: id,
    title: id,
    payload: id,
    closeable: closeable,
    reorderable: reorderable,
  );
}

void main() {
  group('MultitabController', () {
    test('starts empty when no initial entries', () {
      final c = MultitabController<String>();
      expect(c.entries, isEmpty);
      expect(c.active, isNull);
    });

    test('seeds from initial and activates the first', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      expect(c.entries.map((e) => e.id), ['a', 'b']);
      expect(c.activeId, 'a');
    });

    test('add appends and activates by default', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      c.add(entry('b'));
      expect(c.entries.map((e) => e.id), ['a', 'b']);
      expect(c.activeId, 'b');
    });

    test('add with activate:false keeps prior selection', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      c.add(entry('b'), activate: false);
      expect(c.activeId, 'a');
    });

    test('insert places at index and clamps out-of-range', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('c')]);
      c.insert(1, entry('b'));
      expect(c.entries.map((e) => e.id), ['a', 'b', 'c']);
      c.insert(99, entry('d'));
      expect(c.entries.last.id, 'd');
    });

    test('duplicate ids are rejected', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      expect(() => c.add(entry('a')), throwsStateError);
    });

    test('remove activates the right neighbour, then left', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b'), entry('c')]);
      c.activate('b');
      c.remove('b');
      expect(c.entries.map((e) => e.id), ['a', 'c']);
      expect(c.activeId, 'c');

      c.remove('c');
      expect(c.activeId, 'a');
    });

    test('remove leaves activeId null when emptied', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      c.remove('a');
      expect(c.entries, isEmpty);
      expect(c.activeId, isNull);
    });

    test('remove no-ops on non-closeable entries', () {
      final c = MultitabController<String>(initial: [entry('p', closeable: false), entry('s')]);
      c.remove('p');
      expect(c.entries.map((e) => e.id), ['p', 's']);
    });

    test('activate switches selection', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      c.activate('b');
      expect(c.activeId, 'b');
    });

    test('activate ignores unknown ids', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      c.activate('zzz');
      expect(c.activeId, 'a');
    });

    test('reorder moves a tab to a new index', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b'), entry('c')]);
      c.reorder('a', 2);
      expect(c.entries.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('reorder no-ops on non-reorderable entries', () {
      final c = MultitabController<String>(initial: [
        entry('p', reorderable: false),
        entry('a'),
      ]);
      c.reorder('p', 1);
      expect(c.entries.map((e) => e.id), ['p', 'a']);
    });

    test('reorder cannot move a tab past a pinned barrier', () {
      final c = MultitabController<String>(initial: [
        entry('p', reorderable: false),
        entry('a'),
        entry('b'),
      ]);
      // 'a' tries to land at index 0 — blocked by pinned 'p'.
      c.reorder('a', 0);
      expect(c.entries.map((e) => e.id), ['p', 'a', 'b']);
    });

    test('reorder respects barriers on the right', () {
      final c = MultitabController<String>(initial: [
        entry('a'),
        entry('b'),
        entry('p', reorderable: false),
      ]);
      // 'a' tries to land past pinned 'p' — clamped to before it.
      c.reorder('a', 2);
      expect(c.entries.map((e) => e.id), ['b', 'a', 'p']);
    });

    test('activateNext / activatePrev wrap', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b'), entry('c')]);
      c.activateNext();
      expect(c.activeId, 'b');
      c.activateNext();
      expect(c.activeId, 'c');
      c.activateNext();
      expect(c.activeId, 'a');
      c.activatePrev();
      expect(c.activeId, 'c');
    });

    test('replace swaps entry without disturbing position or active', () {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      c.activate('b');
      c.replace('a', MultitabEntry<String>(id: 'a', title: 'A!', payload: 'A!'));
      expect(c.entries.first.title, 'A!');
      expect(c.activeId, 'b');
    });

    test('replace rejects id changes', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      expect(
        () => c.replace('a', MultitabEntry<String>(id: 'b', title: 'b', payload: 'b')),
        throwsStateError,
      );
    });

    test('notifies listeners on every mutation', () {
      final c = MultitabController<String>(initial: [entry('a')]);
      var calls = 0;
      c.addListener(() => calls++);
      c.add(entry('b'));
      c.activate('a');
      c.reorder('b', 0);
      c.remove('b');
      expect(calls, 4);
    });
  });
}
