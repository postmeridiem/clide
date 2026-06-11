/// Pure-Dart tests for the small `lib/src/terminal/src/core/*.dart`
/// files — cell, cursor, charset, tabs, reflow.
library;

import 'package:clide/src/terminal/src/core/buffer/line.dart';
import 'package:clide/src/terminal/src/core/cell.dart';
import 'package:clide/src/terminal/src/core/charset.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
import 'package:clide/src/terminal/src/core/reflow.dart';
import 'package:clide/src/terminal/src/core/tabs.dart';
import 'package:clide/src/terminal/src/utils/circular_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('CellData', () {
    test('explicit constructor stores all four channels', () {
      final c = CellData(foreground: 1, background: 2, flags: 4, content: 8);
      expect(c.foreground, 1);
      expect(c.background, 2);
      expect(c.flags, 4);
      expect(c.content, 8);
    });

    test('CellData.empty factory zeroes everything', () {
      final c = CellData.empty();
      expect(c.foreground, 0);
      expect(c.background, 0);
      expect(c.flags, 0);
      expect(c.content, 0);
    });

    test('getHash combines all four channels (different inputs → different hash)', () {
      final a = CellData(foreground: 1, background: 2, flags: 3, content: 4);
      final b = CellData(foreground: 1, background: 2, flags: 3, content: 4);
      expect(a.getHash(), b.getHash());
      final c = CellData(foreground: 1, background: 2, flags: 3, content: 5);
      expect(a.getHash(), isNot(c.getHash()));
    });

    test('toString shape is the documented debug format', () {
      final c = CellData(foreground: 1, background: 2, flags: 4, content: 8);
      expect(c.toString(), 'CellData{foreground: 1, background: 2, flags: 4, content: 8}');
    });
  });

  group('CursorStyle', () {
    test('default constructor zeroes all three fields', () {
      final c = CursorStyle();
      expect(c.foreground, 0);
      expect(c.background, 0);
      expect(c.attrs, 0);
    });

    test('every set / unset attr toggles the right CellAttr bit', () {
      final c = CursorStyle();
      // Pair each setter with its corresponding getter and unsetter.
      final cases = <(void Function(), void Function(), bool Function())>[
        (c.setBold, c.unsetBold, () => c.isBold),
        (c.setFaint, c.unsetFaint, () => c.isFaint),
        (c.setItalic, c.unsetItalic, () => c.isItalic),
        (c.setUnderline, c.unsetUnderline, () => c.isUnderline),
        (c.setBlink, c.unsetBlink, () => c.isBlink),
        (c.setInverse, c.unsetInverse, () => c.isInverse),
        (c.setInvisible, c.unsetInvisible, () => c.isInvisible),
      ];
      for (final (set, unset, getter) in cases) {
        c.attrs = 0;
        expect(getter(), isFalse);
        set();
        expect(getter(), isTrue);
        unset();
        expect(getter(), isFalse);
      }
      // Strikethrough has no getter — exercise its set / unset directly.
      c.attrs = 0;
      c.setStrikethrough();
      expect(c.attrs & CellAttr.strikethrough, isNot(0));
      c.unsetStrikethrough();
      expect(c.attrs & CellAttr.strikethrough, 0);
    });

    test('foreground 16 / 256 / RGB encode the right CellColor type bits', () {
      final c = CursorStyle();
      c.setForegroundColor16(3);
      expect(c.foreground, 3 | CellColor.named);
      c.setForegroundColor256(200);
      expect(c.foreground, 200 | CellColor.palette);
      c.setForegroundColorRgb(0x10, 0x20, 0x30);
      expect(c.foreground, 0x10 << 16 | 0x20 << 8 | 0x30 | CellColor.rgb);
      c.resetForegroundColor();
      expect(c.foreground, 0);
    });

    test('background 16 / 256 / RGB encode the right CellColor type bits', () {
      final c = CursorStyle();
      c.setBackgroundColor16(5);
      expect(c.background, 5 | CellColor.named);
      c.setBackgroundColor256(123);
      expect(c.background, 123 | CellColor.palette);
      c.setBackgroundColorRgb(1, 2, 3);
      expect(c.background, 1 << 16 | 2 << 8 | 3 | CellColor.rgb);
      c.resetBackgroundColor();
      expect(c.background, 0);
    });

    test('reset wipes all three fields', () {
      final c = CursorStyle()
        ..setBold()
        ..setForegroundColor16(2)
        ..setBackgroundColor256(99);
      c.reset();
      expect(c.foreground, 0);
      expect(c.background, 0);
      expect(c.attrs, 0);
    });

    test('CursorStyle.empty exposes a default-zero singleton', () {
      // Don't mutate this — it's a shared singleton.
      expect(CursorStyle.empty.foreground, 0);
      expect(CursorStyle.empty.background, 0);
      expect(CursorStyle.empty.attrs, 0);
    });
  });

  group('CursorPosition', () {
    test('exposes mutable x / y fields', () {
      final p = CursorPosition(3, 5);
      expect(p.x, 3);
      expect(p.y, 5);
      p.x = 7;
      p.y = 9;
      expect(p.x, 7);
      expect(p.y, 9);
    });
  });

  group('Charset', () {
    test('asciiTranslator is identity', () {
      expect(asciiTranslator(0x41), 0x41);
      expect(asciiTranslator(0x7e), 0x7e);
    });

    test('decSpecGraphicsTranslator maps the documented codepoints', () {
      // 0x6a → BOX DRAWINGS LIGHT UP AND LEFT (0x2518)
      expect(decSpecGraphicsTranslator(0x6a), 0x2518);
      // 0x71 → BOX DRAWINGS LIGHT HORIZONTAL (0x2500)
      expect(decSpecGraphicsTranslator(0x71), 0x2500);
    });

    test('decSpecGraphicsTranslator passes unmapped low-codepoints through', () {
      expect(decSpecGraphicsTranslator(0x41), 0x41); // 'A' is unmapped
    });

    test('decSpecGraphicsTranslator passes high codepoints through', () {
      // The spec only maps 0x5f..0x7e; anything ≥ 127 is identity.
      expect(decSpecGraphicsTranslator(0x100), 0x100);
      expect(decSpecGraphicsTranslator(0x4E2D), 0x4E2D);
    });

    test('translate defaults to ascii when no charset is designated', () {
      final c = Charset();
      expect(c.translate(0x6a), 0x6a);
    });

    test('designate + use switch the active translator', () {
      final c = Charset();
      // Designate the DEC special-graphics charset at slot 0…
      c.designate(0, '0'.codeUnitAt(0));
      // …and select slot 0 as the active charset.
      c.use(0);
      expect(c.translate(0x6a), 0x2518); // now maps via DEC graphics
      // Switch back to a slot with no designated charset → ascii fallback.
      c.use(1);
      expect(c.translate(0x6a), 0x6a);
    });

    test('designate ignores unknown charset names without changing state', () {
      final c = Charset();
      c.designate(0, 0xFFFF); // not in the _charsets table
      c.use(0);
      expect(c.translate(0x6a), 0x6a); // still ascii
    });

    test('save / restore round-trips both the map and the active index', () {
      final c = Charset();
      c.designate(0, '0'.codeUnitAt(0));
      c.use(0);
      c.save();
      // Mutate after save…
      c.designate(0, 'B'.codeUnitAt(0)); // ascii in slot 0 — translate is identity
      c.use(1);
      expect(c.translate(0x6a), 0x6a);
      // …restore should reinstate the saved DEC-graphics binding.
      c.restore();
      expect(c.translate(0x6a), 0x2518);
    });
  });

  group('TabStops', () {
    test('default state has tab stops every 8 columns', () {
      final t = TabStops();
      for (var i = 0; i < 100; i++) {
        expect(t.isSetAt(i), i % 8 == 0, reason: 'col $i');
      }
    });

    test('find — returns first set stop in [start, end)', () {
      final t = TabStops();
      // Default: 0, 8, 16, 24, ...
      expect(t.find(1, 20), 8);
      expect(t.find(8, 20), 8);
      expect(t.find(9, 16), isNull); // no stops in [9, 16)
      expect(t.find(0, 1), 0);
    });

    test('find returns null when start >= end', () {
      final t = TabStops();
      expect(t.find(10, 10), isNull);
      expect(t.find(20, 5), isNull);
    });

    test('find clamps end to the underlying array length', () {
      final t = TabStops();
      // 99999 > _kMaxColumns; should still return a valid stop without
      // walking out of bounds.
      expect(t.find(0, 99999), 0);
    });

    test('setAt + clearAt toggle individual columns', () {
      final t = TabStops();
      t.clearAt(8);
      expect(t.isSetAt(8), isFalse);
      t.setAt(3);
      expect(t.isSetAt(3), isTrue);
      t.clearAt(3);
      expect(t.isSetAt(3), isFalse);
    });

    test('clearAll wipes every stop without restoring the default grid', () {
      final t = TabStops();
      t.clearAll();
      for (var i = 0; i < 100; i++) {
        expect(t.isSetAt(i), isFalse, reason: 'col $i');
      }
    });

    test('reset clears then re-installs the default 8-column grid', () {
      final t = TabStops();
      t.setAt(3);
      t.clearAt(8);
      t.reset();
      // 3 should no longer be set; 8 should be set again.
      expect(t.isSetAt(3), isFalse);
      expect(t.isSetAt(8), isTrue);
    });
  });

  group('reflow', () {
    BufferLine line(int width, [String? text]) {
      final l = BufferLine(width);
      if (text != null) {
        for (var i = 0; i < text.length; i++) {
          l.setCodePoint(i, text.codeUnitAt(i));
        }
      }
      return l;
    }

    IndexAwareCircularBuffer<BufferLine> ring(List<BufferLine> ls) {
      final r = IndexAwareCircularBuffer<BufferLine>(ls.length + 4);
      for (final l in ls) {
        r.push(l);
      }
      return r;
    }

    test('empty input produces empty output', () {
      final out = reflow(ring([]), 80, 80);
      expect(out, isEmpty);
    });

    test('single empty line is reused as-is', () {
      final l = line(8);
      final out = reflow(ring([l]), 8, 8);
      expect(out.length, 1);
      expect(identical(out.first, l), isTrue);
    });

    test('grow width keeps lines and resizes them to the new width', () {
      final out = reflow(ring([line(4, 'abcd')]), 4, 8);
      expect(out, hasLength(1));
      expect(out.first.length, 8);
      expect(out.first.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(out.first.getCodePoint(3), 'd'.codeUnitAt(0));
    });

    test('shrink width splits a single full line into wrapped pieces', () {
      // 8 chars on a width-8 line, reflowed to width 4 → two width-4 lines.
      final out = reflow(ring([line(8, 'abcdefgh')]), 8, 4);
      expect(out, hasLength(2));
      expect(out[0].getCodePoint(0), 'a'.codeUnitAt(0));
      expect(out[0].isWrapped, isFalse); // first line of a logical run
      expect(out[1].getCodePoint(0), 'e'.codeUnitAt(0));
      expect(out[1].isWrapped, isTrue);
    });

    test('continues a wrapped run across input lines and re-emits wrapped output', () {
      // Two width-4 lines forming a single logical line "abcdefgh", reflowed
      // back to width 8 → a single line of 8 chars.
      final a = line(4, 'abcd');
      final b = line(4, 'efgh')..isWrapped = true;
      final out = reflow(ring([a, b]), 4, 8);
      expect(out, hasLength(1));
      expect(out.first.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(out.first.getCodePoint(7), 'h'.codeUnitAt(0));
    });

    test('shrink across a wide char does not split it across two output lines', () {
      // Layout on a width-6 input: 'ab中cd' — the wide char straddles
      // columns 2..3. Reflow to width 4 → first line is 'ab' + space (the
      // wide char wouldn't fit), second line carries the wide char + 'cd'.
      final l = BufferLine(6);
      l.setCodePoint(0, 'a'.codeUnitAt(0));
      l.setCodePoint(1, 'b'.codeUnitAt(0));
      l.setCodePoint(2, '中'.runes.first); // width 2 → occupies 2..3
      l.setCodePoint(4, 'c'.codeUnitAt(0));
      l.setCodePoint(5, 'd'.codeUnitAt(0));

      final out = reflow(ring([l]), 6, 4);
      expect(out.length, greaterThanOrEqualTo(2));
      // First output line should not have started its last cell on the wide
      // char's first half — i.e. cell index 3 should be empty (width-clamp
      // branch fired during the initial fill).
      expect(out[0].getCodePoint(3), 0);
    });

    test('shrink with a wide char at the new boundary takes the from=newWidth-1 path', () {
      // The branch at reflow.dart:88 only fires when the cell at the new
      // boundary (newWidth-1) is itself the first half of a wide char.
      final l = BufferLine(6);
      l.setCodePoint(0, 'a'.codeUnitAt(0));
      l.setCodePoint(1, 'b'.codeUnitAt(0));
      l.setCodePoint(2, 'c'.codeUnitAt(0));
      l.setCodePoint(3, '中'.runes.first); // wide → straddles 3..4
      l.setCodePoint(5, 'd'.codeUnitAt(0));

      // newWidth=4 → boundary cell is 3, which is the wide char's first half.
      final out = reflow(ring([l]), 6, 4);
      expect(out.length, greaterThanOrEqualTo(2));
      // The wide char should not survive as a half-cell on the first line.
      expect(out[0].getCodePoint(3), 0);
    });

    test('anchors on the source line tail (past trimmedLength) land on a line in the result (T-92)', () {
      // The post-loop tail-anchor branch in `_addPart` reparents the
      // anchor onto the active builder line. The fix in T-92 makes
      // `finish()` emit that builder line when it has anchors, even if
      // it's otherwise empty — so the anchor's `line` is guaranteed to
      // be in the reflow result and stays attached after replaceWith.
      final src = line(12, 'abcdefgh'); // width 12, content 8
      final tail = src.createAnchor(10); // past trimmedLength (8)
      final out = reflow(ring([src]), 12, 4);
      expect(tail.line, isNotNull);
      expect(out.contains(tail.line), isTrue);
    });

    test('SelectAllTextIntent-shaped end anchor survives shrink (T-92 regression)', () {
      // Models the actual bug path: SelectAllTextIntent (actions.dart)
      // creates an end anchor at x = viewWidth on the last buffer line.
      // Resizing narrower must not silently drop the selection.
      final src = line(12, 'short');
      final endAnchor = src.createAnchor(12); // viewWidth, past trimmedLength
      final out = reflow(ring([src]), 12, 4);
      expect(
        out.contains(endAnchor.line),
        isTrue,
        reason:
            'end anchor must land on a line that survives '
            'lines.replaceWith — otherwise selection.attached is false '
            'and the selection silently vanishes after resize.',
      );
    });

    test('inner wide-char clamp during _addPart leaves the wide cell to the next iteration', () {
      // The clamp at reflow.dart:124 fires when the iteration is about to
      // fill the builder AND the last cell would be the first half of a
      // wide char — _addPart pushes that copy to the next iteration.
      final src = BufferLine(9);
      for (var i = 0; i < 7; i++) {
        src.setCodePoint(i, 'a'.codeUnitAt(0) + i);
      }
      // Set wide at index 7 (straddles 7..8).
      src.setCodePoint(7, '中'.runes.first);
      final out = reflow(ring([src]), 9, 4);
      expect(out.length, greaterThanOrEqualTo(2));
    });

    test('anchors on the source line get reparented to the reflowed output', () {
      // CellAnchor.attached delegates to its owning BufferLine.attached
      // (which itself reflects whether the line sits in an
      // IndexAwareCircularBuffer). Reflow returns a plain List, so the
      // output lines aren't "attached" — but anchors should still point
      // to one of the lines in the result.
      final src = line(8, 'abcdefgh');
      final anchorAtStart = src.createAnchor(0);
      final anchorMid = src.createAnchor(5);
      final out = reflow(ring([src]), 8, 4);
      expect(out, hasLength(2));

      // anchorAtStart was at x=0 on the original line; reflow's first
      // step is `_lines.add(line)`, so the original line is the first
      // output. The anchor should still point to that same instance.
      expect(out.contains(anchorAtStart.line), isTrue);

      // anchorMid was at x=5; the [4..8) tail is split out via _addPart
      // and lands on the second output line, with the anchor reparented
      // there.
      expect(out.contains(anchorMid.line), isTrue);
      expect(anchorMid.line, isNot(equals(anchorAtStart.line)));
    });
  });
}
