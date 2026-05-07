/// Pure-Dart tests for `lib/src/terminal/src/utils/`.
library;

import 'package:clide/src/terminal/src/utils/ascii.dart';
import 'package:clide/src/terminal/src/utils/byte_consumer.dart';
import 'package:clide/src/terminal/src/utils/circular_buffer.dart';
import 'package:clide/src/terminal/src/utils/hash_values.dart';
import 'package:clide/src/terminal/src/utils/unicode_v11.dart';
import 'package:test/test.dart';

class _Item with IndexedItem {
  _Item(this.value);
  final int value;
  @override
  String toString() => 'Item($value)';
}

void main() {
  group('Ascii.isNonPrintable', () {
    test('returns true for control chars (< 32) and DEL (127)', () {
      expect(Ascii.isNonPrintable(0), isTrue);
      expect(Ascii.isNonPrintable(31), isTrue);
      expect(Ascii.isNonPrintable(127), isTrue);
    });

    test('returns false for printable range [32, 126]', () {
      for (var i = 32; i < 127; i++) {
        expect(Ascii.isNonPrintable(i), isFalse, reason: 'codepoint $i');
      }
    });
  });

  group('hashValues', () {
    test('combines two args deterministically', () {
      expect(hashValues(1, 2), hashValues(1, 2));
      expect(hashValues(1, 2), isNot(hashValues(2, 1)));
    });

    test('extra args change the hash (covers each optional slot)', () {
      // Walk through 3..20 inclusive — the cascade of nested ifs in
      // hashValues is one branch per arg.
      final base = hashValues(1, 2);
      // Wrap up to 20 args; assert each adds entropy.
      var prev = base;
      final args = <Object?>[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
      for (var i = 0; i < args.length; i++) {
        final next = Function.apply(hashValues, [1, 2, ...args.sublist(0, i + 1)]) as int;
        expect(next, isNot(prev), reason: 'arg slot ${i + 3}');
        prev = next;
      }
    });

    test('hashList sums an iterable to a single hash', () {
      expect(hashList([1, 2, 3]), hashList([1, 2, 3]));
      expect(hashList([1, 2, 3]), isNot(hashList([3, 2, 1])));
      // Empty iterable short-circuits — Jenkins.finish(0) == 0; document
      // the contract rather than fight it.
      expect(hashList(<Object>[]), 0);
    });
  });

  group('ByteConsumer', () {
    test('add + consume — basic single-block sequence', () {
      final c = ByteConsumer();
      c.add('abc');
      expect(c.length, 3);
      expect(c.isEmpty, isFalse);
      expect(c.isNotEmpty, isTrue);
      expect(c.consume(), 'a'.codeUnitAt(0));
      expect(c.consume(), 'b'.codeUnitAt(0));
      expect(c.consume(), 'c'.codeUnitAt(0));
      expect(c.length, 0);
      expect(c.totalConsumed, 3);
      expect(c.isEmpty, isTrue);
    });

    test('add empty string is a no-op', () {
      final c = ByteConsumer();
      c.add('');
      expect(c.length, 0);
    });

    test('consume across block boundaries (recursive consume path)', () {
      final c = ByteConsumer();
      c.add('ab');
      c.add('cd');
      expect(c.consume(), 'a'.codeUnitAt(0));
      expect(c.consume(), 'b'.codeUnitAt(0));
      // Crossing boundary: consume() recurses after _queue.removeFirst().
      expect(c.consume(), 'c'.codeUnitAt(0));
      expect(c.consume(), 'd'.codeUnitAt(0));
      expect(c.length, 0);
    });

    test('peek returns the current head without consuming', () {
      final c = ByteConsumer();
      c.add('ab');
      expect(c.peek(), 'a'.codeUnitAt(0));
      expect(c.length, 2); // unchanged
    });

    test('peek across a block boundary uses consume+rollback', () {
      final c = ByteConsumer();
      c.add('ab');
      c.add('cd');
      c.consume();
      c.consume();
      // _currentOffset == 2, equal to first block length → peek takes the
      // consume + rollback path.
      expect(c.peek(), 'c'.codeUnitAt(0));
      expect(c.length, 2);
    });

    test('rollback by 1 within current block', () {
      final c = ByteConsumer();
      c.add('abc');
      c.consume();
      c.consume();
      c.rollback();
      expect(c.length, 2);
      expect(c.consume(), 'b'.codeUnitAt(0));
    });

    test('rollback across consumed blocks restores them', () {
      final c = ByteConsumer();
      c.add('ab');
      c.add('cd');
      c.consume();
      c.consume();
      c.consume(); // crosses boundary, moves first block to consumed
      c.rollback(2); // span back across the boundary
      expect(c.length, 3);
      expect(c.consume(), 'b'.codeUnitAt(0));
    });

    test('rollbackTo restores the consumer to a previous length', () {
      final c = ByteConsumer();
      c.add('abcd');
      c.consume();
      c.consume();
      c.rollbackTo(4); // back to the start
      expect(c.length, 4);
    });

    test('unrefConsumedBlocks empties the consumed history', () {
      final c = ByteConsumer();
      c.add('ab');
      c.add('cd');
      c.consume();
      c.consume();
      c.consume(); // 'c' from second block; first block now in _consumed
      c.unrefConsumedBlocks();
      // Subsequent rollback within current block still works.
      c.rollback();
      expect(c.length, 2);
    });

    test('reset wipes everything', () {
      final c = ByteConsumer();
      c.add('abc');
      c.consume();
      c.reset();
      expect(c.length, 0);
      expect(c.totalConsumed, 0);
      c.add('x');
      expect(c.consume(), 'x'.codeUnitAt(0));
    });
  });

  group('IndexAwareCircularBuffer', () {
    test('push grows the list while length < maxLength', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.push(_Item(1));
      r.push(_Item(2));
      expect(r.length, 2);
      expect(r[0].value, 1);
      expect(r[1].value, 2);
      expect(r.isFull, isFalse);
    });

    test('push past capacity trims the first element (FIFO ring)', () {
      final r = IndexAwareCircularBuffer<_Item>(2);
      r.push(_Item(1));
      r.push(_Item(2));
      r.push(_Item(3)); // trims item 1
      expect(r.length, 2);
      expect(r[0].value, 2);
      expect(r[1].value, 3);
      expect(r.isFull, isTrue);
    });

    test('push wraps _startIndex back to 0 after a full revolution', () {
      final r = IndexAwareCircularBuffer<_Item>(2);
      r.push(_Item(1));
      r.push(_Item(2));
      r.push(_Item(3)); // _startIndex 0 → 1
      r.push(_Item(4)); // _startIndex 1 → 2 → wraps to 0
      // Visible state: ring contains the most recent two items.
      expect(r[0].value, 3);
      expect(r[1].value, 4);
    });

    test('pushAll forwards each item through push', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2), _Item(3)]);
      expect(r.toList().map((i) => i.value), [1, 2, 3]);
    });

    test('pop returns and removes the last item', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      expect(r.pop().value, 2);
      expect(r.length, 1);
    });

    test('[]= replaces an element in place; [] reads it', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      r[0] = _Item(99);
      expect(r[0].value, 99);
    });

    test('clear removes every element', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      r.clear();
      expect(r.length, 0);
    });

    test('forEach iterates in order', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2), _Item(3)]);
      final out = <int>[];
      r.forEach((it) => out.add(it.value));
      expect(out, [1, 2, 3]);
    });

    test('remove deletes a contiguous range and shifts trailing items left', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(2), _Item(3), _Item(4), _Item(5)]);
      r.remove(1, 2); // drops items 2 + 3
      expect(r.toList().map((i) => i.value), [1, 4, 5]);
    });

    test('remove with count past end clamps to remaining length', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(2), _Item(3)]);
      r.remove(1, 99);
      expect(r.toList().map((i) => i.value), [1]);
    });

    test('remove with count=0 is a no-op', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(2)]);
      r.remove(0, 0);
      expect(r.length, 2);
    });

    test('insert at length delegates to push', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      r.insert(2, _Item(3));
      expect(r.toList().map((i) => i.value), [1, 2, 3]);
    });

    test('insert in the middle shifts trailing items right', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      r.insert(1, _Item(99));
      expect(r.toList().map((i) => i.value), [1, 99, 2]);
    });

    test('insert at index 0 of a full ring drops the new value', () {
      // Documented contract: when ring is full, inserting at 0 immediately
      // trims that same value, so the visible state is unchanged.
      final r = IndexAwareCircularBuffer<_Item>(2);
      r.pushAll([_Item(1), _Item(2)]);
      r.insert(0, _Item(99));
      expect(r.toList().map((i) => i.value), [1, 2]);
    });

    test('insert in the middle of a full ring trims the head', () {
      final r = IndexAwareCircularBuffer<_Item>(3);
      r.pushAll([_Item(1), _Item(2), _Item(3)]);
      r.insert(1, _Item(99)); // ring full → head trimmed
      expect(r.length, 3);
    });

    test('insertAll preserves order', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(4)]);
      r.insertAll(1, [_Item(2), _Item(3)]);
      expect(r.toList().map((i) => i.value), [1, 2, 3, 4]);
    });

    test('insertAll truncates when target is full from the head', () {
      final r = IndexAwareCircularBuffer<_Item>(2);
      r.pushAll([_Item(1), _Item(2)]);
      r.insertAll(0, [_Item(91), _Item(92), _Item(93)]);
      expect(r.length, 2);
    });

    test('trimStart drops the leading [count] items in O(1)', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(2), _Item(3), _Item(4)]);
      r.trimStart(2);
      expect(r.toList().map((i) => i.value), [3, 4]);
    });

    test('trimStart clamps to the current length', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1)]);
      r.trimStart(10);
      expect(r.length, 0);
    });

    test('replaceWith swaps the contents with a new list', () {
      final r = IndexAwareCircularBuffer<_Item>(8);
      r.pushAll([_Item(1), _Item(2)]);
      r.replaceWith([_Item(10), _Item(20), _Item(30)]);
      expect(r.toList().map((i) => i.value), [10, 20, 30]);
    });

    test('replaceWith truncates inputs longer than maxLength', () {
      final r = IndexAwareCircularBuffer<_Item>(2);
      r.replaceWith([_Item(1), _Item(2), _Item(3), _Item(4)]);
      expect(r.toList().map((i) => i.value), [3, 4]); // last two kept
    });

    test('swap replaces the element and returns the old value', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      final old = r.swap(0, _Item(99));
      expect(old.value, 1);
      expect(r[0].value, 99);
    });

    test('maxLength setter rejects non-positive values', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      expect(() => r.maxLength = 0, throwsArgumentError);
      expect(() => r.maxLength = -1, throwsArgumentError);
    });

    test('maxLength setter same value is a no-op', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1)]);
      r.maxLength = 4;
      expect(r.length, 1);
    });

    test('maxLength setter rebuilds the array, preserving order', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2), _Item(3)]);
      r.maxLength = 8;
      expect(r.maxLength, 8);
      expect(r.toList().map((i) => i.value), [1, 2, 3]);
    });

    test('debugDump returns a multi-line string with each item', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      r.pushAll([_Item(1), _Item(2)]);
      final s = r.debugDump();
      expect(s, contains('CircularList:'));
      expect(s, contains('Item(1)'));
      expect(s, contains('Item(2)'));
    });

    test('IndexedItem mixin: index reflects ring position; attached toggles', () {
      final r = IndexAwareCircularBuffer<_Item>(4);
      final a = _Item(1);
      expect(a.attached, isFalse);
      r.push(a);
      expect(a.attached, isTrue);
      expect(a.index, 0);
      r.push(_Item(2));
      // After a.push, index stays absolute-relative; the buffer's index
      // exposes regular 0-based.
      r.pop(); // removes the newer item, leaves a in place at index 0
      expect(a.attached, isTrue);
      expect(a.index, 0);
      r.pop(); // removes a
      expect(a.attached, isFalse);
    });
  });

  group('UnicodeV11.wcwidth', () {
    final w = unicodeV11.wcwidth;

    test('control chars (<32) are zero-width', () {
      for (var c = 0; c < 32; c++) {
        expect(w(c), 0, reason: 'codepoint $c');
      }
    });

    test('printable ASCII is width 1', () {
      for (var c = 32; c < 127; c++) {
        expect(w(c), 1, reason: 'codepoint $c');
      }
    });

    test('DEL + C1 controls are width 0 (table)', () {
      expect(w(0x7f), 0); // DEL
      for (var c = 0x80; c < 0xa0; c++) {
        expect(w(c), 0, reason: 'C1 control $c');
      }
    });

    test('combining marks (BMP_COMBINING) are width 0', () {
      expect(w(0x0301), 0); // combining acute accent
      expect(w(0x05BD), 0); // hebrew point meteg
    });

    test('CJK ideographs (BMP_WIDE) are width 2', () {
      expect(w(0x4E2D), 2); // 中
      expect(w(0x4F60), 2); // 你
    });

    test('high-plane combining marks return 0', () {
      // Pull a known HIGH_COMBINING entry — variation-selector range.
      expect(w(0xE0100), 0); // VARIATION SELECTOR-17
    });

    test('high-plane wide chars return 2', () {
      // Emoji.
      expect(w(0x1F600), 2); // GRINNING FACE
    });

    test('unmapped high codepoint defaults to width 1', () {
      // 0x100000 is in PUA-B; not in HIGH_WIDE / HIGH_COMBINING.
      expect(w(0x100000), 1);
    });

    test('UnicodeV11.version is the expected unicode version', () {
      expect(UnicodeV11().version, '11');
    });
  });
}
