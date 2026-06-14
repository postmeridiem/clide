// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

// CSI handlers: cursor movement, erase/scroll/line/char ops, device
// attributes + status reports, margins, tab clear, repeat, and window
// manipulation. Split out of parser.dart (T-123); dispatched from the
// _csiHandlers table in the EscapeParser core.

part of 'parser.dart';

mixin _CsiHandlers on _EscapeParserBase {
  /// `ESC [ Ps a` Cursor Horizontal Position Relative (HPR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sa/
  // void _csiHandleCursorHorizontalRelative() {
  //   if (_csi.params.isEmpty) {
  //     handler.cursorHorizontal(1);
  //   } else {
  //     handler.cursorHorizontal(_csi.params[0]);
  //   }
  // }
  /// `ESC [ Ps b` Repeat Previous Character (REP)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sb/
  void _csiHandleRepeatPreviousCharacter() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.repeatPreviousCharacter(amount);
  }

  /// `ESC [ Ps c` Device Attributes (DA)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sc/
  void _csiHandleSendDeviceAttributes() {
    switch (_csi.prefix) {
      case Ascii.greaterThan:
        return handler.sendSecondaryDeviceAttributes();
      case Ascii.equal:
        return handler.sendTertiaryDeviceAttributes();
      default:
        handler.sendPrimaryDeviceAttributes();
    }
  }

  /// `ESC [ Ps d` Cursor Vertical Position Absolute (VPA)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sd/
  void _csiHandleLinePositionAbsolute() {
    var y = 1;

    if (_csi.params.isNotEmpty) {
      y = _csi.params[0];
    }

    handler.setCursorY(y - 1);
  }

  /// `ESC [ Ps ; Ps f` Alias: Set Cursor Position
  ///
  /// https://terminalguide.namepad.de/seq/csi_sf/
  void _csiHandleCursorPosition() {
    var row = 1;
    var col = 1;

    if (_csi.params.length == 2) {
      row = _csi.params[0];
      col = _csi.params[1];
    }

    handler.setCursor(col - 1, row - 1);
  }

  /// `ESC [ Ps g` Tab Clear (TBC)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sg/
  void _csiHandelClearTabStop() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.clearTabStopUnderCursor();
      default:
        return handler.clearAllTabStops();
    }
  }

  /// `ESC [ Ps n` Device Status Report [Dispatch] (DSR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sn/
  void _csiHandleDeviceStatusReport() {
    if (_csi.params.isEmpty) return;

    switch (_csi.params[0]) {
      case 5:
        return handler.sendOperatingStatus();
      case 6:
        return handler.sendCursorPosition();
    }
  }

  /// `ESC [ Ps ; Ps r` Set Top and Bottom Margins (DECSTBM)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sr/
  void _csiHandleSetMargins() {
    var top = 1;
    int? bottom;

    if (_csi.params.length > 2) return;

    if (_csi.params.isNotEmpty) {
      top = _csi.params[0];

      if (_csi.params.length == 2) {
        bottom = _csi.params[1] - 1;
      }
    }

    handler.setMargins(top - 1, bottom);
  }

  /// `ESC [ Ps t` Window operations [DISPATCH]
  ///
  /// https://terminalguide.namepad.de/seq/csi_st/
  void _csiWindowManipulation() {
    // The sequence needs at least one parameter.
    if (_csi.params.isEmpty) {
      return;
    }
    // Most the commands in this group are either of the scope of this package,
    // or should be disabled for security risks.
    switch (_csi.params.first) {
      // Window handling is currently not in the scope of the package.
      case 1: // Restore Terminal Window (show window if minimized)
      case 2: // Minimize Terminal Window
      case 3: // Set Terminal Window Position
      case 4: // Set Terminal Window Size in Pixels
      case 5: // Raise Terminal Window
      case 6: // Lower Terminal Window
      case 7: // Refresh/Redraw Terminal Window
        return;
      case 8: // Set Terminal Window Size (in characters)
        // This CSI contains 2 more parameters: width and height.
        if (_csi.params.length != 3) {
          return;
        }
        final rows = _csi.params[1];
        final cols = _csi.params[2];
        handler.resize(cols, rows);
        return;
      // Window handling is currently no in the scope of the package.
      case 9: // Maximize Terminal Window
      case 10: // Alias: Maximize Terminal Window
      case 11: // Report Terminal Window State
      case 13: // Report Terminal Window Position
      case 14: // Report Terminal Window Size in Pixels
      case 15: // Report Screen Size in Pixels
      case 16: // Report Cell Size in Pixels
        return;
      case 18: // Report Terminal Size (in characters)
        handler.sendSize();
        return;
      // Screen handling is currently no in the scope of the package.
      case 19: // Report Screen Size (in characters)
      // Disabled as these can a security risk.
      case 20: // Get Icon Title
      case 21: // Get Terminal Title
      // Not implemented.
      case 22: // Push Terminal Title
      case 23: // Pop Terminal Title
        return;
      // Unknown CSI.
      default:
        return;
    }
  }

  /// `ESC [ Ps A` Cursor Up (CUU)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ca/
  void _csiHandleCursorUp() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorY(-amount);
  }

  /// `ESC [ Ps B` Cursor Down (CUD)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cb/
  void _csiHandleCursorDown() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorY(amount);
  }

  /// `ESC [ Ps C` Cursor Right (CUF)
  ///
  /// Cursor Right (CUF)
  void _csiHandleCursorForward() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorX(amount);
  }

  /// `ESC [ Ps D` Cursor Left (CUB)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cd/
  void _csiHandleCursorBackward() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.moveCursorX(-amount);
  }

  /// `ESC [ Ps E` Cursor Next Line (CNL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ce/
  void _csiHandleCursorNextLine() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.cursorNextLine(amount);
  }

  /// `ESC [ Ps F` Cursor Previous Line (CPL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cf/
  void _csiHandleCursorPrecedingLine() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
      if (amount == 0) amount = 1;
    }

    handler.cursorPrecedingLine(amount);
  }

  void _csiHandleCursorHorizontalAbsolute() {
    var x = 1;

    if (_csi.params.isNotEmpty) {
      x = _csi.params[0];
      if (x == 0) x = 1;
    }

    handler.setCursorX(x - 1);
  }

  /// ESC [ Ps J Erase Display [Dispatch] (ED)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cj/
  void _csiHandleEraseDisplay() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.eraseDisplayBelow();
      case 1:
        return handler.eraseDisplayAbove();
      case 2:
        return handler.eraseDisplay();
      case 3:
        return handler.eraseScrollbackOnly();
    }
  }

  /// `ESC [ Ps K` Erase Line [Dispatch] (EL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ck/
  void _csiHandleEraseLine() {
    var cmd = 0;

    if (_csi.params.length == 1) {
      cmd = _csi.params[0];
    }

    switch (cmd) {
      case 0:
        return handler.eraseLineRight();
      case 1:
        return handler.eraseLineLeft();
      case 2:
        return handler.eraseLine();
    }
  }

  /// `ESC [ Ps L` Insert Line (IL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cl/
  void _csiHandleInsertLines() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.insertLines(amount);
  }

  /// ESC [ Ps M Delete Line (DL)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cm/
  void _csiHandleDeleteLines() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.deleteLines(amount);
  }

  /// ESC [ Ps P Delete Character (DCH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cp/
  void _csiHandleDelete() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.deleteChars(amount);
  }

  /// `ESC [ Ps S` Scroll Up (SU)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cs/
  void _csiHandleScrollUp() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.scrollUp(amount);
  }

  /// `ESC [ Ps T `Scroll Down (SD)
  ///
  /// https://terminalguide.namepad.de/seq/csi_ct_1param/
  void _csiHandleScrollDown() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.scrollDown(amount);
  }

  /// `ESC [ Ps X` Erase Character (ECH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_cx/
  void _csiHandleEraseCharacters() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.eraseChars(amount);
  }

  /// `ESC [ Ps @` Insert Blanks (ICH)
  ///
  /// https://terminalguide.namepad.de/seq/csi_x40_at/
  ///
  /// Inserts amount spaces at current cursor position moving existing cell
  /// contents to the right. The contents of the amount right-most columns in
  /// the scroll region are lost. The cursor position is not changed.
  void _csiHandleInsertBlankCharacters() {
    var amount = 1;

    if (_csi.params.isNotEmpty) {
      amount = _csi.params[0];
    }

    handler.insertBlankChars(amount);
  }
}
