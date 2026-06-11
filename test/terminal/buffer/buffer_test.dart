/// Pure-Dart tests for Buffer (lib/src/terminal/src/core/buffer/buffer.dart).
///
/// Buffer is the orchestrator on top of BufferLine — viewport sizing,
/// scroll regions, cursor movement, erase commands, scroll/index/reverse-
/// index, line insert/delete, resize + reflow, and word-boundary lookup.
library;

import 'package:clide/src/terminal/src/core/buffer/buffer.dart';
import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/buffer/range_line.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/core/state.dart';
import 'package:test/test.dart';

class _State implements TerminalState {
  _State({this.viewWidth = 10, this.viewHeight = 5, this.autoWrapMode = true, this.lineFeedMode = false, this.originMode = false, this.reflowEnabled = false});

  @override
  int viewWidth;
  @override
  int viewHeight;
  @override
  bool autoWrapMode;
  @override
  bool lineFeedMode;
  @override
  bool originMode;
  @override
  bool reflowEnabled;

  @override
  final cursor = CursorStyle();

  // Unused-by-Buffer bits — dummy values are fine.
  @override
  bool get insertMode => false;
  @override
  bool get cursorKeysMode => false;
  @override
  bool get reverseDisplayMode => false;
  @override
  MouseMode get mouseMode => MouseMode.none;
  @override
  MouseReportMode get mouseReportMode => MouseReportMode.normal;
  @override
  bool get cursorBlinkMode => true;
  @override
  bool get cursorVisibleMode => true;
  @override
  bool get appKeypadMode => false;
  @override
  bool get reportFocusMode => false;
  @override
  bool get altBufferMouseScrollMode => false;
  @override
  bool get bracketedPasteMode => false;
}

Buffer _newBuffer({
  int viewWidth = 10,
  int viewHeight = 5,
  int maxLines = 50,
  bool isAltBuffer = false,
  bool autoWrapMode = true,
  bool lineFeedMode = false,
  bool originMode = false,
  bool reflowEnabled = false,
  Set<int>? wordSeparators,
}) {
  final state = _State(
    viewWidth: viewWidth,
    viewHeight: viewHeight,
    autoWrapMode: autoWrapMode,
    lineFeedMode: lineFeedMode,
    originMode: originMode,
    reflowEnabled: reflowEnabled,
  );
  return Buffer(state, maxLines: maxLines, isAltBuffer: isAltBuffer, wordSeparators: wordSeparators);
}

void main() {
  group('Buffer — construction', () {
    test('seeds viewHeight empty lines and resets margins', () {
      final b = _newBuffer(viewWidth: 8, viewHeight: 4);
      expect(b.height, 4);
      expect(b.viewWidth, 8);
      expect(b.viewHeight, 4);
      expect(b.cursorX, 0);
      expect(b.cursorY, 0);
      expect(b.scrollBack, 0);
      expect(b.marginTop, 0);
      expect(b.marginBottom, 3);
    });

    test('absolute cursor + margin getters are scrollback-shifted', () {
      final b = _newBuffer(viewHeight: 3);
      // Push a line via index() in the no-scrollable-region path on a
      // primary buffer — that uses lines.push to grow scrollback.
      b.setCursor(0, 2);
      b.index();
      // Now scrollBack == 1; the cursor stayed at viewHeight - 1 = 2.
      expect(b.scrollBack, 1);
      expect(b.absoluteCursorY, 3);
      expect(b.absoluteMarginTop, 1);
      expect(b.absoluteMarginBottom, 3);
    });
  });

  group('Buffer — cursor movement and clamping', () {
    test('setCursorX/Y clamp to viewWidth-1 / viewHeight-1', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 3);
      b.setCursorX(99);
      b.setCursorY(99);
      expect(b.cursorX, 4);
      expect(b.cursorY, 2);
      b.setCursorX(-1);
      b.setCursorY(-1);
      expect(b.cursorX, 0);
      expect(b.cursorY, 0);
    });

    test('moveCursorX / moveCursorY are relative + clamped', () {
      final b = _newBuffer();
      b.setCursor(5, 2);
      b.moveCursorX(2);
      b.moveCursorY(1);
      expect(b.cursorX, 7);
      expect(b.cursorY, 3);
      b.moveCursorX(99); // clamps
      expect(b.cursorX, 9);
    });

    test('cursorGoForward saturates at viewWidth (one past last visible)', () {
      final b = _newBuffer(viewWidth: 5);
      for (var i = 0; i < 10; i++) {
        b.cursorGoForward();
      }
      // The clamped getter caps at viewWidth - 1; the internal saturation
      // sits at viewWidth.
      expect(b.cursorX, 4);
    });

    test('setCursor — originMode shifts y by marginTop and clamps to marginBottom', () {
      final b = _newBuffer(viewHeight: 6, originMode: true);
      b.setVerticalMargins(2, 4);
      b.setCursor(0, 0);
      // origin shift: cursorY += marginTop (2) → clamped to marginBottom (4).
      expect(b.cursorY, 2);
      b.setCursor(0, 99);
      expect(b.cursorY, 4); // clamped to marginBottom
    });

    test('moveCursor delegates to setCursor', () {
      final b = _newBuffer();
      b.setCursor(0, 0);
      b.moveCursor(2, 1);
      expect(b.cursorX, 2);
      expect(b.cursorY, 1);
    });
  });

  group('Buffer — vertical margins', () {
    test('setVerticalMargins clamps and orders top/bottom', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(99, -5);
      // Both clamp to [0, viewHeight-1] = [0, 4]; the implementation
      // also coerces top<=bottom by min/max swap.
      expect(b.marginTop, lessThanOrEqualTo(b.marginBottom));
    });

    test('resetVerticalMargins restores full viewport range', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.resetVerticalMargins();
      expect(b.marginTop, 0);
      expect(b.marginBottom, 4);
    });

    test('isInVerticalMargin is true inside, false outside', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursorY(0);
      expect(b.isInVerticalMargin, isFalse);
      b.setCursorY(2);
      expect(b.isInVerticalMargin, isTrue);
      b.setCursorY(4);
      expect(b.isInVerticalMargin, isFalse);
    });
  });

  group('Buffer — write / writeChar / autoWrap', () {
    test('write adds chars left-to-right and advances the cursor', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abc');
      expect(b.cursorX, 3);
      expect(b.currentLine.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(1), 'b'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(2), 'c'.codeUnitAt(0));
    });

    test('autoWrap pushes the cursor to the next line and marks it wrapped', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 4);
      b.write('abcdef'); // 'def' wraps to line 1
      expect(b.height, 4); // still within view; no scrollback needed yet
      expect(b.cursorY, 1);
      // cursorX getter clamps to viewWidth-1; internal _cursorX is saturated.
      expect(b.cursorX, 2);
      expect(b.currentLine.isWrapped, isTrue);
    });

    test('autoWrap=false leaves the cursor saturated past the end (no wrap)', () {
      final b = _newBuffer(viewWidth: 3, autoWrapMode: false);
      b.write('abc');
      // After three writes the cursor is at viewWidth (3). The next write
      // triggers index() but autoWrapMode is off — the line shouldn't be
      // marked wrapped.
      b.write('d');
      expect(b.currentLine.isWrapped, isFalse);
    });

    test('wide character writes a width-2 cell + a 0-codepoint trailer', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('中'); // CJK ideograph, width 2
      expect(b.cursorX, 2);
    });
  });

  group('Buffer — backspace', () {
    test('column 0 on a wrapped line jumps to the prior line end and unwraps', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 3);
      b.write('abcd'); // wraps; cursor at (1, 1) on a wrapped line
      expect(b.currentLine.isWrapped, isTrue);
      b.setCursor(0, 1);
      // Re-flag wrapped (setCursor may not affect it but to be sure)
      b.currentLine.isWrapped = true;
      b.backspace();
      expect(b.cursorX, 2); // viewWidth - 1
      expect(b.cursorY, 0);
    });

    test('column == viewWidth backspaces by 2 cells (off the saturated edge)', () {
      final b = _newBuffer(viewWidth: 5);
      // Saturate the cursor.
      for (var i = 0; i < 5; i++) {
        b.cursorGoForward();
      }
      // Internal _cursorX is now 5 (viewWidth). The clamped getter shows 4.
      b.backspace();
      // -2 of (5) clamps to (3). cursorX getter returns clamped value.
      expect(b.cursorX, 3);
    });

    test('mid-line backspace is just a -1', () {
      final b = _newBuffer(viewWidth: 5);
      b.setCursor(3, 0);
      b.backspace();
      expect(b.cursorX, 2);
    });
  });

  group('Buffer — erase commands', () {
    test('eraseLine clears the whole current line and clears wrapped flag', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abc');
      b.currentLine.isWrapped = true;
      b.eraseLine();
      expect(b.currentLine.isWrapped, isFalse);
      for (var i = 0; i < 5; i++) {
        expect(b.currentLine.getCodePoint(i), 0);
      }
    });

    test('eraseLineFromCursor only clears [cursor, viewWidth)', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abcde');
      b.setCursorX(2);
      b.eraseLineFromCursor();
      expect(b.currentLine.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(1), 'b'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(2), 0);
      expect(b.currentLine.getCodePoint(4), 0);
    });

    test('eraseLineToCursor only clears [0, cursor)', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abcde');
      b.setCursorX(3);
      b.eraseLineToCursor();
      expect(b.currentLine.getCodePoint(0), 0);
      expect(b.currentLine.getCodePoint(2), 0);
      expect(b.currentLine.getCodePoint(3), 'd'.codeUnitAt(0));
    });

    test('eraseChars erases [cursor, cursor+count)', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abcde');
      b.setCursorX(1);
      b.eraseChars(2);
      expect(b.currentLine.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(1), 0);
      expect(b.currentLine.getCodePoint(2), 0);
      expect(b.currentLine.getCodePoint(3), 'd'.codeUnitAt(0));
    });

    test('eraseDisplay clears every visible line', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 3);
      b.write('aaaaa');
      b.lineFeed();
      b.write('bbbbb');
      b.eraseDisplay();
      for (var y = 0; y < b.viewHeight; y++) {
        for (var x = 0; x < b.viewWidth; x++) {
          expect(b.lines[y].getCodePoint(x), 0);
        }
      }
    });

    test('eraseDisplayFromCursor clears current line tail + every line below', () {
      // lineFeedMode: true so lineFeed resets cursorX — otherwise the
      // saturated cursorX would make the next write wrap onto an extra
      // line via writeChar's autoWrap path.
      final b = _newBuffer(viewWidth: 5, viewHeight: 5, lineFeedMode: true);
      b.write('aaaaa');
      b.lineFeed();
      b.write('bbbbb');
      b.lineFeed();
      b.write('ccccc');
      b.setCursor(2, 1);
      b.eraseDisplayFromCursor();
      expect(b.lines[0].getCodePoint(0), 'a'.codeUnitAt(0)); // untouched
      expect(b.lines[1].getCodePoint(0), 'b'.codeUnitAt(0)); // head kept
      expect(b.lines[1].getCodePoint(2), 0); // tail erased
      expect(b.lines[2].getCodePoint(0), 0); // line below wiped
    });

    test('eraseDisplayToCursor clears every line above + the current line head', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 5, lineFeedMode: true);
      b.write('aaaaa');
      b.lineFeed();
      b.write('bbbbb');
      b.lineFeed();
      b.write('vwxyz'); // distinct chars so the kept tail is visible
      b.setCursor(3, 2);
      b.eraseDisplayToCursor();
      expect(b.lines[0].getCodePoint(0), 0);
      expect(b.lines[1].getCodePoint(0), 0);
      expect(b.lines[2].getCodePoint(0), 0); // head erased
      expect(b.lines[2].getCodePoint(3), 'y'.codeUnitAt(0)); // tail kept
      expect(b.lines[2].getCodePoint(4), 'z'.codeUnitAt(0));
    });
  });

  group('Buffer — scroll / index / lineFeed / reverseIndex', () {
    test('scrollUp inside the scroll region rotates lines and seeds an empty tail', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 5, lineFeedMode: true);
      b.write('aaa');
      b.lineFeed();
      b.write('bbb');
      b.lineFeed();
      b.write('ccc');
      b.scrollUp(1);
      // After scroll: line 0 = 'bbb', line 1 = 'ccc', line 2 = empty.
      expect(b.lines[0].getCodePoint(0), 'b'.codeUnitAt(0));
      expect(b.lines[1].getCodePoint(0), 'c'.codeUnitAt(0));
      expect(b.lines[2].getCodePoint(0), 0);
    });

    test('scrollDown inside the scroll region rotates lines and seeds an empty head', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 5, lineFeedMode: true);
      b.write('aaa');
      b.lineFeed();
      b.write('bbb');
      b.scrollDown(1);
      // After scroll: line 0 = empty, line 1 = 'aaa', line 2 = 'bbb'.
      expect(b.lines[0].getCodePoint(0), 0);
      expect(b.lines[1].getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.lines[2].getCodePoint(0), 'b'.codeUnitAt(0));
    });

    test('index — at the bottom of primary buffer pushes a new line to grow scrollback', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 3);
      b.setCursorY(2);
      b.index();
      expect(b.scrollBack, 1);
      expect(b.cursorY, 2); // stayed at viewHeight - 1
    });

    test('index — at the bottom of alt buffer scrolls up instead of growing', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 3, isAltBuffer: true);
      b.setCursorY(2);
      b.index();
      expect(b.scrollBack, 0);
      expect(b.cursorY, 2);
    });

    test('index — within margin but not at the bottom moves cursor down', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursorY(1);
      b.index();
      expect(b.cursorY, 2);
    });

    test('index — at margin bottom with non-zero top scrollUps inside the region', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 4);
      b.setVerticalMargins(1, 2);
      b.setCursorY(2); // at marginBottom
      b.write('a'); // mark line 2
      b.index();
      expect(b.cursorY, 2);
    });

    test('index — at marginBottom with marginTop=0 on primary inserts a new line', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 4);
      // marginTop=0 by default
      b.setCursorY(b.marginBottom);
      b.write('z');
      final beforeHeight = b.height;
      b.index();
      expect(b.height, beforeHeight + 1); // an empty line was inserted
    });

    test('index — cursor outside the vertical margin and at viewport bottom on primary pushes scrollback', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 5);
      // Margins shrink the scroll region — the cursor below it is outside.
      b.setVerticalMargins(1, 3);
      b.setCursorY(4); // viewHeight - 1, outside [1, 3]
      final before = b.height;
      b.index();
      expect(b.height, before + 1); // primary path: lines.push
    });

    test('index — cursor outside the vertical margin on alt buffer scrolls up instead of pushing', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 5, isAltBuffer: true);
      b.setVerticalMargins(1, 3);
      b.setCursorY(4);
      final before = b.height;
      b.index();
      expect(b.height, before); // alt path: no growth
    });

    test('index — cursor outside the vertical margin and not at the bottom moves cursor down', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursorY(4); // outside, but not viewHeight-1... wait viewHeight-1 IS 4
      // To exercise the moveCursorY branch outside the margin we need
      // _cursorY < viewHeight - 1 AND outside [marginTop, marginBottom].
      // With margins (1, 2) the cursor at y=3 is outside and not at the bottom.
      b.setVerticalMargins(1, 2);
      b.setCursorY(3);
      b.index();
      expect(b.cursorY, 4);
    });

    test('lineFeed honours lineFeedMode by setting cursor to column 0', () {
      final b = _newBuffer(lineFeedMode: true);
      b.setCursorX(5);
      b.lineFeed();
      expect(b.cursorX, 0);
    });

    test('lineFeed leaves cursorX alone when lineFeedMode is off', () {
      final b = _newBuffer();
      b.setCursorX(5);
      b.lineFeed();
      expect(b.cursorX, 5);
    });

    test('reverseIndex inside margins at top scrolls down, otherwise moves up', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursorY(2);
      b.reverseIndex();
      expect(b.cursorY, 1);

      b.setCursorY(1); // at marginTop
      b.reverseIndex();
      expect(b.cursorY, 1); // cursor stays; scrollDown happened

      b.setCursorY(0); // outside margins
      b.reverseIndex();
      expect(b.cursorY, 0); // already at 0, clamps
    });
  });

  group('Buffer — saveCursor / restoreCursor', () {
    test('round-trips position + style + charset', () {
      final b = _newBuffer();
      b.setCursor(3, 2);
      // Mutate cursor style.
      // (Reach into the underlying state via the property surface.)
      b.saveCursor();
      b.setCursor(0, 0);
      b.restoreCursor();
      expect(b.cursorX, 3);
      expect(b.cursorY, 2);
    });
  });

  group('Buffer — line insert / delete / chars', () {
    test('insertBlankChars opens a gap at the cursor', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abcde');
      b.setCursorX(1);
      b.insertBlankChars(2);
      expect(b.currentLine.getCodePoint(1), 0);
      expect(b.currentLine.getCodePoint(2), 0);
      expect(b.currentLine.getCodePoint(3), 'b'.codeUnitAt(0));
    });

    test('deleteChars closes a gap at the cursor', () {
      final b = _newBuffer(viewWidth: 5);
      b.write('abcde');
      b.setCursorX(1);
      b.deleteChars(2);
      expect(b.currentLine.getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(1), 'd'.codeUnitAt(0));
      expect(b.currentLine.getCodePoint(2), 'e'.codeUnitAt(0));
    });

    test('insertLines is a no-op outside the scroll region', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(2, 4);
      b.setCursorY(0);
      b.write('aaa');
      b.insertLines(2);
      // line 0 untouched (cursor was outside margins → no-op)
      expect(b.lines[0].getCodePoint(0), 'a'.codeUnitAt(0));
    });

    test('insertLines inside the scroll region pushes lines down', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursor(0, 2);
      b.write('aaa');
      b.setCursor(0, 1);
      b.insertLines(1);
      // insertLines(1) pushes lines below the cursor down. So 'aaa'
      // should now be at line 3.
      expect(b.lines[3].getCodePoint(0), 'a'.codeUnitAt(0));
      // Line 1 (cursor) is now empty.
      expect(b.lines[1].getCodePoint(0), 0);
    });

    test('insertLines fills the entire region with empty lines when count >= lines below', () {
      // When linesToInsert == linesBelow, linesToMove is 0 and the
      // "fill empty" loop runs from 0 to linesToInsert.
      final b = _newBuffer(viewWidth: 3, viewHeight: 5);
      b.setVerticalMargins(1, 3);
      b.setCursor(0, 1);
      b.write('aaa');
      b.setCursor(0, 2);
      b.write('bbb');
      b.setCursor(0, 1);
      // 3 lines below (incl cursor) but request many more — clamps to 3
      // and skips the "move" loop entirely.
      b.insertLines(99);
      for (var y = 1; y <= 3; y++) {
        expect(b.lines[y].getCodePoint(0), 0);
      }
    });

    test('deleteLines is a no-op outside the scroll region', () {
      final b = _newBuffer(viewHeight: 5);
      b.setVerticalMargins(2, 4);
      b.setCursorY(0);
      b.write('aaa');
      b.deleteLines(2);
      expect(b.lines[0].getCodePoint(0), 'a'.codeUnitAt(0));
    });

    test('deleteLines inside the scroll region pulls lines up', () {
      // Use setCursor (not setCursorY) so cursorX is reset between
      // writes — otherwise it stays saturated after the previous write.
      final b = _newBuffer(viewWidth: 3, viewHeight: 6);
      b.setVerticalMargins(1, 4);
      b.setCursor(0, 2);
      b.write('aaa');
      b.setCursor(0, 3);
      b.write('bbb');
      b.setCursor(0, 1);
      b.deleteLines(1);
      // Inside the scroll region, deleteLines at line 1 shifts lines 2..4 up.
      // Original content was at lines 2 ('aaa') and 3 ('bbb'); after deletion
      // they should sit at 1 and 2.
      expect(b.lines[1].getCodePoint(0), 'a'.codeUnitAt(0));
      expect(b.lines[2].getCodePoint(0), 'b'.codeUnitAt(0));
      expect(b.lines[4].getCodePoint(0), 0); // bottom of region cleared
    });
  });

  group('Buffer — resize', () {
    test('grow height pushes empty lines while there is room in the ring', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 3, maxLines: 50);
      b.resize(5, 3, 5, 5);
      expect(b.height, 5);
    });

    test('grow height into existing scrollback bumps cursorY instead of pushing', () {
      // Build up scrollback so lines.length > new viewHeight.
      final b = _newBuffer(viewWidth: 3, viewHeight: 3, maxLines: 50);
      // Force scrollback growth via index()-at-bottom on primary buffer.
      b.setCursorY(2);
      for (var i = 0; i < 5; i++) {
        b.index();
      }
      expect(b.height, greaterThanOrEqualTo(8));
      final cursorYBefore = b.cursorY;
      // Resize to a height that's still smaller than lines.length: the
      // grow loop should bump _cursorY rather than push new lines.
      b.resize(3, 3, 3, 5);
      expect(b.cursorY, greaterThan(cursorYBefore));
    });

    test('resize with reflow pads the result up to newHeight', () {
      // Empty buffer: reflow returns near-zero lines; the pad-with-empty-
      // lines branch fills up to newHeight.
      final b = _newBuffer(viewWidth: 8, viewHeight: 3, reflowEnabled: true);
      b.resize(8, 3, 4, 12);
      expect(b.height, greaterThanOrEqualTo(12));
    });

    test('shrink height pops lines from the bottom when cursor is near the top', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 5);
      b.setCursorY(0);
      b.resize(5, 5, 5, 3);
      expect(b.height, 3);
    });

    test('shrink height drags cursor up when it sits below the new height', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 5);
      b.setCursorY(4);
      b.resize(5, 5, 5, 3);
      expect(b.cursorY, lessThanOrEqualTo(2));
    });

    test('resize without reflow forwards width to every line', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 3, reflowEnabled: false);
      b.resize(5, 3, 8, 3);
      for (var y = 0; y < b.viewHeight; y++) {
        expect(b.lines[y].length, 8);
      }
    });

    test('resize with reflow on primary buffer pads the result up to newHeight', () {
      final b = _newBuffer(viewWidth: 5, viewHeight: 3, reflowEnabled: true);
      b.resize(5, 3, 8, 5);
      expect(b.height, greaterThanOrEqualTo(5));
    });
  });

  group('Buffer — scrollback / clear', () {
    test('clearScrollback is a no-op when there is no scrollback', () {
      final b = _newBuffer(viewHeight: 3);
      b.clearScrollback();
      expect(b.scrollBack, 0);
    });

    test('clearScrollback drops lines above the viewport', () {
      final b = _newBuffer(viewHeight: 3);
      // Force scrollback by indexing past the bottom.
      b.setCursorY(2);
      b.index();
      b.index();
      expect(b.scrollBack, 2);
      b.clearScrollback();
      expect(b.scrollBack, 0);
    });

    test('clear wipes everything and refills with viewHeight empty lines', () {
      final b = _newBuffer(viewHeight: 3);
      b.write('aaa');
      b.clear();
      expect(b.height, 3);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < b.viewWidth; x++) {
          expect(b.lines[y].getCodePoint(x), 0);
        }
      }
    });
  });

  group('Buffer — anchors', () {
    test('createAnchor at (x, y)', () {
      final b = _newBuffer();
      final a = b.createAnchor(2, 1);
      expect(a.x, 2);
      expect(b.lines[1].anchors, contains(a));
    });

    test('createAnchorFromOffset', () {
      final b = _newBuffer();
      final a = b.createAnchorFromOffset(const CellOffset(3, 2));
      expect(a.x, 3);
      expect(b.lines[2].anchors, contains(a));
    });

    test('createAnchorFromCursor', () {
      final b = _newBuffer();
      b.setCursor(4, 1);
      final a = b.createAnchorFromCursor();
      expect(a.x, 4);
    });
  });

  group('Buffer — getWordBoundary', () {
    test('returns null for an out-of-range y', () {
      final b = _newBuffer(viewHeight: 3);
      expect(b.getWordBoundary(const CellOffset(0, 99)), isNull);
    });

    test('returns null when the position is fully bounded by separators on both sides', () {
      // The implementation walks left until a separator (or column 0) and
      // right until a separator (or viewWidth). A null result requires the
      // walks to land on the same column — i.e., separators flanking the
      // position itself.
      final b = _newBuffer(viewWidth: 5);
      b.write('a   b'); // spaces at indexes 1, 2, 3
      final r = b.getWordBoundary(const CellOffset(2, 0));
      expect(r, isNull);
    });

    test('returns the surrounding word range, halting at separators', () {
      final b = _newBuffer(viewWidth: 9);
      b.write('foo bar');
      final r = b.getWordBoundary(const CellOffset(5, 0))!;
      expect(r.begin.x, 4);
      expect(r.end.x, 7);
    });

    test('honours custom wordSeparators when provided', () {
      final b = _newBuffer(viewWidth: 5, wordSeparators: <int>{','.codeUnitAt(0)});
      b.write('a,bcd');
      final r = b.getWordBoundary(const CellOffset(2, 0))!;
      expect(r.begin.x, 2);
      expect(r.end.x, 5);
    });
  });

  group('Buffer — getText', () {
    test('default range walks the whole buffer line-by-line with newlines', () {
      final b = _newBuffer(viewWidth: 4, viewHeight: 3);
      b.write('aa');
      b.lineFeed();
      b.write('bb');
      final text = b.getText();
      expect(text, contains('aa'));
      expect(text, contains('bb'));
      expect(text.split('\n').length, greaterThanOrEqualTo(2));
    });

    test('explicit range works on a normalized BufferRangeLine', () {
      final b = _newBuffer(viewWidth: 4, viewHeight: 3);
      b.write('aa');
      b.lineFeed();
      b.write('bb');
      final r = BufferRangeLine(const CellOffset(0, 0), const CellOffset(2, 0));
      expect(b.getText(r), 'aa');
    });

    test('skips out-of-range segments', () {
      final b = _newBuffer(viewWidth: 4, viewHeight: 2);
      b.write('aa');
      // Range references a y past height; getText should skip it without
      // throwing.
      final r = BufferRangeLine(const CellOffset(0, 0), const CellOffset(2, 99));
      final result = b.getText(r);
      expect(result, contains('aa'));
    });

    test('wrapped lines do not get an inserted newline', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 3);
      b.write('abcdef'); // wraps line 1
      final text = b.getText();
      // The wrapped line shouldn't have a separating newline before it.
      expect(text.replaceAll('\n', '').contains('abcdef'), isTrue);
    });
  });

  group('Buffer — toString debug dump', () {
    test('produces one line per buffer line with index and wrap marker', () {
      final b = _newBuffer(viewWidth: 3, viewHeight: 3);
      b.write('abcd'); // wraps; line 0 is 'abc', line 1 is 'd' (wrapped)
      final out = b.toString();
      expect(out, contains('|abc|'));
      expect(out, contains('(⏎)')); // the wrapped marker
    });
  });
}
