// midnight_theme.dart
//
// Midnight — classic dark, VS Code-adjacent, maximally muted. Gets out of the way.

import 'package:flutter/material.dart';
import 'clide_theme.dart' show ClideTokens;

class MidnightTheme {
  static const _bg          = Color(0xFF1E1E1E);
  static const _bgSunken    = Color(0xFF181818);
  static const _surface     = Color(0xFF252526);
  static const _surfaceHi   = Color(0xFF2D2D2E);
  static const _border      = Color(0xFF333333);
  static const _borderHi    = Color(0xFF3F3F3F);

  static const _textHi      = Color(0xFFD4D4D4);
  static const _text        = Color(0xFFBBBBBB);
  static const _textDim     = Color(0xFF858585);
  static const _textMute    = Color(0xFF6A6A6A);

  static const _accent      = Color(0xFF569CD6); // muted azure
  static const _accentPress = Color(0xFF4785BD);
  static const _accentSoft  = Color(0x22569CD6);

  static const _ok          = Color(0xFF89D185);
  static const _warn        = Color(0xFFD7BA7D);
  static const _err         = Color(0xFFF48771);
  static const _info        = _accent;

  static const _synKeyword  = Color(0xFFC586C0);
  static const _synType     = Color(0xFF4EC9B0);
  static const _synString   = Color(0xFFCE9178);
  static const _synNumber   = Color(0xFFB5CEA8);
  static const _synComment  = Color(0xFF6A9955);
  static const _synMethod   = Color(0xFFDCDCAA);
  static const _synPunct    = Color(0xFF858585);

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
      primary: _accent, onPrimary: Color(0xFF0B1220),
      secondary: _synKeyword, onSecondary: Color(0xFF0B1220),
      surface: _surface, onSurface: _textHi,
      surfaceContainerHighest: _surfaceHi,
      outline: _border, outlineVariant: _borderHi,
      error: _err, onError: Color(0xFF0B1220),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 48, color: _textHi),
      displayMedium: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 34, color: _textHi),
      headlineSmall: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 20, color: _textHi),
      titleMedium:   TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 14, color: _text),
      labelSmall:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 1.0, color: _textMute),
      bodyMedium:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 12, height: 1.45, color: _textHi),
      bodySmall:     TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 11, color: _text),
    ),
    dividerTheme: const DividerThemeData(color: _border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: _textDim, size: 14),
  );
}
