// paper_theme.dart
//
// Paper — carries the wireframe aesthetic into the product.
// Off-white drafting sheet, near-black ink, red-pencil accent for annotations.

import 'package:flutter/material.dart';
import 'clide_theme.dart' show ClideTokens;

class PaperTheme {
  static const _bg = Color(0xFFF4F1EA); // paper
  static const _bgSunken = Color(0xFFECE7DB); // paper-2
  static const _surface = Color(0xFFFBF8F1);
  static const _surfaceHi = Color(0xFFECE7DB);
  static const _border = Color(0xFF1A1A1A);
  static const _borderHi = Color(0xFF4A4A4A);

  static const _textHi = Color(0xFF1A1A1A); // ink
  static const _text = Color(0xFF4A4A4A); // ink-2
  static const _textDim = Color(0xFF8A8A82); // ink-3
  static const _textMute = Color(0xFFA8A89E);

  static const _accent = Color(0xFFC14B2A); // red pencil
  static const _accentPress = Color(0xFFA03D20);
  static const _accentSoft = Color(0x22C14B2A);

  static const _ok = Color(0xFF2D8A52);
  static const _warn = Color(0xFFB88A2A);
  static const _err = Color(0xFFB03A2A);
  static const _info = Color(0xFF2A6FC1);

  // Syntax tuned for cream paper — desaturated so code reads like print.
  static const _synKeyword = Color(0xFF7B3F8C);
  static const _synType = Color(0xFF2A6FC1);
  static const _synString = Color(0xFF2D8A52);
  static const _synNumber = Color(0xFFB88A2A);
  static const _synComment = Color(0xFF8A8A82);
  static const _synMethod = Color(0xFF1E5D9E);
  static const _synPunct = Color(0xFF4A4A4A);

  static const tokens = ClideTokens(
    bg: _bg,
    bgSunken: _bgSunken,
    surface: _surface,
    surfaceHi: _surfaceHi,
    border: _border,
    borderHi: _borderHi,
    textHi: _textHi,
    text: _text,
    textDim: _textDim,
    textMute: _textMute,
    accent: _accent,
    accentPress: _accentPress,
    accentSoft: _accentSoft,
    ok: _ok,
    warn: _warn,
    err: _err,
    info: _info,
    synKeyword: _synKeyword,
    synType: _synType,
    synString: _synString,
    synNumber: _synNumber,
    synComment: _synComment,
    synMethod: _synMethod,
    synPunct: _synPunct,
  );

  static ThemeData get data => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bg,
        canvasColor: _bg,
        colorScheme: const ColorScheme.light(
          primary: _accent,
          onPrimary: Color(0xFFFBF8F1),
          secondary: _info,
          onSecondary: Color(0xFFFBF8F1),
          surface: _surface,
          onSurface: _textHi,
          surfaceContainerHighest: _surfaceHi,
          outline: _border,
          outlineVariant: _borderHi,
          error: _err,
          onError: Color(0xFFFBF8F1),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 48, color: _textHi),
          displayMedium: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 34, color: _textHi),
          headlineSmall: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 20, color: _textHi),
          titleMedium: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 14, color: _text),
          labelSmall: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: 1.0, color: _textDim),
          bodyMedium: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 12, height: 1.45, color: _textHi),
          bodySmall: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 11, color: _text),
        ),
        dividerTheme: const DividerThemeData(color: _border, thickness: 1, space: 1),
        iconTheme: const IconThemeData(color: _text, size: 14),
      );
}
