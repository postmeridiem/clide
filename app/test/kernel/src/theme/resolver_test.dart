import 'dart:ui';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ThemeResolver();

  Palette paletteOf(Map<String, Color> colors) => Palette(colors);

  group('ThemeResolver default fallbacks', () {
    test('palette-only summer-night shape resolves every token', () {
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
      expect(tokens.sidebarItemSelected, const Color(0xFF00A3D2));
      expect(tokens.statusSuccess, const Color(0xFF00AB9A));
      expect(tokens.statusError, const Color(0xFFF06C6F));
      expect(tokens.globalTextMuted, const Color(0xFF6A7280));
    });

    test('missing "muted" falls back to foreground', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'primary': Color(0xFF111111),
          'accent': Color(0xFF222222),
          'background': Color(0xFF333333),
          'surface': Color(0xFF444444),
          'panel': Color(0xFF555555),
          'foreground': Color(0xFFEEEEEE),
          'success': Color(0xFF008800),
          'warning': Color(0xFFFF8800),
          'error': Color(0xFFFF0000),
        }),
      );
      expect(tokens.globalTextMuted, const Color(0xFFEEEEEE));
    });
  });

  group('ThemeResolver overrides', () {
    test('surface override wins over default', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'primary': Color(0xFF111111),
          'accent': Color(0xFF222222),
          'background': Color(0xFF333333),
          'surface': Color(0xFF444444),
          'panel': Color(0xFF555555),
          'foreground': Color(0xFFFFFFFF),
          'success': Color(0xFF008800),
          'warning': Color(0xFFFF8800),
          'error': Color(0xFFFF0000),
        }),
        surfaceOverride: const {
          'panel.background': '#00FF00',
        },
      );
      expect(tokens.panelBackground, const Color(0xFF00FF00));
    });

    test('semantic override propagates to surface tokens using it', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'primary': Color(0xFF111111),
          'accent': Color(0xFF222222),
          'background': Color(0xFF333333),
          'surface': Color(0xFF444444),
          'panel': Color(0xFF555555),
          'foreground': Color(0xFFFFFFFF),
          'success': Color(0xFF008800),
          'warning': Color(0xFFFF8800),
          'error': Color(0xFFFF0000),
          'teal': Color(0xFF007777),
        }),
        semanticOverride: const SemanticRoles({
          'focus': Color(0xFF007777),
        }),
      );
      // sidebarItemSelected defaults to semantic.focus — expect override.
      expect(tokens.sidebarItemSelected, const Color(0xFF007777));
    });

    test('extensionOverride populates extensionTokens map', () {
      final tokens = resolver.resolve(
        palette: paletteOf(const {
          'primary': Color(0xFF111111),
          'background': Color(0xFF333333),
          'surface': Color(0xFF444444),
          'panel': Color(0xFF555555),
          'foreground': Color(0xFFFFFFFF),
        }),
        extensionOverride: const {
          'ext.sqlite.table.background': '#ABCDEF',
        },
      );
      expect(tokens.extensionTokens['ext.sqlite.table.background'],
          const Color(0xFFABCDEF));
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
