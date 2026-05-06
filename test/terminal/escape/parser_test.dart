/// Pure-Dart tests for EscapeParser + EscapeEmitter.
///
/// Drives a recording EscapeHandler through every reachable dispatch
/// path in the parser: SBC controls, ESC escapes, CSI sequences (with
/// and without params, with and without prefixes), SGR styling
/// (incl. 256-colour and 24-bit RGB), DEC private modes, OSC, window
/// manipulation, and incomplete-sequence rollback.
library;

import 'package:clide/src/terminal/src/core/escape/emitter.dart';
import 'package:clide/src/terminal/src/core/escape/handler.dart';
import 'package:clide/src/terminal/src/core/escape/parser.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:test/test.dart';

class _Call {
  const _Call(this.name, this.args);
  final String name;
  final List<Object?> args;
  @override
  String toString() => '$name(${args.join(", ")})';
}

class _RecordingHandler implements EscapeHandler {
  final calls = <_Call>[];

  void clear() => calls.clear();
  Iterable<_Call> named(String n) => calls.where((c) => c.name == n);
  _Call lastCallNamed(String n) => named(n).last;

  @override
  void writeChar(int char) => calls.add(_Call("writeChar", [char]));
  @override
  void bell() => calls.add(_Call("bell", const []));
  @override
  void backspaceReturn() => calls.add(_Call("backspaceReturn", const []));
  @override
  void tab() => calls.add(_Call("tab", const []));
  @override
  void lineFeed() => calls.add(_Call("lineFeed", const []));
  @override
  void carriageReturn() => calls.add(_Call("carriageReturn", const []));
  @override
  void shiftOut() => calls.add(_Call("shiftOut", const []));
  @override
  void shiftIn() => calls.add(_Call("shiftIn", const []));
  @override
  void unknownSBC(int char) => calls.add(_Call("unknownSBC", [char]));
  @override
  void saveCursor() => calls.add(_Call("saveCursor", const []));
  @override
  void restoreCursor() => calls.add(_Call("restoreCursor", const []));
  @override
  void index() => calls.add(_Call("index", const []));
  @override
  void nextLine() => calls.add(_Call("nextLine", const []));
  @override
  void setTapStop() => calls.add(_Call("setTapStop", const []));
  @override
  void reverseIndex() => calls.add(_Call("reverseIndex", const []));
  @override
  void designateCharset(int charset, int name) => calls.add(_Call("designateCharset", [charset, name]));
  @override
  void unkownEscape(int char) => calls.add(_Call("unkownEscape", [char]));
  @override
  void repeatPreviousCharacter(int n) => calls.add(_Call("repeatPreviousCharacter", [n]));
  @override
  void setCursor(int x, int y) => calls.add(_Call("setCursor", [x, y]));
  @override
  void setCursorX(int x) => calls.add(_Call("setCursorX", [x]));
  @override
  void setCursorY(int y) => calls.add(_Call("setCursorY", [y]));
  @override
  void sendPrimaryDeviceAttributes() => calls.add(_Call("sendPrimaryDeviceAttributes", const []));
  @override
  void clearTabStopUnderCursor() => calls.add(_Call("clearTabStopUnderCursor", const []));
  @override
  void clearAllTabStops() => calls.add(_Call("clearAllTabStops", const []));
  @override
  void moveCursorX(int offset) => calls.add(_Call("moveCursorX", [offset]));
  @override
  void moveCursorY(int n) => calls.add(_Call("moveCursorY", [n]));
  @override
  void sendSecondaryDeviceAttributes() => calls.add(_Call("sendSecondaryDeviceAttributes", const []));
  @override
  void sendTertiaryDeviceAttributes() => calls.add(_Call("sendTertiaryDeviceAttributes", const []));
  @override
  void sendOperatingStatus() => calls.add(_Call("sendOperatingStatus", const []));
  @override
  void sendCursorPosition() => calls.add(_Call("sendCursorPosition", const []));
  @override
  void setMargins(int i, [int? bottom]) => calls.add(_Call("setMargins", [i, bottom]));
  @override
  void cursorNextLine(int amount) => calls.add(_Call("cursorNextLine", [amount]));
  @override
  void cursorPrecedingLine(int amount) => calls.add(_Call("cursorPrecedingLine", [amount]));
  @override
  void eraseDisplayBelow() => calls.add(_Call("eraseDisplayBelow", const []));
  @override
  void eraseDisplayAbove() => calls.add(_Call("eraseDisplayAbove", const []));
  @override
  void eraseDisplay() => calls.add(_Call("eraseDisplay", const []));
  @override
  void eraseScrollbackOnly() => calls.add(_Call("eraseScrollbackOnly", const []));
  @override
  void eraseLineRight() => calls.add(_Call("eraseLineRight", const []));
  @override
  void eraseLineLeft() => calls.add(_Call("eraseLineLeft", const []));
  @override
  void eraseLine() => calls.add(_Call("eraseLine", const []));
  @override
  void insertLines(int amount) => calls.add(_Call("insertLines", [amount]));
  @override
  void deleteLines(int amount) => calls.add(_Call("deleteLines", [amount]));
  @override
  void deleteChars(int amount) => calls.add(_Call("deleteChars", [amount]));
  @override
  void scrollUp(int amount) => calls.add(_Call("scrollUp", [amount]));
  @override
  void scrollDown(int amount) => calls.add(_Call("scrollDown", [amount]));
  @override
  void eraseChars(int amount) => calls.add(_Call("eraseChars", [amount]));
  @override
  void insertBlankChars(int amount) => calls.add(_Call("insertBlankChars", [amount]));
  @override
  void unknownCSI(int finalByte) => calls.add(_Call("unknownCSI", [finalByte]));
  @override
  void setInsertMode(bool enabled) => calls.add(_Call("setInsertMode", [enabled]));
  @override
  void setLineFeedMode(bool enabled) => calls.add(_Call("setLineFeedMode", [enabled]));
  @override
  void setUnknownMode(int mode, bool enabled) => calls.add(_Call("setUnknownMode", [mode, enabled]));
  @override
  void setCursorKeysMode(bool enabled) => calls.add(_Call("setCursorKeysMode", [enabled]));
  @override
  void setReverseDisplayMode(bool enabled) => calls.add(_Call("setReverseDisplayMode", [enabled]));
  @override
  void setOriginMode(bool enabled) => calls.add(_Call("setOriginMode", [enabled]));
  @override
  void setColumnMode(bool enabled) => calls.add(_Call("setColumnMode", [enabled]));
  @override
  void setAutoWrapMode(bool enabled) => calls.add(_Call("setAutoWrapMode", [enabled]));
  @override
  void setMouseMode(MouseMode mode) => calls.add(_Call("setMouseMode", [mode]));
  @override
  void setCursorBlinkMode(bool enabled) => calls.add(_Call("setCursorBlinkMode", [enabled]));
  @override
  void setCursorVisibleMode(bool enabled) => calls.add(_Call("setCursorVisibleMode", [enabled]));
  @override
  void useAltBuffer() => calls.add(_Call("useAltBuffer", const []));
  @override
  void useMainBuffer() => calls.add(_Call("useMainBuffer", const []));
  @override
  void clearAltBuffer() => calls.add(_Call("clearAltBuffer", const []));
  @override
  void setAppKeypadMode(bool enabled) => calls.add(_Call("setAppKeypadMode", [enabled]));
  @override
  void setReportFocusMode(bool enabled) => calls.add(_Call("setReportFocusMode", [enabled]));
  @override
  void setMouseReportMode(MouseReportMode mode) => calls.add(_Call("setMouseReportMode", [mode]));
  @override
  void setAltBufferMouseScrollMode(bool enabled) => calls.add(_Call("setAltBufferMouseScrollMode", [enabled]));
  @override
  void setBracketedPasteMode(bool enabled) => calls.add(_Call("setBracketedPasteMode", [enabled]));
  @override
  void setUnknownDecMode(int mode, bool enabled) => calls.add(_Call("setUnknownDecMode", [mode, enabled]));
  @override
  void resize(int cols, int rows) => calls.add(_Call("resize", [cols, rows]));
  @override
  void sendSize() => calls.add(_Call("sendSize", const []));
  @override
  void resetCursorStyle() => calls.add(_Call("resetCursorStyle", const []));
  @override
  void setCursorBold() => calls.add(_Call("setCursorBold", const []));
  @override
  void setCursorFaint() => calls.add(_Call("setCursorFaint", const []));
  @override
  void setCursorItalic() => calls.add(_Call("setCursorItalic", const []));
  @override
  void setCursorUnderline() => calls.add(_Call("setCursorUnderline", const []));
  @override
  void setCursorBlink() => calls.add(_Call("setCursorBlink", const []));
  @override
  void setCursorInverse() => calls.add(_Call("setCursorInverse", const []));
  @override
  void setCursorInvisible() => calls.add(_Call("setCursorInvisible", const []));
  @override
  void setCursorStrikethrough() => calls.add(_Call("setCursorStrikethrough", const []));
  @override
  void unsetCursorBold() => calls.add(_Call("unsetCursorBold", const []));
  @override
  void unsetCursorFaint() => calls.add(_Call("unsetCursorFaint", const []));
  @override
  void unsetCursorItalic() => calls.add(_Call("unsetCursorItalic", const []));
  @override
  void unsetCursorUnderline() => calls.add(_Call("unsetCursorUnderline", const []));
  @override
  void unsetCursorBlink() => calls.add(_Call("unsetCursorBlink", const []));
  @override
  void unsetCursorInverse() => calls.add(_Call("unsetCursorInverse", const []));
  @override
  void unsetCursorInvisible() => calls.add(_Call("unsetCursorInvisible", const []));
  @override
  void unsetCursorStrikethrough() => calls.add(_Call("unsetCursorStrikethrough", const []));
  @override
  void setForegroundColor16(int color) => calls.add(_Call("setForegroundColor16", [color]));
  @override
  void setForegroundColor256(int index) => calls.add(_Call("setForegroundColor256", [index]));
  @override
  void setForegroundColorRgb(int r, int g, int b) => calls.add(_Call("setForegroundColorRgb", [r, g, b]));
  @override
  void resetForeground() => calls.add(_Call("resetForeground", const []));
  @override
  void setBackgroundColor16(int color) => calls.add(_Call("setBackgroundColor16", [color]));
  @override
  void setBackgroundColor256(int index) => calls.add(_Call("setBackgroundColor256", [index]));
  @override
  void setBackgroundColorRgb(int r, int g, int b) => calls.add(_Call("setBackgroundColorRgb", [r, g, b]));
  @override
  void resetBackground() => calls.add(_Call("resetBackground", const []));
  @override
  void unsupportedStyle(int param) => calls.add(_Call("unsupportedStyle", [param]));
  @override
  void setTitle(String name) => calls.add(_Call("setTitle", [name]));
  @override
  void setIconName(String name) => calls.add(_Call("setIconName", [name]));
  @override
  void unknownOSC(String code, List<String> args) => calls.add(_Call("unknownOSC", [code, args]));
}

({EscapeParser parser, _RecordingHandler h}) _newParser() {
  final h = _RecordingHandler();
  return (parser: EscapeParser(h), h: h);
}

void main() {
  group('EscapeParser — plain characters', () {
    test('writes printable chars one-by-one to writeChar', () {
      final f = _newParser();
      f.parser.write('Hi!');
      expect(
        f.h.calls.map((c) => c.name).toList(),
        ['writeChar', 'writeChar', 'writeChar'],
      );
      expect(f.h.calls.map((c) => c.args.first).toList(), [
        'H'.codeUnitAt(0),
        'i'.codeUnitAt(0),
        '!'.codeUnitAt(0),
      ]);
    });

    test('chars beyond the SBC table go straight to writeChar', () {
      // Codepoint above the lookup table maxIndex falls through to the
      // explicit writeChar path.
      final f = _newParser();
      f.parser.write('中');
      expect(f.h.calls.single.name, 'writeChar');
      expect(f.h.calls.single.args.single, '中'.runes.first);
    });

    test('low-byte char with no SBC entry calls unkownEscape', () {
      // 0x06 is below maxIndex but has no entry — parser routes it to
      // unkownEscape (note the typo in handler.dart).
      final f = _newParser();
      f.parser.write(String.fromCharCode(0x06));
      expect(f.h.calls.single.name, 'unkownEscape');
    });
  });

  group('EscapeParser — single-byte controls', () {
    test('BEL, BS, HT, LF, VT, FF, CR, SO, SI', () {
      final f = _newParser();
      f.parser.write('\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'bell',
        'backspaceReturn',
        'tab',
        'lineFeed', // LF
        'lineFeed', // VT shares LF
        'lineFeed', // FF shares LF
        'carriageReturn',
        'shiftOut',
        'shiftIn',
      ]);
    });
  });

  group('EscapeParser — ESC sequences', () {
    test('ESC 7 / ESC 8 → save / restore cursor', () {
      final f = _newParser();
      f.parser.write('\x1b7\x1b8');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'saveCursor',
        'restoreCursor',
      ]);
    });

    test('ESC D / E / H / M', () {
      final f = _newParser();
      f.parser.write('\x1bD\x1bE\x1bH\x1bM');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'index',
        'nextLine',
        'setTapStop',
        'reverseIndex',
      ]);
    });

    test('ESC ( / ESC ) designate G0 / G1 charset', () {
      final f = _newParser();
      f.parser.write('\x1b(B\x1b)0');
      expect(f.h.calls.length, 2);
      expect(f.h.calls[0].name, 'designateCharset');
      expect(f.h.calls[0].args, [0, 'B'.codeUnitAt(0)]);
      expect(f.h.calls[1].name, 'designateCharset');
      expect(f.h.calls[1].args, [1, '0'.codeUnitAt(0)]);
    });

    test('ESC = / ESC > toggle application keypad mode (DECKPAM/DECKPNM)', () {
      final f = _newParser();
      // ESC = enables app keypad mode, ESC > disables it.
      f.parser.write('\x1b=\x1b>');
      expect(
        f.h.named('setAppKeypadMode').map((c) => c.args.first).toList(),
        [true, false],
      );
    });

    test('unknown ESC byte → unkownEscape', () {
      final f = _newParser();
      f.parser.write('\x1bZ'); // Z has no handler
      expect(f.h.calls.single.name, 'unkownEscape');
      expect(f.h.calls.single.args.single, 'Z'.codeUnitAt(0));
    });

    test('ESC alone is held back until the next chunk completes it', () {
      final f = _newParser();
      f.parser.write('\x1b');
      expect(f.h.calls, isEmpty); // nothing dispatched yet
      f.parser.write('D'); // now ESC D = index
      expect(f.h.calls.single.name, 'index');
    });

    test('ESC ( without a charset name is held back', () {
      final f = _newParser();
      f.parser.write('\x1b(');
      expect(f.h.calls, isEmpty);
      f.parser.write('B');
      expect(f.h.calls.single.name, 'designateCharset');
    });
  });

  group('EscapeParser — CSI cursor movement', () {
    test('A / B / C / D — default amount = 1, missing param uses default', () {
      final f = _newParser();
      f.parser.write('\x1b[A\x1b[B\x1b[C\x1b[D');
      expect(f.h.calls.map((c) => '${c.name}/${c.args}').toList(), [
        'moveCursorY/[-1]',
        'moveCursorY/[1]',
        'moveCursorX/[1]',
        'moveCursorX/[-1]',
      ]);
    });

    test('A / B / C / D — explicit amount + 0-as-1 fallback', () {
      // A negates (cursor up), B/D pass through, C also passes through.
      final f = _newParser();
      f.parser.write('\x1b[3A'); // up 3 → moveCursorY(-3)
      expect(f.h.lastCallNamed('moveCursorY').args, [-3]);
      f.h.clear();
      f.parser.write('\x1b[0B'); // 0 falls back to 1 → moveCursorY(1)
      expect(f.h.lastCallNamed('moveCursorY').args, [1]);
    });

    test('E / F — cursor next/preceding line', () {
      final f = _newParser();
      f.parser.write('\x1b[2E\x1b[F');
      expect(f.h.named('cursorNextLine').first.args, [2]);
      expect(f.h.named('cursorPrecedingLine').first.args, [1]);
    });

    test('G — cursor horizontal absolute (1-based to 0-based)', () {
      final f = _newParser();
      f.parser.write('\x1b[5G');
      expect(f.h.lastCallNamed('setCursorX').args, [4]); // 5-1
    });

    test('H / f — cursor position with both row and column', () {
      final f = _newParser();
      f.parser.write('\x1b[3;7H\x1b[2;4f');
      expect(f.h.named('setCursor').first.args, [6, 2]); // (col-1, row-1)
      expect(f.h.named('setCursor').last.args, [3, 1]);
    });

    test('H — no params resets to (0, 0)', () {
      final f = _newParser();
      f.parser.write('\x1b[H');
      expect(f.h.lastCallNamed('setCursor').args, [0, 0]);
    });

    test('d — line position absolute (1-based)', () {
      final f = _newParser();
      f.parser.write('\x1b[3d');
      expect(f.h.lastCallNamed('setCursorY').args, [2]);
      f.h.clear();
      f.parser.write('\x1b[d'); // default = 1 → 0-based 0
      expect(f.h.lastCallNamed('setCursorY').args, [0]);
    });
  });

  group('EscapeParser — CSI erase / scroll / lines / chars', () {
    test('J 0/1/2/3 → erase display below/above/all/scrollback', () {
      final f = _newParser();
      f.parser.write('\x1b[J\x1b[1J\x1b[2J\x1b[3J');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'eraseDisplayBelow',
        'eraseDisplayAbove',
        'eraseDisplay',
        'eraseScrollbackOnly',
      ]);
    });

    test('K 0/1/2 → erase line right / left / all', () {
      final f = _newParser();
      f.parser.write('\x1b[K\x1b[1K\x1b[2K');
      expect(f.h.calls.map((c) => c.name).toList(), ['eraseLineRight', 'eraseLineLeft', 'eraseLine']);
    });

    test('L / M — insert / delete lines', () {
      final f = _newParser();
      f.parser.write('\x1b[L\x1b[3M');
      expect(f.h.named('insertLines').first.args, [1]);
      expect(f.h.named('deleteLines').first.args, [3]);
    });

    test('P — delete chars; @ — insert blanks; X — erase chars', () {
      final f = _newParser();
      f.parser.write('\x1b[2P\x1b[3@\x1b[4X');
      expect(f.h.named('deleteChars').first.args, [2]);
      expect(f.h.named('insertBlankChars').first.args, [3]);
      expect(f.h.named('eraseChars').first.args, [4]);
    });

    test('S / T — scroll up / down', () {
      final f = _newParser();
      f.parser.write('\x1b[2S\x1b[3T');
      expect(f.h.named('scrollUp').first.args, [2]);
      expect(f.h.named('scrollDown').first.args, [3]);
    });

    test('b — repeat previous character', () {
      final f = _newParser();
      f.parser.write('\x1b[3b');
      expect(f.h.lastCallNamed('repeatPreviousCharacter').args, [3]);
      f.h.clear();
      f.parser.write('\x1b[0b'); // 0 falls back to 1
      expect(f.h.lastCallNamed('repeatPreviousCharacter').args, [1]);
      f.h.clear();
      f.parser.write('\x1b[b'); // empty defaults to 1
      expect(f.h.lastCallNamed('repeatPreviousCharacter').args, [1]);
    });

    test('g — clear tab stop (default 0 → under cursor; non-zero → all)', () {
      final f = _newParser();
      f.parser.write('\x1b[g\x1b[3g');
      expect(f.h.calls.map((c) => c.name).toList(), ['clearTabStopUnderCursor', 'clearAllTabStops']);
    });

    test('r — set top/bottom margins; default top, no bottom', () {
      final f = _newParser();
      f.parser.write('\x1b[3;10r');
      expect(f.h.named('setMargins').last.args, [2, 9]); // (top-1, bottom-1)
      f.h.clear();
      f.parser.write('\x1b[r'); // no params → top=1, bottom=null
      expect(f.h.named('setMargins').last.args, [0, null]);
      f.h.clear();
      f.parser.write('\x1b[1;2;3r'); // too many params → no-op
      expect(f.h.named('setMargins'), isEmpty);
    });
  });

  group('EscapeParser — CSI device attributes / status reports', () {
    test('c / >c / =c — primary, secondary, tertiary device attributes', () {
      final f = _newParser();
      f.parser.write('\x1b[c\x1b[>c\x1b[=c');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'sendPrimaryDeviceAttributes',
        'sendSecondaryDeviceAttributes',
        'sendTertiaryDeviceAttributes',
      ]);
    });

    test('n 5 → operating status; n 6 → cursor position', () {
      final f = _newParser();
      f.parser.write('\x1b[5n\x1b[6n');
      expect(f.h.calls.map((c) => c.name).toList(), ['sendOperatingStatus', 'sendCursorPosition']);
    });

    test('n with no params is a no-op (defensive)', () {
      final f = _newParser();
      f.parser.write('\x1b[n');
      expect(f.h.calls, isEmpty);
    });
  });

  group('EscapeParser — CSI window manipulation', () {
    test('CSI 8 ; rows ; cols t → resize(cols, rows)', () {
      final f = _newParser();
      f.parser.write('\x1b[8;24;80t');
      expect(f.h.lastCallNamed('resize').args, [80, 24]);
    });

    test('CSI 18 t → sendSize', () {
      final f = _newParser();
      f.parser.write('\x1b[18t');
      expect(f.h.calls.single.name, 'sendSize');
    });

    test('CSI ignored window ops (no params, no-scope codes) emit nothing', () {
      final f = _newParser();
      f.parser.write('\x1b[t\x1b[1t\x1b[5t\x1b[9t\x1b[19t\x1b[22t\x1b[99t');
      expect(f.h.calls, isEmpty);
    });

    test('CSI 8 t with wrong number of params is a no-op', () {
      final f = _newParser();
      f.parser.write('\x1b[8t');
      expect(f.h.calls, isEmpty);
    });
  });

  group('EscapeParser — CSI mode set / reset', () {
    test('CSI [4]h / l → setInsertMode true/false', () {
      final f = _newParser();
      f.parser.write('\x1b[4h\x1b[4l');
      expect(f.h.named('setInsertMode').map((c) => c.args.first).toList(), [true, false]);
    });

    test('CSI [20]h → setLineFeedMode', () {
      final f = _newParser();
      f.parser.write('\x1b[20h');
      expect(f.h.named('setLineFeedMode').first.args, [true]);
    });

    test('CSI unknown mode → setUnknownMode(mode, enabled)', () {
      final f = _newParser();
      f.parser.write('\x1b[99h\x1b[99l');
      expect(f.h.named('setUnknownMode').map((c) => c.args).toList(), [
        [99, true],
        [99, false],
      ]);
    });

    test('CSI ?1 / ?7 / ?25 / ?2004 — DEC modes route correctly', () {
      final f = _newParser();
      f.parser.write('\x1b[?1h\x1b[?7l\x1b[?25h\x1b[?2004l');
      expect(f.h.named('setCursorKeysMode').first.args, [true]);
      expect(f.h.named('setAutoWrapMode').first.args, [false]);
      expect(f.h.named('setCursorVisibleMode').first.args, [true]);
      expect(f.h.named('setBracketedPasteMode').first.args, [false]);
    });

    test('CSI ?47 — alt buffer toggle', () {
      final f = _newParser();
      f.parser.write('\x1b[?47h\x1b[?47l');
      expect(f.h.named('useAltBuffer').length, 1);
      expect(f.h.named('useMainBuffer').length, 1);
    });

    test('CSI ?1047 — alt buffer + clear on disable', () {
      final f = _newParser();
      f.parser.write('\x1b[?1047h\x1b[?1047l');
      expect(f.h.named('useAltBuffer').length, 1);
      expect(f.h.named('clearAltBuffer').length, 1);
      expect(f.h.named('useMainBuffer').length, 1);
    });

    test('CSI ?1048 — save / restore cursor', () {
      final f = _newParser();
      f.parser.write('\x1b[?1048h\x1b[?1048l');
      expect(f.h.named('saveCursor').length, 1);
      expect(f.h.named('restoreCursor').length, 1);
    });

    test('CSI ?1049 — save+clear+alt on enable; main on disable', () {
      final f = _newParser();
      f.parser.write('\x1b[?1049h\x1b[?1049l');
      expect(f.h.named('saveCursor').length, 1);
      expect(f.h.named('clearAltBuffer').length, 1);
      expect(f.h.named('useAltBuffer').length, 1);
      expect(f.h.named('useMainBuffer').length, 1);
    });

    test('CSI ?9 / ?1000 / ?1002 / ?1003 — mouse modes route to setMouseMode', () {
      final f = _newParser();
      f.parser.write('\x1b[?9h\x1b[?1000h\x1b[?1002h\x1b[?1003h');
      final modes = f.h.named('setMouseMode').map((c) => c.args.first).toList();
      expect(modes, [
        MouseMode.clickOnly,
        MouseMode.upDownScroll,
        MouseMode.upDownScrollDrag,
        MouseMode.upDownScrollMove,
      ]);
    });

    test('CSI ?9 / ?1000 disabled → setMouseMode(none)', () {
      final f = _newParser();
      f.parser.write('\x1b[?9l\x1b[?1000l');
      final modes = f.h.named('setMouseMode').map((c) => c.args.first).toList();
      expect(modes, [MouseMode.none, MouseMode.none]);
    });

    test('CSI ?1005 / ?1006 / ?1015 — mouse report modes', () {
      final f = _newParser();
      f.parser.write('\x1b[?1005h\x1b[?1006h\x1b[?1015h\x1b[?1006l');
      final modes = f.h.named('setMouseReportMode').map((c) => c.args.first).toList();
      expect(modes, [
        MouseReportMode.utf,
        MouseReportMode.sgr,
        MouseReportMode.urxvt,
        MouseReportMode.normal,
      ]);
    });

    test('CSI ?3 / ?5 / ?6 / ?12 / ?66 / ?1004 / ?1007 — column/reverse/origin/blink/keypad/focus/altScroll', () {
      final f = _newParser();
      f.parser.write('\x1b[?3h\x1b[?5l\x1b[?6h\x1b[?12h\x1b[?66h\x1b[?1004h\x1b[?1007h');
      expect(f.h.named('setColumnMode').first.args, [true]);
      expect(f.h.named('setReverseDisplayMode').first.args, [false]);
      expect(f.h.named('setOriginMode').first.args, [true]);
      expect(f.h.named('setCursorBlinkMode').first.args, [true]);
      expect(f.h.named('setAppKeypadMode').first.args, [true]);
      expect(f.h.named('setReportFocusMode').first.args, [true]);
      expect(f.h.named('setAltBufferMouseScrollMode').first.args, [true]);
    });

    test('CSI ?9999 — unknown DEC mode falls through to setUnknownDecMode', () {
      final f = _newParser();
      f.parser.write('\x1b[?9999h');
      expect(f.h.named('setUnknownDecMode').first.args, [9999, true]);
    });
  });

  group('EscapeParser — CSI SGR styling', () {
    test('empty params → resetCursorStyle', () {
      final f = _newParser();
      f.parser.write('\x1b[m');
      expect(f.h.calls.single.name, 'resetCursorStyle');
    });

    test('single attribute params 0..9 / 21..29 — set + unset', () {
      final f = _newParser();
      f.parser.write('\x1b[0;1;2;3;4;5;7;8;9m');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'resetCursorStyle',
        'setCursorBold',
        'setCursorFaint',
        'setCursorItalic',
        'setCursorUnderline',
        'setCursorBlink',
        'setCursorInverse',
        'setCursorInvisible',
        'setCursorStrikethrough',
      ]);
      f.h.clear();
      f.parser.write('\x1b[21;22;23;24;25;27;28;29m');
      expect(f.h.calls.map((c) => c.name).toList(), [
        'unsetCursorBold',
        'unsetCursorFaint',
        'unsetCursorItalic',
        'unsetCursorUnderline',
        'unsetCursorBlink',
        'unsetCursorInverse',
        'unsetCursorInvisible',
        'unsetCursorStrikethrough',
      ]);
    });

    test('foreground colour 16 — params 30..37 + 90..97', () {
      final f = _newParser();
      f.parser.write('\x1b[30;31;32;33;34;35;36;37;90;91;92;93;94;95;96;97m');
      // 16 calls to setForegroundColor16 with successive NamedColor int values.
      final args = f.h.named('setForegroundColor16').map((c) => c.args.first).toList();
      // NamedColor.black==0 .. white==7, brightBlack==8 .. brightWhite==15.
      expect(args, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
    });

    test('background colour 16 — params 40..47 + 100..107', () {
      final f = _newParser();
      f.parser.write('\x1b[40;41;42;43;44;45;46;47;100;101;102;103;104;105;106;107m');
      final args = f.h.named('setBackgroundColor16').map((c) => c.args.first).toList();
      expect(args, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
    });

    test('38;5;n / 48;5;n — 256-colour palette', () {
      final f = _newParser();
      f.parser.write('\x1b[38;5;200m\x1b[48;5;42m');
      expect(f.h.named('setForegroundColor256').first.args, [200]);
      expect(f.h.named('setBackgroundColor256').first.args, [42]);
    });

    test('38;2;r;g;b / 48;2;r;g;b — 24-bit RGB', () {
      final f = _newParser();
      f.parser.write('\x1b[38;2;10;20;30m\x1b[48;2;100;150;200m');
      expect(f.h.named('setForegroundColorRgb').first.args, [10, 20, 30]);
      expect(f.h.named('setBackgroundColorRgb').first.args, [100, 150, 200]);
    });

    test('39 / 49 — reset foreground / background', () {
      final f = _newParser();
      f.parser.write('\x1b[39;49m');
      expect(f.h.named('resetForeground').length, 1);
      expect(f.h.named('resetBackground').length, 1);
    });

    test('unknown SGR param → unsupportedStyle', () {
      final f = _newParser();
      f.parser.write('\x1b[123m');
      expect(f.h.named('unsupportedStyle').first.args, [123]);
    });
  });

  group('EscapeParser — OSC sequences', () {
    test('OSC 0 ; title BEL → setTitle + setIconName', () {
      final f = _newParser();
      f.parser.write('\x1b]0;hello\x07');
      expect(f.h.named('setTitle').first.args, ['hello']);
      expect(f.h.named('setIconName').first.args, ['hello']);
    });

    test('OSC 1 ; iconname BEL → setIconName only', () {
      final f = _newParser();
      f.parser.write('\x1b]1;icon\x07');
      expect(f.h.named('setIconName').first.args, ['icon']);
      expect(f.h.named('setTitle'), isEmpty);
    });

    test('OSC 2 ; title BEL → setTitle only', () {
      final f = _newParser();
      f.parser.write('\x1b]2;title\x07');
      expect(f.h.named('setTitle').first.args, ['title']);
      expect(f.h.named('setIconName'), isEmpty);
    });

    test('OSC terminated by ST (ESC \\) instead of BEL', () {
      final f = _newParser();
      f.parser.write('\x1b]0;via-st\x1b\\');
      expect(f.h.named('setTitle').first.args, ['via-st']);
    });

    test('OSC unknown ps → unknownOSC', () {
      final f = _newParser();
      f.parser.write('\x1b]99;arg1;arg2\x07');
      expect(f.h.named('unknownOSC').first.args[0], '99');
      expect(f.h.named('unknownOSC').first.args[1], ['arg1', 'arg2']);
    });

    test('OSC with only a terminator dispatches unknownOSC with empty params', () {
      // _consumeOsc records the empty string before BEL, so _osc = [""];
      // length is 1 (not 0), so the empty-fast-path doesn't fire and the
      // sequence falls through to unknownOSC.
      final f = _newParser();
      f.parser.write('\x1b]\x07');
      expect(f.h.named('unknownOSC').first.args[0], '');
      expect(f.h.named('unknownOSC').first.args[1], <String>[]);
    });

    test('OSC incomplete sequence is held back until terminator arrives', () {
      final f = _newParser();
      f.parser.write('\x1b]0;par');
      expect(f.h.calls, isEmpty);
      f.parser.write('tial\x07');
      expect(f.h.named('setTitle').first.args, ['partial']);
    });
  });

  group('EscapeParser — CSI unknown final byte', () {
    test('routes to unknownCSI(finalByte)', () {
      final f = _newParser();
      f.parser.write('\x1b[~'); // ~ has no entry in _csiHandlers
      expect(f.h.named('unknownCSI').first.args, ['~'.codeUnitAt(0)]);
    });
  });

  group('EscapeParser — token bookkeeping', () {
    test('tokenBegin / tokenEnd advance with consumed bytes', () {
      final f = _newParser();
      f.parser.write('AB\x1b[H');
      // Last token was the CSI H sequence. tokenBegin sits at the start
      // of the ESC; tokenEnd advances to one past the last consumed byte.
      expect(f.parser.tokenEnd, greaterThan(f.parser.tokenBegin));
      expect(f.parser.tokenEnd, 5); // total bytes consumed
    });
  });

  group('EscapeEmitter', () {
    const e = EscapeEmitter();

    test('primary device attributes', () {
      expect(e.primaryDeviceAttributes(), '\x1b[?1;2c');
    });

    test('secondary device attributes', () {
      expect(e.secondaryDeviceAttributes(), '\x1b[>0;0;0c');
    });

    test('tertiary device attributes', () {
      expect(e.tertiaryDeviceAttributes(), '\x1bP!|00000000\x1b\\');
    });

    test('operating status', () {
      expect(e.operatingStatus(), '\x1b[0n');
    });

    test('cursor position', () {
      expect(e.cursorPosition(7, 3), '\x1b[3;7R');
    });

    test('bracketed paste wraps the text', () {
      expect(e.bracketedPaste('abc'), '\x1b[200~abc\x1b[201~');
    });

    test('size emits CSI 8 ; rows ; cols t', () {
      expect(e.size(24, 80), '\x1b[8;24;80t');
    });
  });
}
