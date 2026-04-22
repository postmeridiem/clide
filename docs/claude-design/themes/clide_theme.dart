// clide_theme.dart
//
// Default theme for clide.
// Sampled from the Clide Web session dashboard — cool near-black canvas
// with a single periwinkle accent.
//
// Usage:
//   MaterialApp(theme: ClideTheme.data, ...)

import 'package:flutter/material.dart';

class ClideTheme {
  // ─── palette ──────────────────────────────────────────────────────────
  static const _bg          = Color(0xFF20202C); // page / editor canvas
  static const _bgSunken    = Color(0xFF1A1A24); // sidebar, gutters
  static const _surface     = Color(0xFF242838); // cards, table header, pills
  static const _surfaceHi   = Color(0xFF2C3046); // hover, selected row
  static const _border      = Color(0xFF343850);
  static const _borderHi    = Color(0xFF3C445C);

  static const _textHi      = Color(0xFFE6E8F2); // primary text
  static const _text        = Color(0xFFB1BBE3); // section titles, labels
  static const _textDim     = Color(0xFF78809C); // secondary
  static const _textMute    = Color(0xFF545C84); // small-caps labels

  static const _accent      = Color(0xFF78A0F8); // periwinkle primary
  static const _accentPress = Color(0xFF6C90DC);
  static const _accentSoft  = Color(0x2278A0F8); // 13% accent for fills

  static const _ok          = Color(0xFF7DD3A8);
  static const _warn        = Color(0xFFE6C370);
  static const _err         = Color(0xFFE87D7D);
  static const _info        = _accent;

  // syntax (Dart-biased)
  static const _synKeyword  = Color(0xFFC792EA); // class, const, final
  static const _synType     = Color(0xFF78A0F8); // Widget, BuildContext
  static const _synString   = Color(0xFFA8D99B);
  static const _synNumber   = Color(0xFFE6C370);
  static const _synComment  = Color(0xFF545C84);
  static const _synMethod   = Color(0xFF82B1FF);
  static const _synPunct    = Color(0xFF78809C);

  // ─── exposed tokens ───────────────────────────────────────────────────
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

  // ─── ThemeData ────────────────────────────────────────────────────────
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bg,
    canvasColor: _bg,

    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _accent,
      onPrimary: Color(0xFF0D1020),
      secondary: _synKeyword,
      onSecondary: Color(0xFF0D1020),
      surface: _surface,
      onSurface: _textHi,
      surfaceContainerHighest: _surfaceHi,
      outline: _border,
      outlineVariant: _borderHi,
      error: _err,
      onError: Color(0xFF0D1020),
    ),

    textTheme: const TextTheme(
      // Josefin Sans Light for display; JetBrains Mono for code/body.
      displayLarge:  TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 48, height: 1.1,  letterSpacing: 0.2, color: _textHi),
      displayMedium: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w300, fontSize: 34, height: 1.15, letterSpacing: 0.2, color: _textHi),
      headlineSmall: TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 20, height: 1.2,  letterSpacing: 0.2, color: _textHi),
      titleMedium:   TextStyle(fontFamily: 'Josefin Sans', fontWeight: FontWeight.w400, fontSize: 14, height: 1.3,  letterSpacing: 0.3, color: _text),
      labelSmall:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500, fontSize: 10, height: 1.2, letterSpacing: 1.0, color: _textMute),
      bodyMedium:    TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 12, height: 1.45, color: _textHi),
      bodySmall:     TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w400, fontSize: 11, height: 1.4,  color: _text),
    ),

    dividerTheme: const DividerThemeData(color: _border, thickness: 1, space: 1),

    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: _bgSunken,
      hintStyle: const TextStyle(color: _textMute),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: const Color(0xFF0D1020),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
      ),
    ),

    // Pill-style chips (matches the Projects row in the dashboard).
    chipTheme: ChipThemeData(
      backgroundColor: _surface,
      side: const BorderSide(color: _borderHi),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: _text),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),

    iconTheme: const IconThemeData(color: _textDim, size: 14),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: _surfaceHi,
        border: Border.all(color: _borderHi),
        borderRadius: BorderRadius.circular(3),
      ),
      textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: _textHi),
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(_border),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
    ),
  );
}

/// Raw color tokens — use when Material widgets can't carry the meaning.
class ClideTokens {
  const ClideTokens({
    required this.bg, required this.bgSunken,
    required this.surface, required this.surfaceHi,
    required this.border, required this.borderHi,
    required this.textHi, required this.text,
    required this.textDim, required this.textMute,
    required this.accent, required this.accentPress, required this.accentSoft,
    required this.ok, required this.warn, required this.err, required this.info,
    required this.synKeyword, required this.synType, required this.synString,
    required this.synNumber, required this.synComment,
    required this.synMethod, required this.synPunct,
  });
  final Color bg, bgSunken, surface, surfaceHi;
  final Color border, borderHi;
  final Color textHi, text, textDim, textMute;
  final Color accent, accentPress, accentSoft;
  final Color ok, warn, err, info;
  final Color synKeyword, synType, synString, synNumber, synComment, synMethod, synPunct;
}
