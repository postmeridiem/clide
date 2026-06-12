// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

// ANSI + DEC private mode set/reset (CSI h / CSI l, with and without
// the ? prefix). Split out of parser.dart (T-123).

part of 'parser.dart';

mixin _ModeHandlers on _EscapeParserBase {
  /// - `ESC [ [ Pm ] h Set Mode (SM)` https://terminalguide.namepad.de/seq/csi_sm/
  /// - `ESC [ ? [ Pm ] h` Set Mode (?) (SM) https://terminalguide.namepad.de/seq/csi_sh__p/
  /// - `ESC [ [ Pm ] l` Reset Mode (RM) https://terminalguide.namepad.de/seq/csi_rm/
  /// - `ESC [ ? [ Pm ] l` Reset Mode (?) (RM) https://terminalguide.namepad.de/seq/csi_sl__p/
  void _csiHandleMode() {
    final isEnabled = _csi.finalByte == Ascii.h;

    final isDecModes = _csi.prefix == Ascii.questionMark;

    if (isDecModes) {
      for (var mode in _csi.params) {
        _setDecMode(mode, isEnabled);
      }
    } else {
      for (var mode in _csi.params) {
        _setMode(mode, isEnabled);
      }
    }
  }

  void _setMode(int mode, bool enabled) {
    switch (mode) {
      case 4:
        return handler.setInsertMode(enabled);
      case 20:
        return handler.setLineFeedMode(enabled);
      default:
        return handler.setUnknownMode(mode, enabled);
    }
  }

  void _setDecMode(int mode, bool enabled) {
    switch (mode) {
      case 1:
        return handler.setCursorKeysMode(enabled);
      case 3:
        return handler.setColumnMode(enabled);
      case 5:
        return handler.setReverseDisplayMode(enabled);
      case 6:
        return handler.setOriginMode(enabled);
      case 7:
        return handler.setAutoWrapMode(enabled);
      case 9:
        return enabled ? handler.setMouseMode(MouseMode.clickOnly) : handler.setMouseMode(MouseMode.none);
      case 12:
      case 13:
        return handler.setCursorBlinkMode(enabled);
      case 25:
        return handler.setCursorVisibleMode(enabled);
      case 47:
        if (enabled) {
          return handler.useAltBuffer();
        } else {
          return handler.useMainBuffer();
        }
      case 66:
        return handler.setAppKeypadMode(enabled);
      case 1000:
        return enabled ? handler.setMouseMode(MouseMode.upDownScroll) : handler.setMouseMode(MouseMode.none);
      case 1001:
        return enabled ? handler.setMouseMode(MouseMode.upDownScroll) : handler.setMouseMode(MouseMode.none);
      case 1002:
        return enabled ? handler.setMouseMode(MouseMode.upDownScrollDrag) : handler.setMouseMode(MouseMode.none);
      case 1003:
        return enabled ? handler.setMouseMode(MouseMode.upDownScrollMove) : handler.setMouseMode(MouseMode.none);
      case 1004:
        return handler.setReportFocusMode(enabled);
      case 1005:
        return enabled ? handler.setMouseReportMode(MouseReportMode.utf) : handler.setMouseReportMode(MouseReportMode.normal);
      case 1006:
        return enabled ? handler.setMouseReportMode(MouseReportMode.sgr) : handler.setMouseReportMode(MouseReportMode.normal);
      case 1007:
        return handler.setAltBufferMouseScrollMode(enabled);
      case 1015:
        return enabled ? handler.setMouseReportMode(MouseReportMode.urxvt) : handler.setMouseReportMode(MouseReportMode.normal);
      case 1047:
        if (enabled) {
          handler.useAltBuffer();
        } else {
          handler.clearAltBuffer();
          handler.useMainBuffer();
        }
        return;
      case 1048:
        if (enabled) {
          return handler.saveCursor();
        } else {
          return handler.restoreCursor();
        }
      case 1049:
        if (enabled) {
          handler.saveCursor();
          handler.clearAltBuffer();
          handler.useAltBuffer();
        } else {
          handler.useMainBuffer();
        }
        return;
      case 2004:
        return handler.setBracketedPasteMode(enabled);
      default:
        return handler.setUnknownDecMode(mode, enabled);
    }
  }
}
