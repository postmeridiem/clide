// terminal_theme.dart
//
// Terminal — near-black bg, high-contrast mono, single amber accent.
// For users who want the IDE to read like a tmux window.

import 'package:flutter/material.dart';
import 'clide_theme.dart' show ClideTokens;

class TerminalTheme {
  static const _bg          = Color(0xFF0A0A0A);
  static const _bgSunken    = Color(0xFF000000);
  static const _surface     = Color(0xFF111111);
  static const _surfaceHi   = Color(0xFF181818);
  static const _border      = Color(0xFF242424);
  static const _borderHi    = Color(0xFF2E2E2E);

  static const _textHi      = Color(0xFFE6E6E6);
  static const _text        = Color(0xFFBDBDBD);
  static const _textDim     = Color(0xFF7A7A7A);
  static const _textMute    = Color(0xFF4A4A4A);

  static const _accent      = Color(0xFFE0B050); // amber
  static const _accentPress = Color(0xFFC29438);
  static const _accentSoft  = Color(0x22E0B050);

  static const _ok          = Color(0xFF8FDC9B);
  static const _warn        = Color(0xFFE0B050);
  static const _err         = Color(0xFFE05050);
  static const _info        = Color(0xFFA3C4FF);

  // Classic 16-color palette feel
  static const _synKeyword  = Color(0xFFE05050);
  static const _synType     = Color(0xFFE0B050);
  static const _synString   = Color(0xFF8FDC9B);
  static const _synNumber   = Color(0xFFC792EA);
  static const _synComment  = Color(0xFF4A4A4A);
  static const _synMethod   = Color(0xFFA3C4FF);
  static const _synPunct    = Color(0xFF7A7A7A);

  static const tokens = ClideTokens(
    bg: _bg, bgSunken: _bgSunken, surface: _surface, surfaceHi: _surfaceHi,
    border: _border, borderHi: _borderHi,
    textHi: _textHi, text: _text, textDim: _textDim, textMute: _textMute,
    accent: _accent, accentPress: _accentPress, accentSoft: _accentSoft,
    ok: _ok, warn: _warn, err: _err, info: _info,
    synKeyword: _synKeyword, synType: _synType, synString: _synString,
    synNumber: _synNumber, synComment: _synComment, synMethod: _synMethod,
    synPunct: _synPunct,
  );

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    canvasColor: _bg,
    colorScheme: const ColorScheme.dark(
      primary: _accent, onPrimary: Color(0xFF000000),
      secondary: _info, onSecondary: Color(0xFF000000),
      surface: _surface, onSurface: _textHi,
      surfaceContainerHighest: _surfaceHi,
      outline: _border, outlineVariant: _borderHi,
      error: _err, onError: Color(0xFF000000),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 48, color: _textHi),
      displayMedium: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 34, color: _textHi),
      headlineSmall: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 20, color: _textHi),
      titleMedium:   TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 14, color: _text),
      // Terminal mockups go full-mono even for display.
      labelSmall:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 1.0, color: _textMute),
      bodyMedium:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 12, height: 1.45, color: _textHi),
      bodySmall:     TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 11, color: _text),
    ),
    dividerTheme: const DividerThemeData(color: _border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: _textDim, size: 14),
  );
}
