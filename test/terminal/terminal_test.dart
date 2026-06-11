/// Pure-Dart tests for the `Terminal` orchestrator
/// (`lib/src/terminal/src/terminal.dart`). The `Terminal` is the
/// EscapeHandler implementation that wires the parser into a
/// Buffer-backed scrollback, exposes mode flags via TerminalState,
/// and emits user output through the `onOutput` callback. No Flutter
/// dependency.
library;

import 'dart:convert' show utf8;

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/input/keys.dart';
import 'package:clide/src/terminal/src/core/mouse/button.dart';
import 'package:clide/src/terminal/src/core/mouse/button_state.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/core/platform.dart';
import 'package:clide/src/terminal/src/terminal.dart';
import 'package:test/test.dart';

class _Recorder {
  final outputs = <String>[];
  int bellCount = 0;
  String? lastTitle;
  String? lastIcon;
  int? resizeWidth, resizeHeight, resizePixelW, resizePixelH;
  String? lastOscPs;
  List<String>? lastOscArgs;

  Terminal build({int maxLines = 100, TerminalTargetPlatform platform = TerminalTargetPlatform.linux, bool reflow = true}) {
    return Terminal(
      maxLines: maxLines,
      platform: platform,
      reflowEnabled: reflow,
      onOutput: outputs.add,
      onBell: () => bellCount++,
      onTitleChange: (t) => lastTitle = t,
      onIconChange: (i) => lastIcon = i,
      onResize: (w, h, pw, ph) {
        resizeWidth = w;
        resizeHeight = h;
        resizePixelW = pw;
        resizePixelH = ph;
      },
      onPrivateOSC: (ps, args) {
        lastOscPs = ps;
        lastOscArgs = args;
      },
    );
  }
}

void main() {
  group('Terminal — construction + state defaults', () {
    test('default view is 80x24, mainBuffer is active, mode flags zeroed', () {
      final t = _Recorder().build();
      expect(t.viewWidth, 80);
      expect(t.viewHeight, 24);
      expect(t.isUsingAltBuffer, isFalse);
      expect(identical(t.buffer, t.mainBuffer), isTrue);
      expect(t.insertMode, isFalse);
      expect(t.lineFeedMode, isFalse);
      expect(t.cursorKeysMode, isFalse);
      expect(t.reverseDisplayMode, isFalse);
      expect(t.originMode, isFalse);
      expect(t.autoWrapMode, isTrue);
      expect(t.cursorBlinkMode, isFalse);
      expect(t.cursorVisibleMode, isTrue);
      expect(t.appKeypadMode, isFalse);
      expect(t.reportFocusMode, isFalse);
      expect(t.altBufferMouseScrollMode, isFalse);
      expect(t.bracketedPasteMode, isFalse);
      expect(t.mouseMode, MouseMode.none);
      expect(t.mouseReportMode, MouseReportMode.normal);
    });

    test('lines getter returns the active buffer lines', () {
      final t = _Recorder().build();
      expect(t.lines, t.mainBuffer.lines);
    });

    test('toString shape includes hashCode + dimensions + height', () {
      final t = _Recorder().build();
      expect(t.toString(), contains('${t.viewWidth} x ${t.viewHeight}'));
      expect(t.toString(), contains('${t.buffer.height} lines'));
    });
  });

  group('Terminal — Observable mixin', () {
    test('listeners fire on write() and stop firing after removeListener', () {
      final t = _Recorder().build();
      var fired = 0;
      void cb() => fired++;
      t.addListener(cb);
      t.write('hi');
      expect(fired, 1);
      t.removeListener(cb);
      t.write('more');
      expect(fired, 1);
    });

    test('multiple listeners all fire', () {
      final t = _Recorder().build();
      var a = 0;
      var b = 0;
      t.addListener(() => a++);
      t.addListener(() => b++);
      t.write('x');
      expect(a, 1);
      expect(b, 1);
    });
  });

  group('Terminal — write + writeChar', () {
    test('writeChar advances the buffer cursor', () {
      final t = _Recorder().build();
      t.writeChar('a'.codeUnitAt(0));
      expect(t.buffer.cursorX, 1);
      expect(t.buffer.lines[0].getCodePoint(0), 'a'.codeUnitAt(0));
    });

    test('write feeds the escape parser end-to-end', () {
      final t = _Recorder().build();
      t.write('\x1b[31mred'); // SGR red foreground
      expect(t.cursor.foreground, isNot(0)); // foreground was set
    });

    // T-373: byte consumers used to utf8.decode per chunk — a rune split
    // across PTY reads rendered as U+FFFD garbage.
    test('writeBytes joins a multi-byte rune split across two calls', () {
      final t = _Recorder().build();
      final euro = utf8.encode('€'); // 3 bytes: E2 82 AC
      t.writeBytes(euro.sublist(0, 1));
      t.writeBytes(euro.sublist(1));
      expect(t.buffer.lines[0].getCodePoint(0), '€'.codeUnitAt(0));
    });

    test('writeBytes decodes consecutive whole chunks like write', () {
      final t = _Recorder().build();
      t.writeBytes(utf8.encode('héllo'));
      final line = [for (var i = 0; i < 5; i++) t.buffer.lines[0].getCodePoint(i)];
      expect(String.fromCharCodes(line), 'héllo');
    });

    test('writeBytes with an empty chunk is a no-op', () {
      final t = _Recorder().build();
      t.writeBytes(const []);
      expect(t.buffer.cursorX, 0);
    });
  });

  group('Terminal — keyInput', () {
    test('returns true and emits when the input handler produces output', () {
      final r = _Recorder();
      final t = r.build();
      // Up arrow on the default keytab produces a non-empty escape.
      expect(t.keyInput(TerminalKey.arrowUp), isTrue);
      expect(r.outputs, isNotEmpty);
    });

    test('returns false when no handler matches', () {
      final r = _Recorder();
      final t = r.build()..inputHandler = null;
      expect(t.keyInput(TerminalKey.arrowUp), isFalse);
      expect(r.outputs, isEmpty);
    });
  });

  group('Terminal — charInput', () {
    test('Ctrl + a..z → 0x01..0x1A', () {
      final r = _Recorder();
      final t = r.build();
      for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) {
        r.outputs.clear();
        expect(t.charInput(c, ctrl: true), isTrue);
        expect(r.outputs.single, String.fromCharCode(c - 'a'.codeUnitAt(0) + 1));
      }
    });

    test('Ctrl + [ ..._ → 0x1B..0x1F', () {
      final r = _Recorder();
      final t = r.build();
      for (var c = '['.codeUnitAt(0); c <= '_'.codeUnitAt(0); c++) {
        r.outputs.clear();
        expect(t.charInput(c, ctrl: true), isTrue);
        expect(r.outputs.single, String.fromCharCode(c - '['.codeUnitAt(0) + 27));
      }
    });

    test('Alt + a..z (linux) → ESC + uppercase', () {
      final r = _Recorder();
      final t = r.build();
      r.outputs.clear();
      expect(t.charInput('a'.codeUnitAt(0), alt: true), isTrue);
      expect(r.outputs.single, '\x1bA');
    });

    test('Alt on macOS is reserved → returns false (no output)', () {
      final r = _Recorder();
      final t = r.build(platform: TerminalTargetPlatform.macos);
      expect(t.charInput('a'.codeUnitAt(0), alt: true), isFalse);
      expect(r.outputs, isEmpty);
    });

    test('non-letter char with no modifier returns false', () {
      final r = _Recorder();
      final t = r.build();
      expect(t.charInput('1'.codeUnitAt(0)), isFalse);
      expect(r.outputs, isEmpty);
    });
  });

  group('Terminal — textInput / paste', () {
    test('textInput emits the literal string', () {
      final r = _Recorder();
      final t = r.build();
      t.textInput('hello');
      expect(r.outputs.single, 'hello');
    });

    test('paste without bracketed mode behaves like textInput', () {
      final r = _Recorder();
      final t = r.build();
      t.paste('plain');
      expect(r.outputs.single, 'plain');
    });

    test('paste with bracketed mode wraps the text in markers', () {
      final r = _Recorder();
      final t = r.build();
      t.setBracketedPasteMode(true);
      t.paste('bracketed');
      expect(r.outputs.single, '\x1b[200~bracketed\x1b[201~');
    });
  });

  group('Terminal — mouseInput', () {
    test('returns true and emits when the mouse handler produces output', () {
      final r = _Recorder();
      final t = r.build();
      t.setMouseMode(MouseMode.upDownScroll);
      final handled = t.mouseInput(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(1, 1));
      expect(handled, isTrue);
      expect(r.outputs, isNotEmpty);
    });

    test('returns false when mouse is in none mode', () {
      final r = _Recorder();
      final t = r.build();
      // mouseMode is none by default → ClickMouseHandler + UpDownMouseHandler
      // both decline.
      final handled = t.mouseInput(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(0, 0));
      expect(handled, isFalse);
    });

    test('returns false when mouseHandler is null', () {
      final r = _Recorder();
      final t = r.build()..mouseHandler = null;
      final handled = t.mouseInput(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(0, 0));
      expect(handled, isFalse);
    });
  });

  group('Terminal — resize', () {
    test('updates viewWidth/Height, fires onResize, resets margins', () {
      final r = _Recorder();
      final t = r.build();
      t.resize(40, 12, 800, 600);
      expect(t.viewWidth, 40);
      expect(t.viewHeight, 12);
      expect(r.resizeWidth, 40);
      expect(r.resizeHeight, 12);
      expect(r.resizePixelW, 800);
      expect(r.resizePixelH, 600);
      expect(t.mainBuffer.marginTop, 0);
      expect(t.mainBuffer.marginBottom, 11);
    });

    test('clamps newWidth/newHeight to >= 1', () {
      final r = _Recorder();
      final t = r.build();
      t.resize(0, -5);
      expect(t.viewWidth, 1);
      expect(t.viewHeight, 1);
    });

    test('clears scrollback when active buffer is the alt buffer', () {
      final r = _Recorder();
      final t = r.build();
      t.useAltBuffer();
      t.write('a\nb\nc'); // not strictly building scrollback but exercises path
      t.resize(40, 10);
      // alt buffer has at most viewHeight lines after clearScrollback.
      expect(t.altBuffer.height, lessThanOrEqualTo(10));
    });
  });

  group('Terminal — buffer switching', () {
    test('useAltBuffer / useMainBuffer / clearAltBuffer', () {
      final t = _Recorder().build();
      expect(t.isUsingAltBuffer, isFalse);
      t.useAltBuffer();
      expect(t.isUsingAltBuffer, isTrue);
      expect(identical(t.buffer, t.altBuffer), isTrue);
      // Write something to alt buffer, then clear it.
      t.writeChar('x'.codeUnitAt(0));
      t.useMainBuffer();
      expect(t.isUsingAltBuffer, isFalse);
      // Switch back and verify clear works.
      t.useAltBuffer();
      t.clearAltBuffer();
      // Cleared buffer has all-empty cells.
      expect(t.altBuffer.lines[0].getCodePoint(0), 0);
    });
  });

  group('Terminal — SBC handlers', () {
    test('bell fires onBell', () {
      final r = _Recorder();
      final t = r.build();
      t.bell();
      expect(r.bellCount, 1);
    });

    test('backspaceReturn moves cursor back by 1', () {
      final t = _Recorder().build();
      t.buffer.setCursorX(3);
      t.backspaceReturn();
      expect(t.buffer.cursorX, 2);
    });

    test('lineFeed delegates to buffer.lineFeed', () {
      final t = _Recorder().build();
      final yBefore = t.buffer.cursorY;
      t.lineFeed();
      expect(t.buffer.cursorY, yBefore + 1);
    });

    test('carriageReturn resets cursorX to 0', () {
      final t = _Recorder().build();
      t.buffer.setCursorX(5);
      t.carriageReturn();
      expect(t.buffer.cursorX, 0);
    });

    test('shiftOut / shiftIn switch the active charset slot', () {
      final t = _Recorder().build();
      t.shiftOut();
      // No exception, no observable side-effect from outside.
      t.shiftIn();
    });

    test('unknownSBC and unkownEscape are no-ops', () {
      final t = _Recorder().build();
      // Just ensure they don't throw.
      t.unknownSBC(0xFF);
      t.unkownEscape(0xFF);
    });
  });

  group('Terminal — tab stops', () {
    test('tab jumps to the next 8-column stop', () {
      final t = _Recorder().build();
      t.buffer.setCursorX(0);
      t.tab();
      expect(t.buffer.cursorX, 8);
    });

    test('tab past the last stop saturates the cursor at viewWidth', () {
      final t = _Recorder().build();
      t.clearAllTabStops(); // remove every stop
      t.buffer.setCursorX(70);
      t.tab();
      // cursor saturated at viewWidth (80); the public getter clamps to 79.
      expect(t.buffer.cursorX, 79);
    });

    test('clearTabStopUnderCursor / clearAllTabStops mutate the table', () {
      final t = _Recorder().build();
      t.buffer.setCursorX(8);
      t.clearTabStopUnderCursor();
      // Subsequent tab from 0 must skip the cleared 8 stop.
      t.buffer.setCursorX(0);
      t.tab();
      expect(t.buffer.cursorX, 16);

      t.clearAllTabStops();
      t.buffer.setCursorX(0);
      t.tab();
      expect(t.buffer.cursorX, 79); // saturated
    });

    test('setTapStop is a query, not a write — does not throw', () {
      final t = _Recorder().build();
      t.buffer.setCursorX(5);
      t.setTapStop();
    });
  });

  group('Terminal — ANSI escape handlers', () {
    test('saveCursor / restoreCursor round-trip through buffer', () {
      final t = _Recorder().build();
      t.buffer.setCursor(3, 2);
      t.saveCursor();
      t.buffer.setCursor(0, 0);
      t.restoreCursor();
      expect(t.buffer.cursorX, 3);
      expect(t.buffer.cursorY, 2);
    });

    test('index moves the cursor down one line', () {
      final t = _Recorder().build();
      t.buffer.setCursorY(1);
      t.index();
      expect(t.buffer.cursorY, 2);
    });

    test('nextLine moves down + resets x to 0', () {
      final t = _Recorder().build();
      t.buffer.setCursor(5, 1);
      t.nextLine();
      expect(t.buffer.cursorX, 0);
    });

    test('reverseIndex moves the cursor up one line (inside margins)', () {
      final t = _Recorder().build();
      t.buffer.setCursorY(3);
      t.reverseIndex();
      expect(t.buffer.cursorY, 2);
    });

    test('designateCharset routes to buffer.charset.designate', () {
      final t = _Recorder().build();
      t.designateCharset(0, '0'.codeUnitAt(0)); // DEC special graphics
      // After use(0), the next char goes through the DEC graphics translator.
      // Verify by checking the translator picks up the mapping (test-side).
      t.buffer.charset.use(0);
      expect(t.buffer.charset.translate(0x6a), 0x2518);
    });
  });

  group('Terminal — CSI handlers', () {
    test('cursor motion delegates to buffer (setCursor / setCursorX/Y, moveCursorX/Y)', () {
      final t = _Recorder().build();
      t.setCursor(3, 5);
      expect(t.buffer.cursorX, 3);
      expect(t.buffer.cursorY, 5);
      t.setCursorX(7);
      expect(t.buffer.cursorX, 7);
      t.setCursorY(2);
      expect(t.buffer.cursorY, 2);
      t.moveCursorX(2);
      expect(t.buffer.cursorX, 9);
      t.moveCursorY(1);
      expect(t.buffer.cursorY, 3);
    });

    test('cursorNextLine / cursorPrecedingLine move y + reset x', () {
      final t = _Recorder().build();
      t.buffer.setCursor(5, 2);
      t.cursorNextLine(2);
      expect(t.buffer.cursorY, 4);
      expect(t.buffer.cursorX, 0);

      t.buffer.setCursor(5, 5);
      t.cursorPrecedingLine(2);
      expect(t.buffer.cursorY, 3);
      expect(t.buffer.cursorX, 0);
    });

    test('setMargins forwards to buffer', () {
      final t = _Recorder().build();
      t.setMargins(2, 5);
      expect(t.buffer.marginTop, 2);
      expect(t.buffer.marginBottom, 5);
      // null bottom defaults to viewHeight - 1.
      t.setMargins(0);
      expect(t.buffer.marginBottom, t.viewHeight - 1);
    });

    test('erase commands forward to buffer.erase*', () {
      // Helper that fills line 0 with 'abcde' from column 0 deterministically.
      Terminal fresh() {
        final t = _Recorder().build();
        t.buffer.setCursor(0, 0);
        t.write('abcde');
        t.buffer.setCursor(0, 0);
        return t;
      }

      // eraseLine wipes the whole line.
      var t = fresh();
      t.eraseLine();
      expect(t.buffer.lines[0].getCodePoint(0), 0);
      expect(t.buffer.lines[0].getCodePoint(4), 0);

      // eraseLineRight from column 2 keeps 0..1, wipes 2..end.
      t = fresh();
      t.buffer.setCursorX(2);
      t.eraseLineRight();
      expect(t.buffer.lines[0].getCodePoint(0), 'a'.codeUnitAt(0));
      expect(t.buffer.lines[0].getCodePoint(2), 0);

      // eraseLineLeft from column 2 wipes 0..1, keeps 2..end.
      t = fresh();
      t.buffer.setCursorX(2);
      t.eraseLineLeft();
      expect(t.buffer.lines[0].getCodePoint(0), 0);
      expect(t.buffer.lines[0].getCodePoint(2), 'c'.codeUnitAt(0));

      // eraseDisplay wipes everything.
      t = fresh();
      t.eraseDisplay();
      expect(t.buffer.lines[0].getCodePoint(0), 0);

      // eraseDisplayBelow from column 2 keeps 0..1, wipes the rest.
      t = fresh();
      t.buffer.setCursor(2, 0);
      t.eraseDisplayBelow();
      expect(t.buffer.lines[0].getCodePoint(0), 'a'.codeUnitAt(0));
      expect(t.buffer.lines[0].getCodePoint(2), 0);

      // eraseDisplayAbove + eraseScrollbackOnly — exercise without throw.
      t = fresh();
      t.buffer.setCursor(0, 0);
      t.eraseDisplayAbove();
      t.eraseScrollbackOnly();
    });

    test('insertLines / deleteLines / deleteChars / scrollUp / scrollDown / eraseChars / insertBlankChars — delegates', () {
      final t = _Recorder().build();
      // Just ensure none throw and each side-effect is observable somewhere.
      t.setMargins(0, 5);
      t.buffer.setCursorY(2);
      t.insertLines(1);
      t.deleteLines(1);
      t.write('abc');
      t.buffer.setCursorX(1);
      t.deleteChars(1);
      t.scrollUp(1);
      t.scrollDown(1);
      t.eraseChars(1);
      t.insertBlankChars(1);
    });

    test('repeatPreviousCharacter writes the last codepoint N times', () {
      final t = _Recorder().build();
      t.writeChar('z'.codeUnitAt(0));
      final xBefore = t.buffer.cursorX;
      t.repeatPreviousCharacter(3);
      expect(t.buffer.cursorX, xBefore + 3);
    });

    test('repeatPreviousCharacter is a no-op with no preceding codepoint', () {
      final t = _Recorder().build();
      final xBefore = t.buffer.cursorX;
      t.repeatPreviousCharacter(3);
      expect(t.buffer.cursorX, xBefore);
    });

    test('unknownCSI / setUnknownMode / setUnknownDecMode / setColumnMode / unsupportedStyle — no-ops, no throw', () {
      final t = _Recorder().build();
      t.unknownCSI('Z'.codeUnitAt(0));
      t.setUnknownMode(99, true);
      t.setUnknownDecMode(9999, true);
      t.setColumnMode(true);
      t.unsupportedStyle(123);
    });
  });

  group('Terminal — device-attribute reports', () {
    test('every device-attribute / status report hits onOutput', () {
      final r = _Recorder();
      final t = r.build();
      t.sendPrimaryDeviceAttributes();
      t.sendSecondaryDeviceAttributes();
      t.sendTertiaryDeviceAttributes();
      t.sendOperatingStatus();
      t.sendCursorPosition();
      t.sendSize();
      expect(r.outputs.length, 6);
      expect(r.outputs[0], '\x1b[?1;2c');
      expect(r.outputs[3], '\x1b[0n');
    });
  });

  group('Terminal — mode setters', () {
    test('every mode setter mirrors into its getter', () {
      final t = _Recorder().build();
      t.setInsertMode(true);
      expect(t.insertMode, isTrue);
      t.setLineFeedMode(true);
      expect(t.lineFeedMode, isTrue);
      t.setCursorKeysMode(true);
      expect(t.cursorKeysMode, isTrue);
      t.setReverseDisplayMode(true);
      expect(t.reverseDisplayMode, isTrue);
      t.setOriginMode(true);
      expect(t.originMode, isTrue);
      t.setAutoWrapMode(false);
      expect(t.autoWrapMode, isFalse);
      t.setMouseMode(MouseMode.upDownScroll);
      expect(t.mouseMode, MouseMode.upDownScroll);
      t.setCursorBlinkMode(true);
      expect(t.cursorBlinkMode, isTrue);
      t.setCursorVisibleMode(false);
      expect(t.cursorVisibleMode, isFalse);
      t.setAppKeypadMode(true);
      expect(t.appKeypadMode, isTrue);
      t.setReportFocusMode(true);
      expect(t.reportFocusMode, isTrue);
      t.setMouseReportMode(MouseReportMode.sgr);
      expect(t.mouseReportMode, MouseReportMode.sgr);
      t.setAltBufferMouseScrollMode(true);
      expect(t.altBufferMouseScrollMode, isTrue);
      t.setBracketedPasteMode(true);
      expect(t.bracketedPasteMode, isTrue);
    });
  });

  group('Terminal — SGR forwarding', () {
    test('every set/unset attr toggles the cursor flag', () {
      final t = _Recorder().build();
      t.setCursorBold();
      expect(t.cursor.isBold, isTrue);
      t.setCursorFaint();
      expect(t.cursor.isFaint, isTrue);
      t.setCursorItalic();
      expect(t.cursor.isItalic, isTrue);
      t.setCursorUnderline();
      expect(t.cursor.isUnderline, isTrue);
      t.setCursorBlink();
      expect(t.cursor.isBlink, isTrue);
      t.setCursorInverse();
      expect(t.cursor.isInverse, isTrue);
      t.setCursorInvisible();
      expect(t.cursor.isInvisible, isTrue);
      t.setCursorStrikethrough();

      // Unset each in turn and check the matching getter goes back to false
      // (where one is exposed).
      t.unsetCursorBold();
      expect(t.cursor.isBold, isFalse);
      t.unsetCursorFaint();
      expect(t.cursor.isFaint, isFalse);
      t.unsetCursorItalic();
      expect(t.cursor.isItalic, isFalse);
      t.unsetCursorUnderline();
      expect(t.cursor.isUnderline, isFalse);
      t.unsetCursorBlink();
      expect(t.cursor.isBlink, isFalse);
      t.unsetCursorInverse();
      expect(t.cursor.isInverse, isFalse);
      t.unsetCursorInvisible();
      expect(t.cursor.isInvisible, isFalse);
      t.unsetCursorStrikethrough(); // no getter, just exercise
    });

    test('foreground / background colour setters + reset', () {
      final t = _Recorder().build();
      t.setForegroundColor16(2);
      t.setForegroundColor256(123);
      t.setForegroundColorRgb(10, 20, 30);
      t.resetForeground();
      expect(t.cursor.foreground, 0);

      t.setBackgroundColor16(4);
      t.setBackgroundColor256(99);
      t.setBackgroundColorRgb(1, 2, 3);
      t.resetBackground();
      expect(t.cursor.background, 0);
    });

    test('resetCursorStyle wipes attrs + foreground + background', () {
      final t = _Recorder().build();
      t.setCursorBold();
      t.setForegroundColor16(2);
      t.setBackgroundColor16(4);
      t.resetCursorStyle();
      expect(t.cursor.attrs, 0);
      expect(t.cursor.foreground, 0);
      expect(t.cursor.background, 0);
    });
  });

  group('Terminal — OSC handlers', () {
    test('setTitle fires onTitleChange with the supplied name', () {
      final r = _Recorder();
      final t = r.build();
      t.setTitle('hello world');
      expect(r.lastTitle, 'hello world');
    });

    test('setIconName fires onIconChange', () {
      final r = _Recorder();
      final t = r.build();
      t.setIconName('icon-id');
      expect(r.lastIcon, 'icon-id');
    });

    test('unknownOSC routes to onPrivateOSC', () {
      final r = _Recorder();
      final t = r.build();
      t.unknownOSC('99', ['arg1', 'arg2']);
      expect(r.lastOscPs, '99');
      expect(r.lastOscArgs, ['arg1', 'arg2']);
    });
  });
}
