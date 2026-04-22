// clide_tokens.dart
//
// Raw token values for the four default clide themes — framework-free.
// No Material, no Cupertino, no ThemeData. Just colors, organized into a
// flat palette + syntax block. Wire these into your theme pipeline
// (YAML palette -> semantic roles -> surface tokens).
//
// Mirror of bundle/tokens/*.yaml · keep them in sync.

import 'dart:ui' show Color;

class ClideTheme {
  const ClideTheme({
    required this.name,
    required this.dark,
    required this.subtitle,
    required this.palette,
    required this.syntax,
  });
  final String name;
  final bool dark;
  final String subtitle;
  final ClidePalette palette;
  final ClideSyntax syntax;
}

class ClidePalette {
  const ClidePalette({
    required this.bg,
    required this.bgSunken,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.borderHi,
    required this.textHi,
    required this.text,
    required this.textDim,
    required this.textMute,
    required this.accent,
    required this.accentPress,
    required this.accentSoft,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.err,
    required this.info,
  });
  final Color bg, bgSunken, surface, surfaceHi;
  final Color border, borderHi;
  final Color textHi, text, textDim, textMute;
  final Color accent, accentPress, accentSoft, onAccent;
  final Color ok, warn, err, info;
}

class ClideSyntax {
  const ClideSyntax({
    required this.keyword,
    required this.type,
    required this.string,
    required this.number,
    required this.comment,
    required this.method,
    required this.punct,
  });
  final Color keyword, type, string, number, comment, method, punct;
}

class ClideThemes {
  // ─── clide ───────────────────────────────────────────────────────
  static const clide = ClideTheme(
    name: 'clide',
    dark: true,
    subtitle: 'cool near-black + periwinkle · default',
    palette: ClidePalette(
      bg:          Color(0xFF20202C),
      bgSunken:    Color(0xFF1A1A24),
      surface:     Color(0xFF242838),
      surfaceHi:   Color(0xFF2C3046),
      border:      Color(0xFF343850),
      borderHi:    Color(0xFF3C445C),
      textHi:      Color(0xFFE6E8F2),
      text:        Color(0xFFB1BBE3),
      textDim:     Color(0xFF78809C),
      textMute:    Color(0xFF545C84),
      accent:      Color(0xFF78A0F8),
      accentPress: Color(0xFF6C90DC),
      accentSoft:  Color(0x2178A0F8),
      onAccent:    Color(0xFF0D1020),
      ok:          Color(0xFF7DD3A8),
      warn:        Color(0xFFE6C370),
      err:         Color(0xFFE87D7D),
      info:        Color(0xFF78A0F8),
    ),
    syntax: ClideSyntax(
      keyword:  Color(0xFFC792EA),
      type:     Color(0xFF78A0F8),
      string:   Color(0xFFA8D99B),
      number:   Color(0xFFE6C370),
      comment:  Color(0xFF545C84),
      method:   Color(0xFF82B1FF),
      punct:    Color(0xFF78809C),
    ),
  );

  // ─── midnight ────────────────────────────────────────────────────
  static const midnight = ClideTheme(
    name: 'midnight',
    dark: true,
    subtitle: 'VS Code-adjacent muted dark',
    palette: ClidePalette(
      bg:          Color(0xFF1E1E1E),
      bgSunken:    Color(0xFF181818),
      surface:     Color(0xFF252526),
      surfaceHi:   Color(0xFF2D2D2E),
      border:      Color(0xFF333333),
      borderHi:    Color(0xFF3F3F3F),
      textHi:      Color(0xFFD4D4D4),
      text:        Color(0xFFBBBBBB),
      textDim:     Color(0xFF858585),
      textMute:    Color(0xFF6A6A6A),
      accent:      Color(0xFF569CD6),
      accentPress: Color(0xFF4785BD),
      accentSoft:  Color(0x21569CD6),
      onAccent:    Color(0xFF0B1220),
      ok:          Color(0xFF89D185),
      warn:        Color(0xFFD7BA7D),
      err:         Color(0xFFF48771),
      info:        Color(0xFF569CD6),
    ),
    syntax: ClideSyntax(
      keyword:  Color(0xFFC586C0),
      type:     Color(0xFF4EC9B0),
      string:   Color(0xFFCE9178),
      number:   Color(0xFFB5CEA8),
      comment:  Color(0xFF6A9955),
      method:   Color(0xFFDCDCAA),
      punct:    Color(0xFF858585),
    ),
  );

  // ─── paper ───────────────────────────────────────────────────────
  static const paper = ClideTheme(
    name: 'paper',
    dark: false,
    subtitle: 'drafting sheet · red-pencil accent · light',
    palette: ClidePalette(
      bg:          Color(0xFFF4F1EA),
      bgSunken:    Color(0xFFECE7DB),
      surface:     Color(0xFFFBF8F1),
      surfaceHi:   Color(0xFFECE7DB),
      border:      Color(0xFF1A1A1A),
      borderHi:    Color(0xFF4A4A4A),
      textHi:      Color(0xFF1A1A1A),
      text:        Color(0xFF4A4A4A),
      textDim:     Color(0xFF8A8A82),
      textMute:    Color(0xFFA8A89E),
      accent:      Color(0xFFC14B2A),
      accentPress: Color(0xFFA03D20),
      accentSoft:  Color(0x21C14B2A),
      onAccent:    Color(0xFFFBF8F1),
      ok:          Color(0xFF2D8A52),
      warn:        Color(0xFFB88A2A),
      err:         Color(0xFFB03A2A),
      info:        Color(0xFF2A6FC1),
    ),
    syntax: ClideSyntax(
      keyword:  Color(0xFF7B3F8C),
      type:     Color(0xFF2A6FC1),
      string:   Color(0xFF2D8A52),
      number:   Color(0xFFB88A2A),
      comment:  Color(0xFF8A8A82),
      method:   Color(0xFF1E5D9E),
      punct:    Color(0xFF4A4A4A),
    ),
  );

  // ─── terminal ────────────────────────────────────────────────────
  static const terminal = ClideTheme(
    name: 'terminal',
    dark: true,
    subtitle: 'near-black + amber · tmux feel',
    palette: ClidePalette(
      bg:          Color(0xFF0A0A0A),
      bgSunken:    Color(0xFF000000),
      surface:     Color(0xFF111111),
      surfaceHi:   Color(0xFF181818),
      border:      Color(0xFF242424),
      borderHi:    Color(0xFF2E2E2E),
      textHi:      Color(0xFFE6E6E6),
      text:        Color(0xFFBDBDBD),
      textDim:     Color(0xFF7A7A7A),
      textMute:    Color(0xFF4A4A4A),
      accent:      Color(0xFFE0B050),
      accentPress: Color(0xFFC29438),
      accentSoft:  Color(0x21E0B050),
      onAccent:    Color(0xFF000000),
      ok:          Color(0xFF8FDC9B),
      warn:        Color(0xFFE0B050),
      err:         Color(0xFFE05050),
      info:        Color(0xFFA3C4FF),
    ),
    syntax: ClideSyntax(
      keyword:  Color(0xFFE05050),
      type:     Color(0xFFE0B050),
      string:   Color(0xFF8FDC9B),
      number:   Color(0xFFC792EA),
      comment:  Color(0xFF4A4A4A),
      method:   Color(0xFFA3C4FF),
      punct:    Color(0xFF7A7A7A),
    ),
  );

  static const all = [clide, midnight, paper, terminal];
  static const defaultTheme = clide;
}
