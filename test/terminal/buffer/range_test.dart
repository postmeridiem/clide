/// Pure-Dart tests for the BufferRange family (CellOffset, BufferSegment,
/// BufferRangeLine, BufferRangeBlock). No Flutter dependency.
library;

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/buffer/range.dart';
import 'package:clide/src/terminal/src/core/buffer/range_block.dart';
import 'package:clide/src/terminal/src/core/buffer/range_line.dart';
import 'package:clide/src/terminal/src/core/buffer/segment.dart';
import 'package:test/test.dart';

void main() {
  group('CellOffset', () {
    test('equality + hashCode for same coordinates', () {
      const a = CellOffset(3, 5);
      const b = CellOffset(3, 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.isEqual(b), isTrue);
      expect(identical(a, a), isTrue); // hits the identity branch in ==
      const Object notACellOffset = 'CellOffset(3, 5)';
      expect(a == notACellOffset, isFalse); // hits the type-mismatch branch
    });

    test('inequality for different coordinates', () {
      expect(const CellOffset(3, 5), isNot(const CellOffset(4, 5)));
      expect(const CellOffset(3, 5).isEqual(const CellOffset(3, 6)), isFalse);
    });

    test('isBefore / isAfter — different rows', () {
      const top = CellOffset(9, 1);
      const bottom = CellOffset(0, 2);
      expect(top.isBefore(bottom), isTrue);
      expect(bottom.isAfter(top), isTrue);
      expect(top.isAfter(bottom), isFalse);
      expect(bottom.isBefore(top), isFalse);
    });

    test('isBefore / isAfter — same row, different columns', () {
      const left = CellOffset(2, 4);
      const right = CellOffset(7, 4);
      expect(left.isBefore(right), isTrue);
      expect(right.isAfter(left), isTrue);
      expect(left.isAfter(right), isFalse);
      expect(right.isBefore(left), isFalse);
    });

    test('isBefore / isAfter — equal positions are neither', () {
      const a = CellOffset(2, 2);
      const b = CellOffset(2, 2);
      expect(a.isBefore(b), isFalse);
      expect(a.isAfter(b), isFalse);
    });

    test('isBeforeOrSame / isAfterOrSame include equal positions', () {
      const a = CellOffset(3, 3);
      const b = CellOffset(3, 3);
      const earlier = CellOffset(2, 3);
      const later = CellOffset(4, 3);
      expect(a.isBeforeOrSame(b), isTrue);
      expect(a.isAfterOrSame(b), isTrue);
      expect(earlier.isBeforeOrSame(a), isTrue);
      expect(later.isAfterOrSame(a), isTrue);
      expect(later.isBeforeOrSame(a), isFalse);
      expect(earlier.isAfterOrSame(a), isFalse);
    });

    test('isAtSameRow / isAtSameColumn', () {
      expect(const CellOffset(2, 5).isAtSameRow(const CellOffset(9, 5)), isTrue);
      expect(const CellOffset(2, 5).isAtSameRow(const CellOffset(2, 6)), isFalse);
      expect(const CellOffset(4, 1).isAtSameColumn(const CellOffset(4, 9)), isTrue);
      expect(const CellOffset(4, 1).isAtSameColumn(const CellOffset(5, 9)), isFalse);
    });

    test('isWithin delegates to BufferRange.contains', () {
      final range = BufferRangeLine(const CellOffset(0, 0), const CellOffset(5, 0));
      expect(const CellOffset(3, 0).isWithin(range), isTrue);
      expect(const CellOffset(3, 1).isWithin(range), isFalse);
    });

    test('toString shape', () {
      expect(const CellOffset(2, 3).toString(), 'CellOffset(2, 3)');
    });
  });

  group('BufferSegment', () {
    test('isWithin — wrong line is never within', () {
      const seg = BufferSegment(_dummyRange, 4, 2, 8);
      expect(seg.isWithin(const CellOffset(5, 3)), isFalse);
      expect(seg.isWithin(const CellOffset(5, 5)), isFalse);
    });

    test('isWithin — bounded segment respects start and end', () {
      const seg = BufferSegment(_dummyRange, 4, 2, 8);
      expect(seg.isWithin(const CellOffset(2, 4)), isTrue); // at start
      expect(seg.isWithin(const CellOffset(5, 4)), isTrue); // middle
      expect(seg.isWithin(const CellOffset(8, 4)), isTrue); // at end
      expect(seg.isWithin(const CellOffset(1, 4)), isFalse); // before start
      expect(seg.isWithin(const CellOffset(9, 4)), isFalse); // after end
    });

    test('isWithin — null start means line beginning', () {
      const seg = BufferSegment(_dummyRange, 0, null, 5);
      expect(seg.isWithin(const CellOffset(0, 0)), isTrue);
      expect(seg.isWithin(const CellOffset(5, 0)), isTrue);
      expect(seg.isWithin(const CellOffset(6, 0)), isFalse);
    });

    test('isWithin — null end means line end', () {
      const seg = BufferSegment(_dummyRange, 0, 3, null);
      expect(seg.isWithin(const CellOffset(3, 0)), isTrue);
      expect(seg.isWithin(const CellOffset(999, 0)), isTrue);
      expect(seg.isWithin(const CellOffset(2, 0)), isFalse);
    });

    test('equality + hashCode', () {
      const a = BufferSegment(_dummyRange, 1, 2, 3);
      const b = BufferSegment(_dummyRange, 1, 2, 3);
      const c = BufferSegment(_dummyRange, 1, 2, 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      const Object notASegment = 'segment';
      expect(a == notASegment, isFalse);
      expect(identical(a, a), isTrue);
    });

    test('toString shape — bounded and unbounded', () {
      expect(const BufferSegment(_dummyRange, 4, 2, 8).toString(), 'Segment(4, 2 -> 8)');
      expect(const BufferSegment(_dummyRange, 0, null, null).toString(), 'Segment(0, start -> end)');
    });
  });

  group('BufferRangeLine', () {
    test('collapsed range has equal begin and end', () {
      final r = BufferRangeLine.collapsed(const CellOffset(2, 3));
      expect(r.isCollapsed, isTrue);
      expect(r.begin, const CellOffset(2, 3));
      expect(r.end, const CellOffset(2, 3));
    });

    test('isNormalized true when begin <= end', () {
      final r = BufferRangeLine(const CellOffset(0, 0), const CellOffset(3, 1));
      expect(r.isNormalized, isTrue);
    });

    test('normalized swaps begin/end when reversed', () {
      final r = BufferRangeLine(const CellOffset(3, 1), const CellOffset(0, 0));
      expect(r.isNormalized, isFalse);
      final n = r.normalized;
      expect(n.begin, const CellOffset(0, 0));
      expect(n.end, const CellOffset(3, 1));
      expect(n.normalized, n); // already normalized → identity
    });

    test('toSegments — single line returns one bounded segment', () {
      final r = BufferRangeLine(const CellOffset(2, 0), const CellOffset(5, 0));
      final segs = r.toSegments().toList();
      expect(segs, hasLength(1));
      expect(segs[0].line, 0);
      expect(segs[0].start, 2);
      expect(segs[0].end, 5);
    });

    test('toSegments — multiple lines: first bounded-left, last bounded-right, middle unbounded', () {
      final r = BufferRangeLine(const CellOffset(2, 0), const CellOffset(5, 2));
      final segs = r.toSegments().toList();
      expect(segs.map((s) => s.line), [0, 1, 2]);
      expect(segs[0].start, 2);
      expect(segs[0].end, isNull);
      expect(segs[1].start, isNull);
      expect(segs[1].end, isNull);
      expect(segs[2].start, isNull);
      expect(segs[2].end, 5);
    });

    test('contains positions inside the range, including endpoints', () {
      final r = BufferRangeLine(const CellOffset(2, 0), const CellOffset(5, 2));
      expect(r.contains(const CellOffset(2, 0)), isTrue);
      expect(r.contains(const CellOffset(0, 1)), isTrue); // mid line
      expect(r.contains(const CellOffset(5, 2)), isTrue);
      expect(r.contains(const CellOffset(1, 0)), isFalse);
      expect(r.contains(const CellOffset(6, 2)), isFalse);
    });

    test('contains works on a denormalized range too (normalizes internally)', () {
      final r = BufferRangeLine(const CellOffset(5, 2), const CellOffset(2, 0));
      expect(r.contains(const CellOffset(0, 1)), isTrue);
    });

    test('merge picks earliest begin and latest end', () {
      final a = BufferRangeLine(const CellOffset(2, 0), const CellOffset(5, 0));
      final b = BufferRangeLine(const CellOffset(0, 0), const CellOffset(9, 0));
      final m = a.merge(b);
      expect(m.begin, const CellOffset(0, 0));
      expect(m.end, const CellOffset(9, 0));
    });

    test('extend grows the range to cover an outside position', () {
      final r = BufferRangeLine(const CellOffset(2, 1), const CellOffset(5, 1));
      final earlier = r.extend(const CellOffset(0, 0));
      expect(earlier.begin, const CellOffset(0, 0));
      expect(earlier.end, const CellOffset(5, 1));
      final later = r.extend(const CellOffset(9, 3));
      expect(later.begin, const CellOffset(2, 1));
      expect(later.end, const CellOffset(9, 3));
    });

    test('equality + hashCode + toString', () {
      final a = BufferRangeLine(const CellOffset(0, 0), const CellOffset(1, 1));
      final b = BufferRangeLine(const CellOffset(0, 0), const CellOffset(1, 1));
      final c = BufferRangeLine(const CellOffset(0, 0), const CellOffset(1, 2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      const Object notALineRange = 'line range';
      expect(a == notALineRange, isFalse);
      expect(identical(a, a), isTrue);
      expect(a.toString(), startsWith('Line Range('));
    });
  });

  group('BufferRangeBlock', () {
    test('isNormalized requires top-left + bottom-right corners', () {
      final tlBr = BufferRangeBlock(const CellOffset(2, 1), const CellOffset(5, 4));
      expect(tlBr.isNormalized, isTrue);

      final trBl = BufferRangeBlock(const CellOffset(5, 1), const CellOffset(2, 4));
      expect(trBl.isNormalized, isFalse);
    });

    test('normalized produces top-left / bottom-right corners', () {
      final r = BufferRangeBlock(const CellOffset(5, 1), const CellOffset(2, 4));
      final n = r.normalized;
      expect(n.begin, const CellOffset(2, 1));
      expect(n.end, const CellOffset(5, 4));
      expect(n.normalized, n); // already normalized branch
    });

    test('toSegments — bounded on every line', () {
      final r = BufferRangeBlock(const CellOffset(2, 0), const CellOffset(5, 2));
      final segs = r.toSegments().toList();
      expect(segs.map((s) => s.line), [0, 1, 2]);
      for (final s in segs) {
        expect(s.start, 2);
        expect(s.end, 5);
      }
    });

    test('toSegments — denormalized input still yields normalized output', () {
      final r = BufferRangeBlock(const CellOffset(5, 2), const CellOffset(2, 0));
      final segs = r.toSegments().toList();
      // After internal normalization the segment range is x:[2..5] over y:[0..2].
      expect(segs.map((s) => s.line), [0, 1, 2]);
      for (final s in segs) {
        expect(s.start, 2);
        expect(s.end, 5);
      }
    });

    test('contains — inside, on edge, outside', () {
      final r = BufferRangeBlock(const CellOffset(2, 0), const CellOffset(5, 2));
      expect(r.contains(const CellOffset(2, 0)), isTrue); // tl
      expect(r.contains(const CellOffset(5, 2)), isTrue); // br
      expect(r.contains(const CellOffset(3, 1)), isTrue); // inside
      expect(r.contains(const CellOffset(1, 1)), isFalse); // left of block
      expect(r.contains(const CellOffset(6, 1)), isFalse); // right of block
      expect(r.contains(const CellOffset(3, 3)), isFalse); // below block
    });

    test('contains works on denormalized blocks', () {
      final r = BufferRangeBlock(const CellOffset(5, 2), const CellOffset(2, 0));
      expect(r.contains(const CellOffset(3, 1)), isTrue);
    });

    test('extend — position inside is identity', () {
      final r = BufferRangeBlock(const CellOffset(2, 0), const CellOffset(5, 2));
      final same = r.extend(const CellOffset(3, 1));
      expect(same, r);
    });

    test('extend — position outside grows the block', () {
      final r = BufferRangeBlock(const CellOffset(2, 1), const CellOffset(5, 3));
      final out = r.extend(const CellOffset(0, 0));
      expect(out.begin, const CellOffset(0, 0));
      expect(out.end, const CellOffset(5, 3));
    });

    test('merge — combines two blocks into the smallest enclosing block', () {
      final a = BufferRangeBlock(const CellOffset(0, 0), const CellOffset(2, 2));
      final b = BufferRangeBlock(const CellOffset(5, 5), const CellOffset(7, 7));
      final m = a.merge(b);
      expect(m.begin, const CellOffset(0, 0));
      expect(m.end, const CellOffset(7, 7));
    });

    test('equality + hashCode + toString', () {
      final a = BufferRangeBlock(const CellOffset(0, 0), const CellOffset(1, 1));
      final b = BufferRangeBlock(const CellOffset(0, 0), const CellOffset(1, 1));
      final c = BufferRangeBlock(const CellOffset(0, 0), const CellOffset(1, 2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      const Object notABlockRange = 'block range';
      expect(a == notABlockRange, isFalse);
      expect(identical(a, a), isTrue);
      expect(a.toString(), startsWith('Block Range('));
    });
  });

  group('BufferRange (abstract base) — collapsed + isCollapsed + isNormalized', () {
    test('collapsed range is normalized and collapsed', () {
      final r = BufferRangeLine.collapsed(const CellOffset(3, 3));
      expect(r.isCollapsed, isTrue);
      expect(r.isNormalized, isTrue);
    });

    test('block collapsed constructor', () {
      final r = BufferRangeBlock.collapsed(const CellOffset(2, 2));
      expect(r.isCollapsed, isTrue);
      expect(r.begin, r.end);
    });

    test('base ==/hashCode/toString via direct subclass that does not override them', () {
      const a = _StubRange(CellOffset(0, 0), CellOffset(1, 1));
      const b = _StubRange(CellOffset(0, 0), CellOffset(1, 1));
      const c = _StubRange(CellOffset(0, 0), CellOffset(2, 2));
      expect(a, b); // same begin + end via base ==
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      const Object notARange = 'not a range';
      expect(a == notARange, isFalse); // type-mismatch branch
      expect(identical(a, a), isTrue);
      expect(a.toString(), 'Range(CellOffset(0, 0), CellOffset(1, 1))');
    });
  });
}

const _dummyRange = _StubRange(CellOffset(0, 0), CellOffset(0, 0));

class _StubRange extends BufferRange {
  const _StubRange(super.begin, super.end);
  @override
  BufferRange get normalized => this;
  @override
  Iterable<BufferSegment> toSegments() => const [];
  @override
  bool contains(CellOffset position) => false;
  @override
  BufferRange merge(BufferRange range) => this;
  @override
  BufferRange extend(CellOffset position) => this;
}
