/// Pure-Dart tests for BufferLine + CellAnchor (lib/src/terminal/src/core/buffer/line.dart).
library;

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/buffer/line.dart';
import 'package:clide/src/terminal/src/core/cell.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
import 'package:clide/src/terminal/src/utils/circular_buffer.dart';
import 'package:test/test.dart';

const int _aChar = 0x61;
const int _bChar = 0x62;
const int _wideChar = 0x4E2D; // any CJK ideograph; wcwidth=2
final _styleEmpty = CursorStyle.empty;

CursorStyle _style({int fg = 0, int bg = 0, int attrs = 0}) => CursorStyle(foreground: fg, background: bg, attrs: attrs);

void main() {
  group('BufferLine — construction and basic accessors', () {
    test('new line has the requested length, isWrapped false by default', () {
      final l = BufferLine(10);
      expect(l.length, 10);
      expect(l.isWrapped, isFalse);
      expect(l.anchors, isEmpty);
      expect(l.attached, isFalse);
    });

    test('isWrapped can be set via the constructor', () {
      final l = BufferLine(5, isWrapped: true);
      expect(l.isWrapped, isTrue);
    });

    test('data getter exposes the backing Uint32List', () {
      final l = BufferLine(4);
      expect(l.data.length, isPositive);
      expect(l.data.length % 4, 0); // _cellSize == 4
    });
  });

  group('BufferLine — per-cell get/set round-trips', () {
    test('foreground/background/attributes/content are independent', () {
      final l = BufferLine(3);
      l.setForeground(0, 0xAA);
      l.setBackground(0, 0xBB);
      l.setAttributes(0, 0xCC);
      l.setContent(0, 0xDD);
      expect(l.getForeground(0), 0xAA);
      expect(l.getBackground(0), 0xBB);
      expect(l.getAttributes(0), 0xCC);
      expect(l.getContent(0), 0xDD);

      // Other cells are untouched.
      expect(l.getForeground(1), 0);
      expect(l.getContent(2), 0);
    });

    test('setCodePoint encodes width into the high bits of content', () {
      final l = BufferLine(3);
      l.setCodePoint(0, _aChar);
      expect(l.getCodePoint(0), _aChar);
      expect(l.getWidth(0), 1);

      l.setCodePoint(1, _wideChar);
      expect(l.getCodePoint(1), _wideChar);
      expect(l.getWidth(1), 2);
    });

    test('setCell writes style + char + width as a single packed cell', () {
      final l = BufferLine(2);
      l.setCell(0, _aChar, 1, _style(fg: 1, bg: 2, attrs: 4));
      expect(l.getForeground(0), 1);
      expect(l.getBackground(0), 2);
      expect(l.getAttributes(0), 4);
      expect(l.getCodePoint(0), _aChar);
      expect(l.getWidth(0), 1);
    });

    test('getCellData fills a CellData record from the backing buffer', () {
      final l = BufferLine(1);
      l.setCell(0, _aChar, 1, _style(fg: 9, bg: 8, attrs: 7));
      final data = CellData.empty();
      l.getCellData(0, data);
      expect(data.foreground, 9);
      expect(data.background, 8);
      expect(data.flags, 7);
      expect(data.content & CellContent.codepointMask, _aChar);
    });

    test('setCellData writes a CellData back into the backing buffer', () {
      final l = BufferLine(1);
      final src = CellData(foreground: 11, background: 22, flags: 33, content: 44);
      l.setCellData(0, src);
      expect(l.getForeground(0), 11);
      expect(l.getBackground(0), 22);
      expect(l.getAttributes(0), 33);
      expect(l.getContent(0), 44);
    });

    test('createCellData seeds an empty CellData and writes it through', () {
      final l = BufferLine(1);
      l.setCell(0, _aChar, 1, _style(fg: 5));
      final result = l.createCellData(0);
      // createCellData starts from CellData.empty() and writes that into the
      // backing buffer — it OVERWRITES whatever was at that index.
      expect(result.foreground, 0);
      expect(l.getForeground(0), 0);
      expect(l.getCodePoint(0), 0);
    });
  });

  group('BufferLine — eraseCell + resetCell', () {
    test('eraseCell stamps style fg/bg/attrs and zeroes content', () {
      final l = BufferLine(1);
      l.setCell(0, _aChar, 1, _style(fg: 1, bg: 2, attrs: 4));
      l.eraseCell(0, _style(fg: 7, bg: 8, attrs: 9));
      expect(l.getForeground(0), 7);
      expect(l.getBackground(0), 8);
      expect(l.getAttributes(0), 9);
      expect(l.getContent(0), 0);
    });

    test('resetCell zeroes every channel', () {
      final l = BufferLine(1);
      l.setCell(0, _aChar, 1, _style(fg: 1, bg: 2, attrs: 4));
      l.resetCell(0);
      expect(l.getForeground(0), 0);
      expect(l.getBackground(0), 0);
      expect(l.getAttributes(0), 0);
      expect(l.getContent(0), 0);
    });
  });

  group('BufferLine — eraseRange', () {
    test('basic range erases [start, end)', () {
      final l = BufferLine(5);
      for (var i = 0; i < 5; i++) {
        l.setCell(i, _aChar, 1, _styleEmpty);
      }
      l.eraseRange(1, 4, _styleEmpty);
      expect(l.getCodePoint(0), _aChar);
      expect(l.getCodePoint(1), 0);
      expect(l.getCodePoint(2), 0);
      expect(l.getCodePoint(3), 0);
      expect(l.getCodePoint(4), _aChar); // outside the [1,4) range
    });

    test('clamps end to length', () {
      final l = BufferLine(3);
      l.setCell(0, _aChar, 1, _styleEmpty);
      l.setCell(2, _aChar, 1, _styleEmpty);
      l.eraseRange(0, 99, _styleEmpty);
      expect(l.getCodePoint(0), 0);
      expect(l.getCodePoint(2), 0);
    });

    test('extends one cell left when start-1 is the second cell of a wide char', () {
      final l = BufferLine(4);
      // Place a wide char at positions 0..1, then a regular at 2.
      l.setCell(0, _wideChar, 2, _styleEmpty);
      l.setCell(1, 0, 0, _styleEmpty); // (logical second-half marker; width=0)
      // The implementation only checks getWidth(start-1) == 2, so make it true.
      l.setContent(0, _wideChar | (2 << CellContent.widthShift));
      l.setCell(2, _aChar, 1, _styleEmpty);

      l.eraseRange(2, 3, _styleEmpty);
      // Cell at index 1 is start-1; getWidth(1) is 0 here, so the wide-extension
      // branch isn't hit through index 1. But the branch for getWidth(start-1)==2
      // is exercised when start lands on a cell whose neighbor at start-1 is wide.
      expect(l.getCodePoint(2), 0); // erased

      // Now exercise the actual wide-neighbor branch: erase range [1, 2) when
      // index 0 is wide.
      l.setContent(0, _wideChar | (2 << CellContent.widthShift));
      l.setCell(1, _aChar, 1, _styleEmpty);
      l.eraseRange(1, 2, _styleEmpty);
      // index 0's content should now also be erased due to the extension.
      expect(l.getContent(0), 0);
    });

    test('eraseRange(0, 0, ...) does not panic when called at column 0', () {
      // Surfaced by Terminal.eraseDisplayAbove when the cursor sits at
      // column 0: eraseLineToCursor → eraseRange(0, _cursorX, ...) with
      // _cursorX == 0. Without the `end > 0` guard, the right-side
      // wide-char check reads _data[-1] via getWidth(-1).
      final l = BufferLine(4);
      l.eraseRange(0, 0, _styleEmpty);
    });

    test('extends one cell right when end-1 is the second cell of a wide char', () {
      final l = BufferLine(4);
      l.setCell(0, _aChar, 1, _styleEmpty);
      // Place a wide char straddling indexes 1..2 (width recorded at index 1).
      l.setContent(1, _wideChar | (2 << CellContent.widthShift));
      l.setCell(3, _aChar, 1, _styleEmpty);

      l.eraseRange(0, 2, _styleEmpty);
      // Both index 0 (in range) and index 1 (the wide-end-extension) should be
      // erased to 0.
      expect(l.getContent(0), 0);
      expect(l.getContent(1), 0);
      // Index 3 stays.
      expect(l.getCodePoint(3), _aChar);
    });
  });

  group('BufferLine — removeCells', () {
    test('shifts cells left and fills tail with the given style', () {
      final l = BufferLine(5);
      for (var i = 0; i < 5; i++) {
        l.setCell(i, _aChar + i, 1, _styleEmpty);
      }
      l.removeCells(1, 2);
      // After removeCells(1, 2), cells at index 3..4 move to 1..2.
      expect(l.getCodePoint(0), _aChar); // index 0 unchanged
      expect(l.getCodePoint(1), _aChar + 3);
      expect(l.getCodePoint(2), _aChar + 4);
      expect(l.getCodePoint(3), 0); // erased tail
      expect(l.getCodePoint(4), 0);
    });

    test('null style argument defaults to CursorStyle.empty', () {
      final l = BufferLine(3);
      for (var i = 0; i < 3; i++) {
        l.setCell(i, _aChar, 1, _style(fg: 99));
      }
      l.removeCells(0, 1); // default style = empty
      // Tail cell after shift should be erased with empty style.
      expect(l.getForeground(2), 0);
    });

    test('handles wide neighbor at start-1 (erases preceding wide cell)', () {
      final l = BufferLine(4);
      l.setContent(0, _wideChar | (2 << CellContent.widthShift));
      l.setCell(1, _aChar, 1, _styleEmpty);
      l.setCell(2, _bChar, 1, _styleEmpty);
      l.setCell(3, _aChar, 1, _styleEmpty);
      l.removeCells(1, 1);
      expect(l.getContent(0), 0); // wide neighbor erased
    });

    test('removes anchors inside the removed range, repositions later anchors', () {
      final l = BufferLine(5);
      final inside = l.createAnchor(2);
      final after = l.createAnchor(4);
      final before = l.createAnchor(0);

      l.removeCells(1, 2);

      expect(inside.attached, isFalse); // disposed
      expect(after.x, 4 - 2); // moved left by count
      expect(before.x, 0); // unchanged
    });
  });

  group('BufferLine — insertCells', () {
    test('shifts cells right, erases inserted range', () {
      final l = BufferLine(5);
      for (var i = 0; i < 5; i++) {
        l.setCell(i, _aChar + i, 1, _styleEmpty);
      }
      l.insertCells(1, 2);
      expect(l.getCodePoint(0), _aChar);
      expect(l.getCodePoint(1), 0); // erased (newly inserted)
      expect(l.getCodePoint(2), 0); // erased (newly inserted)
      expect(l.getCodePoint(3), _aChar + 1); // shifted from index 1
      expect(l.getCodePoint(4), _aChar + 2); // shifted from index 2
    });

    test('null style argument defaults to CursorStyle.empty', () {
      final l = BufferLine(3);
      for (var i = 0; i < 3; i++) {
        l.setCell(i, _aChar, 1, _style(fg: 99));
      }
      l.insertCells(0, 1);
      // newly inserted cell at 0 should have empty style.
      expect(l.getForeground(0), 0);
    });

    test('handles wide neighbor at start-1', () {
      final l = BufferLine(4);
      l.setContent(0, _wideChar | (2 << CellContent.widthShift));
      l.setCell(1, _aChar, 1, _styleEmpty);
      l.insertCells(1, 1);
      expect(l.getContent(0), 0); // wide neighbor erased
    });

    test('handles wide cell pushed to the line tail by the shift', () {
      // Wide cell at index 2 (length-1-count). After insertCells(0, 1)
      // shifts data[0..2] to data[1..3], the wide marker lands at index
      // 3 — which is now the last cell. The wide-tail-erase branch
      // (getWidth(_length - 1) == 2) fires and clears it.
      final l = BufferLine(4);
      l.setContent(2, _wideChar | (2 << CellContent.widthShift));
      l.insertCells(0, 1);
      expect(l.getContent(3), 0);
    });

    test('repositions anchors at-or-past the end of the inserted range', () {
      final l = BufferLine(8);
      // insertCells(1, 2): only anchors with x >= start + count = 3 move.
      final inRange = l.createAnchor(2); // inside [start, start+count)
      final atBoundary = l.createAnchor(3); // exactly at start+count
      final far = l.createAnchor(5);
      final before = l.createAnchor(0);

      l.insertCells(1, 2);

      expect(inRange.x, 2); // inside the inserted range — stays put
      expect(atBoundary.x, 5); // at boundary — moves
      expect(far.x, 7); // moves
      expect(before.x, 0);
    });

    test('disposes anchors pushed past the line end', () {
      final l = BufferLine(4);
      final farRight = l.createAnchor(3);
      l.insertCells(1, 2);
      // 3 → 5, which is >= length (4) → disposed.
      expect(farRight.attached, isFalse);
    });
  });

  group('BufferLine — resize', () {
    test('same length is a no-op', () {
      final l = BufferLine(3);
      final before = l.data.length;
      l.resize(3);
      expect(l.length, 3);
      expect(l.data.length, before);
    });

    test('shrink keeps capacity, lowers length', () {
      final l = BufferLine(5);
      final cap = l.data.length;
      l.resize(2);
      expect(l.length, 2);
      expect(l.data.length, cap);
    });

    test('grow within capacity does not realloc', () {
      final l = BufferLine(2);
      final cap = l.data.length;
      l.resize(10);
      expect(l.length, 10);
      expect(l.data.length, cap); // still the initial 64-cell capacity
    });

    test('grow beyond capacity reallocates and copies', () {
      final l = BufferLine(2);
      l.setCodePoint(0, _aChar);
      final initialCap = l.data.length;
      l.resize(500); // forces capacity > initial — exercises the >=256 branch
      expect(l.length, 500);
      expect(l.data.length, greaterThan(initialCap));
      expect(l.getCodePoint(0), _aChar); // content preserved
    });

    test('grow into the [64, 256) capacity-doubling branch', () {
      // _calcCapacity grows by *2 while < 256 and < length. Pushing length
      // to 100 forces the doubling loop (64 → 128).
      final l = BufferLine(2);
      l.setCodePoint(0, _aChar);
      l.resize(100);
      expect(l.length, 100);
      expect(l.data.length, greaterThanOrEqualTo(128 * 4));
      expect(l.getCodePoint(0), _aChar);
    });

    test('clamps anchor x to new length on shrink', () {
      final l = BufferLine(10);
      final a = l.createAnchor(8);
      l.resize(5);
      expect(a.x, lessThanOrEqualTo(5));
    });
  });

  group('BufferLine — getTrimmedLength', () {
    test('empty line returns 0', () {
      final l = BufferLine(10);
      expect(l.getTrimmedLength(), 0);
      expect(l.getTrimmedLength(0), 0);
    });

    test('returns last-content-index + width for the last filled cell', () {
      final l = BufferLine(10);
      l.setCodePoint(0, _aChar);
      l.setCodePoint(1, _bChar);
      expect(l.getTrimmedLength(), 2);
    });

    test('honours wide cells at the end', () {
      final l = BufferLine(10);
      l.setCodePoint(0, _aChar);
      l.setCodePoint(1, _wideChar); // width 2
      expect(l.getTrimmedLength(), 3);
    });

    test('cols caps the search range', () {
      final l = BufferLine(10);
      l.setCodePoint(5, _aChar);
      expect(l.getTrimmedLength(3), 0); // searched indexes 0..2 only
      expect(l.getTrimmedLength(6), 6); // includes index 5
    });

    test('cols larger than capacity falls back to capacity', () {
      final l = BufferLine(2);
      l.setCodePoint(0, _aChar);
      // capacity is 64 cells; passing cols=999 should clamp.
      expect(l.getTrimmedLength(999), 1);
    });
  });

  group('BufferLine — copyFrom', () {
    test('copies cells from src to dst at the right offsets, resizing as needed', () {
      final src = BufferLine(5);
      for (var i = 0; i < 5; i++) {
        src.setCell(i, _aChar + i, 1, _style(fg: i + 1));
      }
      final dst = BufferLine(2);
      dst.copyFrom(src, 1, 0, 3);
      expect(dst.length, 3);
      expect(dst.getCodePoint(0), _aChar + 1);
      expect(dst.getCodePoint(1), _aChar + 2);
      expect(dst.getCodePoint(2), _aChar + 3);
      expect(dst.getForeground(0), 2);
    });
  });

  group('BufferLine — getText / toString', () {
    test('empty line returns empty string', () {
      expect(BufferLine(5).getText(), '');
      expect(BufferLine(5).toString(), '');
    });

    test('default args span the whole line', () {
      final l = BufferLine(3);
      l.setCodePoint(0, _aChar);
      l.setCodePoint(1, _bChar);
      expect(l.getText(), 'ab');
      expect(l.toString(), 'ab');
    });

    test('explicit from/to slice', () {
      final l = BufferLine(5);
      for (var i = 0; i < 5; i++) {
        l.setCodePoint(i, _aChar + i);
      }
      expect(l.getText(1, 3), 'bc');
    });

    test('clamps from < 0 and to > length', () {
      final l = BufferLine(3);
      l.setCodePoint(0, _aChar);
      l.setCodePoint(1, _bChar);
      expect(l.getText(-1, 99), 'ab');
    });

    test('skips a wide char that would extend past `to`', () {
      final l = BufferLine(4);
      l.setCodePoint(0, _aChar);
      l.setCodePoint(1, _wideChar); // width 2 — straddles 1..2
      // Asking for text up to index 2 (exclusive of 2) means the wide char
      // would extend past `to`; it's skipped.
      expect(l.getText(0, 2), 'a');
    });
  });

  group('BufferLine — anchors', () {
    test('createAnchor adds to anchors list and returns it owned by the line', () {
      final l = BufferLine(5);
      final a = l.createAnchor(2);
      expect(l.anchors, contains(a));
      expect(a.line, l);
      expect(a.x, 2);
    });

    test('dispose detaches all anchors', () {
      final l = BufferLine(5);
      final a = l.createAnchor(1);
      final b = l.createAnchor(3);
      l.dispose();
      expect(a.attached, isFalse);
      expect(b.attached, isFalse);
    });
  });

  group('CellAnchor', () {
    test('detached anchor: x, line are accessible; attached is false', () {
      final a = CellAnchor(7);
      expect(a.x, 7);
      expect(a.line, isNull);
      expect(a.attached, isFalse);
      expect(a.toString(), 'CellAnchor(7, detached)');
    });

    test('reposition updates x', () {
      final a = CellAnchor(2);
      a.reposition(10);
      expect(a.x, 10);
    });

    test('reparent moves the anchor between lines', () {
      final l1 = BufferLine(4);
      final l2 = BufferLine(4);
      final a = l1.createAnchor(0);
      a.reparent(l2, 3);
      expect(l1.anchors, isNot(contains(a)));
      expect(l2.anchors, contains(a));
      expect(a.x, 3);
    });

    test('reparent from a detached anchor wires it to a new owner', () {
      final l = BufferLine(4);
      final a = CellAnchor(0); // no owner
      a.reparent(l, 2);
      expect(l.anchors, contains(a));
      expect(a.x, 2);
    });

    test('attached anchor exposes y + offset via the owning circular buffer', () {
      final l = BufferLine(4);
      // Push the line into a buffer so its `attached` becomes true and
      // `index` is well-defined.
      final ring = IndexAwareCircularBuffer<BufferLine>(8)..push(l);
      expect(l.attached, isTrue);
      expect(ring.length, 1);

      final a = l.createAnchor(2);
      expect(a.attached, isTrue);
      expect(a.y, 0);
      expect(a.offset, const CellOffset(2, 0));
      expect(a.toString(), 'CellAnchor(2, 0)');
    });

    test('dispose detaches an attached anchor', () {
      final l = BufferLine(4);
      final a = l.createAnchor(1);
      a.dispose();
      expect(a.attached, isFalse);
      expect(l.anchors, isNot(contains(a)));
    });
  });
}
