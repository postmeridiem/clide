import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ThemeResolver();

  Palette paletteOf(Map<String, Color> colors) => Palette(colors);

  group('ThemeResolver default fallbacks', () {
    test('design-shape palette resolves every token', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'bg': Color(0xFF20202C),
          'bgSunken': Color(0xFF1A1A24),
          'surface': Color(0xFF242838),
          'surfaceHi': Color(0xFF2C3046),
          'border': Color(0xFF343850),
          'borderHi': Color(0xFF3C445C),
          'textHi': Color(0xFFE6E8F2),
          'text': Color(0xFFB1BBE3),
          'textDim': Color(0xFF78809C),
          'textMute': Color(0xFF545C84),
          'accent': Color(0xFF78A0F8),
          'accentPress': Color(0xFF6C90DC),
          'accentSoft': Color(0x2178A0F8),
          'onAccent': Color(0xFF0D1020),
          'ok': Color(0xFF7DD3A8),
          'warn': Color(0xFFE6C370),
          'err': Color(0xFFE87D7D),
          'info': Color(0xFF78A0F8),
        }),
      );
      expect(tokens.globalBackground, const Color(0xFF20202C));
      expect(tokens.globalForeground, const Color(0xFFE6E8F2));
      expect(tokens.panelBackground, const Color(0xFF1A1A24));
      expect(tokens.sidebarItemSelected, const Color(0xFF2C3046));
      expect(tokens.statusSuccess, const Color(0xFF7DD3A8));
      expect(tokens.statusError, const Color(0xFFE87D7D));
      expect(tokens.globalTextMuted, const Color(0xFF78809C));
      expect(tokens.buttonBackground, const Color(0xFF78A0F8));
      expect(tokens.buttonForeground, const Color(0xFF0D1020));
    });

    test('legacy palette keys still resolve via fallback chains', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'primary': Color(0xFF00A3D2),
          'accent': Color(0xFFFA5F8B),
          'background': Color(0xFF21262F),
          'surface': Color(0xFF393E48),
          'panel': Color(0xFF292E38),
          'foreground': Color(0xFFE2E8F5),
          'muted': Color(0xFF6A7280),
          'success': Color(0xFF00AB9A),
          'warning': Color(0xFFD08447),
          'error': Color(0xFFF06C6F),
          'info': Color(0xFF00A3D2),
        }),
      );
      expect(tokens.globalBackground, const Color(0xFF21262F));
      expect(tokens.globalForeground, const Color(0xFFE2E8F5));
      expect(tokens.panelBackground, const Color(0xFF292E38));
      expect(tokens.statusSuccess, const Color(0xFF00AB9A));
      expect(tokens.statusError, const Color(0xFFF06C6F));
    });
  });

  group('ThemeResolver overrides', () {
    test('surface override wins over default', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'bg': Color(0xFF333333),
          'bgSunken': Color(0xFF222222),
          'surface': Color(0xFF444444),
          'border': Color(0xFF555555),
          'textHi': Color(0xFFFFFFFF),
          'accent': Color(0xFF111111),
          'ok': Color(0xFF008800),
          'warn': Color(0xFFFF8800),
          'err': Color(0xFFFF0000),
          'info': Color(0xFF111111),
        }),
        surfaceOverride: const {
          'panel.background': '#00FF00',
        },
      );
      expect(tokens.panelBackground, const Color(0xFF00FF00));
    });

    test('semantic override propagates when palette key is absent', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'bg': Color(0xFF333333),
          'bgSunken': Color(0xFF222222),
          'surface': Color(0xFF444444),
          'surfaceHi': Color(0xFF555555),
          'border': Color(0xFF666666),
          'textHi': Color(0xFFFFFFFF),
          'ok': Color(0xFF008800),
          'warn': Color(0xFFFF8800),
          'err': Color(0xFFFF0000),
          'info': Color(0xFF111111),
        }),
        semanticOverride: const SemanticRoles({
          'focus': Color(0xFF007777),
        }),
      );
      // No 'accent' in palette, so globalFocus falls through to
      // semantic.focus which is overridden.
      expect(tokens.globalFocus, const Color(0xFF007777));
    });

    test('extensionOverride populates extensionTokens map', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'bg': Color(0xFF333333),
          'bgSunken': Color(0xFF222222),
          'surface': Color(0xFF444444),
          'border': Color(0xFF555555),
          'textHi': Color(0xFFFFFFFF),
          'accent': Color(0xFF111111),
        }),
        extensionOverride: const {
          'ext.sqlite.table.background': '#ABCDEF',
        },
      );
      expect(tokens.extensionTokens['ext.sqlite.table.background'], const Color(0xFFABCDEF));
    });
  });

  group('Palette.parseHex', () {
    test('parses 6-digit hex as opaque', () {
      expect(Palette.parseHex('#112233'), const Color(0xFF112233));
    });
    test('parses 8-digit hex with alpha', () {
      expect(Palette.parseHex('#80112233'), const Color(0x80112233));
    });
    test('returns null on invalid', () {
      expect(Palette.parseHex('nope'), isNull);
      expect(Palette.parseHex('#12'), isNull);
    });
  });
}
