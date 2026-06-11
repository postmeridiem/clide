/// Pure-Dart tests for `lib/src/terminal/src/core/mouse/`.
library;

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/cursor.dart';
import 'package:clide/src/terminal/src/core/mouse/button.dart';
import 'package:clide/src/terminal/src/core/mouse/button_state.dart';
import 'package:clide/src/terminal/src/core/mouse/handler.dart';
import 'package:clide/src/terminal/src/core/mouse/mode.dart';
import 'package:clide/src/terminal/src/core/mouse/reporter.dart';
import 'package:clide/src/terminal/src/core/platform.dart';
import 'package:clide/src/terminal/src/core/state.dart';
import 'package:test/test.dart';

class _State implements TerminalState {
  _State({this.mouseMode = MouseMode.none, this.mouseReportMode = MouseReportMode.normal});

  @override
  MouseMode mouseMode;
  @override
  MouseReportMode mouseReportMode;

  @override
  int get viewWidth => 80;
  @override
  int get viewHeight => 24;
  @override
  CursorStyle get cursor => CursorStyle();
  @override
  bool get reflowEnabled => false;
  @override
  bool get insertMode => false;
  @override
  bool get lineFeedMode => false;
  @override
  bool get cursorKeysMode => false;
  @override
  bool get reverseDisplayMode => false;
  @override
  bool get originMode => false;
  @override
  bool get autoWrapMode => true;
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

TerminalMouseEvent _evt(
  TerminalMouseButton button,
  TerminalMouseButtonState state, {
  int x = 0,
  int y = 0,
  MouseMode mode = MouseMode.none,
  MouseReportMode reportMode = MouseReportMode.normal,
  TerminalTargetPlatform platform = TerminalTargetPlatform.linux,
}) {
  return TerminalMouseEvent(
    button: button,
    buttonState: state,
    position: CellOffset(x, y),
    state: _State(mouseMode: mode, mouseReportMode: reportMode),
    platform: platform,
  );
}

void main() {
  group('TerminalMouseButton', () {
    test('left/middle/right have ids 0/1/2 and isWheel=false', () {
      expect(TerminalMouseButton.left.id, 0);
      expect(TerminalMouseButton.middle.id, 1);
      expect(TerminalMouseButton.right.id, 2);
      expect(TerminalMouseButton.left.isWheel, isFalse);
      expect(TerminalMouseButton.middle.isWheel, isFalse);
      expect(TerminalMouseButton.right.isWheel, isFalse);
    });

    test('wheel buttons are flagged isWheel and use the 64+N transposed ids', () {
      expect(TerminalMouseButton.wheelUp.id, 64 + 4);
      expect(TerminalMouseButton.wheelDown.id, 64 + 5);
      expect(TerminalMouseButton.wheelLeft.id, 64 + 6);
      expect(TerminalMouseButton.wheelRight.id, 64 + 7);
      for (final b in [TerminalMouseButton.wheelUp, TerminalMouseButton.wheelDown, TerminalMouseButton.wheelLeft, TerminalMouseButton.wheelRight]) {
        expect(b.isWheel, isTrue, reason: '$b');
      }
    });
  });

  group('MouseReporter (normal mode)', () {
    String r(TerminalMouseButton b, TerminalMouseButtonState s, {int x = 0, int y = 0}) => MouseReporter.report(b, s, CellOffset(x, y), MouseReportMode.normal);

    test('press encodes button id + 1-based coordinates', () {
      // Position (0,0) → button code 32+0=32 (' '), col 32+1=33 ('!'),
      // row 32+1+1=34 ('"').
      expect(r(TerminalMouseButton.left, TerminalMouseButtonState.down), '\x1b[M !"');
    });

    test('release uses button id 3 regardless of which button was up', () {
      expect(r(TerminalMouseButton.right, TerminalMouseButtonState.up), '\x1b[M#!"'); // 32+3='#' for the up code
    });

    test('coordinates beyond 223 (8-bit limit) emit a null byte', () {
      final out = r(TerminalMouseButton.left, TerminalMouseButtonState.down, x: 300, y: 0);
      expect(out, '\x1b[M \x00"'); // null in the column slot
    });
  });

  group('MouseReporter (utf mode)', () {
    test('uses the 2015 limit for the null-byte clamp', () {
      // x=300 fits into utf mode (limit 2015) — should emit a real char.
      final out = MouseReporter.report(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(300, 0), MouseReportMode.utf);
      expect(out.contains('\x00'), isFalse);
      // x=3000 trips the utf limit.
      final outBig = MouseReporter.report(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(3000, 3000), MouseReportMode.utf);
      expect(outBig.contains('\x00'), isTrue);
    });
  });

  group('MouseReporter (sgr mode)', () {
    test('M for press, m for release, with raw 1-based coords', () {
      expect(MouseReporter.report(TerminalMouseButton.middle, TerminalMouseButtonState.down, const CellOffset(10, 20), MouseReportMode.sgr), '\x1b[<1;11;21M');
      expect(MouseReporter.report(TerminalMouseButton.middle, TerminalMouseButtonState.up, const CellOffset(10, 20), MouseReportMode.sgr), '\x1b[<1;11;21m');
    });
  });

  group('MouseReporter (urxvt mode)', () {
    test('always M, button id +32 (3 for up, real for down)', () {
      expect(
        MouseReporter.report(TerminalMouseButton.left, TerminalMouseButtonState.down, const CellOffset(5, 7), MouseReportMode.urxvt),
        '\x1b[32;6;8M', // 32+0 = 32 for left-button down
      );
      expect(
        MouseReporter.report(TerminalMouseButton.left, TerminalMouseButtonState.up, const CellOffset(5, 7), MouseReportMode.urxvt),
        '\x1b[35;6;8M', // 32+3 = 35 for any up
      );
    });
  });

  group('TerminalMouseEvent', () {
    test('constructor exposes every field directly', () {
      final e = _evt(TerminalMouseButton.left, TerminalMouseButtonState.down, x: 3, y: 5);
      expect(e.button, TerminalMouseButton.left);
      expect(e.buttonState, TerminalMouseButtonState.down);
      expect(e.position, const CellOffset(3, 5));
      expect(e.platform, TerminalTargetPlatform.linux);
      expect(e.state, isA<TerminalState>());
    });
  });

  group('CascadeMouseHandler', () {
    test('returns the first non-null result; null when all return null', () {
      const cascade = CascadeMouseHandler([_NullHandler(), _ConstHandler('first'), _ConstHandler('second')]);
      expect(cascade(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down)), 'first');

      const allNull = CascadeMouseHandler([_NullHandler(), _NullHandler()]);
      expect(allNull(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down)), isNull);
    });
  });

  group('ClickMouseHandler', () {
    const h = ClickMouseHandler();

    test('clickOnly mode + down + button id < 3 → reports', () {
      final out = h(_evt(TerminalMouseButton.middle, TerminalMouseButtonState.down, mode: MouseMode.clickOnly));
      expect(out, isNotNull);
    });

    test('clickOnly mode + up → null (only down events report)', () {
      expect(h(_evt(TerminalMouseButton.middle, TerminalMouseButtonState.up, mode: MouseMode.clickOnly)), isNull);
    });

    test('clickOnly mode + button id >= 3 (wheel) → null', () {
      expect(h(_evt(TerminalMouseButton.wheelUp, TerminalMouseButtonState.down, mode: MouseMode.clickOnly)), isNull);
    });

    test('non-clickOnly modes always return null', () {
      for (final m in [MouseMode.none, MouseMode.upDownScroll, MouseMode.upDownScrollDrag, MouseMode.upDownScrollMove]) {
        expect(h(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down, mode: m)), isNull, reason: '$m');
      }
    });
  });

  group('UpDownMouseHandler', () {
    const h = UpDownMouseHandler();

    test('none / clickOnly modes return null', () {
      for (final m in [MouseMode.none, MouseMode.clickOnly]) {
        expect(h(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down, mode: m)), isNull);
      }
    });

    test('upDownScroll modes report regular button events', () {
      for (final m in [MouseMode.upDownScroll, MouseMode.upDownScrollDrag, MouseMode.upDownScrollMove]) {
        expect(h(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down, mode: m)), isNotNull, reason: '$m');
      }
    });

    test('wheel up events are silently dropped (no report on wheel release)', () {
      expect(h(_evt(TerminalMouseButton.wheelUp, TerminalMouseButtonState.up, mode: MouseMode.upDownScroll)), isNull);
    });

    test('wheel down events do report (one click per scroll tick)', () {
      expect(h(_evt(TerminalMouseButton.wheelDown, TerminalMouseButtonState.down, mode: MouseMode.upDownScroll)), isNotNull);
    });
  });

  group('defaultMouseHandler', () {
    test('routes clickOnly through ClickMouseHandler', () {
      final out = defaultMouseHandler(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down, mode: MouseMode.clickOnly));
      expect(out, isNotNull);
    });

    test('routes upDownScroll through UpDownMouseHandler', () {
      final out = defaultMouseHandler(_evt(TerminalMouseButton.middle, TerminalMouseButtonState.up, mode: MouseMode.upDownScrollDrag));
      expect(out, isNotNull);
    });

    test('mode=none produces null (no handler reports)', () {
      expect(defaultMouseHandler(_evt(TerminalMouseButton.left, TerminalMouseButtonState.down, mode: MouseMode.none)), isNull);
    });
  });
}

class _NullHandler extends TerminalMouseHandler {
  const _NullHandler();
  @override
  String? call(TerminalMouseEvent event) => null;
}

class _ConstHandler extends TerminalMouseHandler {
  const _ConstHandler(this._value);
  final String _value;
  @override
  String? call(TerminalMouseEvent event) => _value;
}
