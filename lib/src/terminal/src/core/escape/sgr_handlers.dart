// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

// SGR (Select Graphic Rendition) handling, including the guarded
// extended-color (38/48) path with ITU T.416 colon sub-parameters
// (T-369). Split out of parser.dart (T-123).

part of 'parser.dart';

mixin _SgrHandlers on _EscapeParserBase {
  /// `ESC [ [ Ps ] m` Select Graphic Rendition (SGR)
  ///
  /// https://terminalguide.namepad.de/seq/csi_sm/
  void _csiHandleSgr() {
    final params = _csi.params;

    if (params.isEmpty) {
      return handler.resetCursorStyle();
    }

    for (var i = 0; i < _csi.params.length; i++) {
      final param = params[i];
      switch (param) {
        case 0:
          handler.resetCursorStyle();
          continue;
        case 1:
          handler.setCursorBold();
          continue;
        case 2:
          handler.setCursorFaint();
          continue;
        case 3:
          handler.setCursorItalic();
          continue;
        case 4:
          handler.setCursorUnderline();
          continue;
        case 5:
          handler.setCursorBlink();
          continue;
        case 7:
          handler.setCursorInverse();
          continue;
        case 8:
          handler.setCursorInvisible();
          continue;
        case 9:
          handler.setCursorStrikethrough();
          continue;

        case 21:
          handler.unsetCursorBold();
          continue;
        case 22:
          handler.unsetCursorFaint();
          continue;
        case 23:
          handler.unsetCursorItalic();
          continue;
        case 24:
          handler.unsetCursorUnderline();
          continue;
        case 25:
          handler.unsetCursorBlink();
          continue;
        case 27:
          handler.unsetCursorInverse();
          continue;
        case 28:
          handler.unsetCursorInvisible();
          continue;
        case 29:
          handler.unsetCursorStrikethrough();
          continue;

        case 30:
          handler.setForegroundColor16(NamedColor.black);
          continue;
        case 31:
          handler.setForegroundColor16(NamedColor.red);
          continue;
        case 32:
          handler.setForegroundColor16(NamedColor.green);
          continue;
        case 33:
          handler.setForegroundColor16(NamedColor.yellow);
          continue;
        case 34:
          handler.setForegroundColor16(NamedColor.blue);
          continue;
        case 35:
          handler.setForegroundColor16(NamedColor.magenta);
          continue;
        case 36:
          handler.setForegroundColor16(NamedColor.cyan);
          continue;
        case 37:
          handler.setForegroundColor16(NamedColor.white);
          continue;
        case 38:
          i = _csiHandleExtendedColor(i, foreground: true);
          continue;
        case 39:
          handler.resetForeground();
          continue;

        case 40:
          handler.setBackgroundColor16(NamedColor.black);
          continue;
        case 41:
          handler.setBackgroundColor16(NamedColor.red);
          continue;
        case 42:
          handler.setBackgroundColor16(NamedColor.green);
          continue;
        case 43:
          handler.setBackgroundColor16(NamedColor.yellow);
          continue;
        case 44:
          handler.setBackgroundColor16(NamedColor.blue);
          continue;
        case 45:
          handler.setBackgroundColor16(NamedColor.magenta);
          continue;
        case 46:
          handler.setBackgroundColor16(NamedColor.cyan);
          continue;
        case 47:
          handler.setBackgroundColor16(NamedColor.white);
          continue;
        case 48:
          i = _csiHandleExtendedColor(i, foreground: false);
          continue;
        case 49:
          handler.resetBackground();
          continue;

        case 90:
          handler.setForegroundColor16(NamedColor.brightBlack);
          continue;
        case 91:
          handler.setForegroundColor16(NamedColor.brightRed);
          continue;
        case 92:
          handler.setForegroundColor16(NamedColor.brightGreen);
          continue;
        case 93:
          handler.setForegroundColor16(NamedColor.brightYellow);
          continue;
        case 94:
          handler.setForegroundColor16(NamedColor.brightBlue);
          continue;
        case 95:
          handler.setForegroundColor16(NamedColor.brightMagenta);
          continue;
        case 96:
          handler.setForegroundColor16(NamedColor.brightCyan);
          continue;
        case 97:
          handler.setForegroundColor16(NamedColor.brightWhite);
          continue;

        case 100:
          handler.setBackgroundColor16(NamedColor.brightBlack);
          continue;
        case 101:
          handler.setBackgroundColor16(NamedColor.brightRed);
          continue;
        case 102:
          handler.setBackgroundColor16(NamedColor.brightGreen);
          continue;
        case 103:
          handler.setBackgroundColor16(NamedColor.brightYellow);
          continue;
        case 104:
          handler.setBackgroundColor16(NamedColor.brightBlue);
          continue;
        case 105:
          handler.setBackgroundColor16(NamedColor.brightMagenta);
          continue;
        case 106:
          handler.setBackgroundColor16(NamedColor.brightCyan);
          continue;
        case 107:
          handler.setBackgroundColor16(NamedColor.brightWhite);
          continue;

        default:
          handler.unsupportedStyle(param);
          continue;
      }
    }
  }

  /// Extended fg/bg color (SGR 38/48), semicolon or colon form.
  ///
  /// Returns the index of the last parameter consumed. Never reads past the
  /// end of the parameter list — a truncated sequence (`ESC [38m`,
  /// `ESC [38;2;255m`) is ignored instead of throwing; an emulator must never
  /// throw on hostile bytes (T-369). Colon-form sub-parameters per ITU T.416
  /// (`38:2:r:g:b`, `38:2:<colorspace>:r:g:b`, `38:5:n`) are treated as one
  /// logical group: parsed equivalently to the semicolon form, and dropped
  /// whole when malformed so they never spill into neighbouring parameters.
  int _csiHandleExtendedColor(int i, {required bool foreground}) {
    final params = _csi.params;
    final sub = _csi.subParam;

    // End of the colon-linked group starting at params[i] (exclusive).
    var end = i + 1;
    while (end < params.length && sub[end]) {
      end++;
    }

    if (end > i + 1) {
      // Colon form. Group is params[i..end-1]; n includes the 38/48 itself.
      final n = end - i;
      final mode = params[i + 1];
      if (mode == 5 && n >= 3) {
        foreground ? handler.setForegroundColor256(params[i + 2]) : handler.setBackgroundColor256(params[i + 2]);
      } else if (mode == 2) {
        // A 6+ element group carries the T.416 colorspace id slot — skip it.
        final base = n >= 6 ? i + 3 : i + 2;
        if (base + 2 < end) {
          foreground
              ? handler.setForegroundColorRgb(params[base], params[base + 1], params[base + 2])
              : handler.setBackgroundColorRgb(params[base], params[base + 1], params[base + 2]);
        }
      }
      return end - 1;
    }

    // Semicolon form (legacy).
    if (i + 1 >= params.length) return i; // bare 38/48 — ignore
    switch (params[i + 1]) {
      case 2:
        if (i + 4 >= params.length) return params.length - 1; // truncated — ignore
        foreground
            ? handler.setForegroundColorRgb(params[i + 2], params[i + 3], params[i + 4])
            : handler.setBackgroundColorRgb(params[i + 2], params[i + 3], params[i + 4]);
        return i + 4;
      case 5:
        if (i + 2 >= params.length) return params.length - 1; // truncated — ignore
        foreground ? handler.setForegroundColor256(params[i + 2]) : handler.setBackgroundColor256(params[i + 2]);
        return i + 2;
    }
    // Unknown mode — consume it so it isn't re-interpreted as an SGR code.
    return i + 1;
  }
}
