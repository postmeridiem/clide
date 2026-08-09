import 'package:clide/builtin/clide_companion/src/glyph_cache.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _mono = 'JetBrainsMono';
const _white = Color(0xFFFFFFFF);
const _grey = Color(0xFF8890AC);

void main() {
  // ui.Paragraph needs the engine, so this runs under flutter_test rather than
  // dart test — unlike the rest of the companion's pure-Dart units.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reuse — the point of the class', () {
    test('the same request returns the identical paragraph instance', () {
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      expect(identical(a, b), isTrue, reason: 'paragraph was laid out twice for identical input');
      expect(cache.length, 1);
    });

    test('repeated requests across many frames add no entries', () {
      // The load case: ~80 cells a frame at 30fps. If this grew, the widget
      // would be laying out thousands of paragraphs a second.
      final cache = GlyphCache();
      const glyphs = ['0', '1', 'A', r'$', '│', '╷', '┼', '▪'];
      for (var frame = 0; frame < 200; frame++) {
        for (final g in glyphs) {
          cache.paragraph(g, color: _white, fontSize: 14, fontFamily: _mono);
        }
      }
      expect(cache.length, glyphs.length, reason: 'cache grew across frames: ${cache.length}');
    });
  });

  group('the key covers everything that changes the pixels', () {
    test('a different glyph is a different entry', () {
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('1', color: _white, fontSize: 14, fontFamily: _mono);
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a colour change is a different entry, not a stale hit', () {
      // Theme switch. If colour were not in the key this would silently keep
      // painting the old theme's colour until something cleared the cache.
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('0', color: _grey, fontSize: 14, fontFamily: _mono);
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a font-size change is a different entry', () {
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('0', color: _white, fontSize: 20, fontFamily: _mono);
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a font-family change is a different entry', () {
      // The mono face is user-selectable (D-101), so this is a live runtime
      // switch, not a build-time constant.
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: 'FiraMono');
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a fallback-list change is a different entry', () {
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono, fontFamilyFallback: const ['FiraMono']);
      final b = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono, fontFamilyFallback: const ['Inter']);
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a text-scale change is a different entry', () {
      final cache = GlyphCache();
      final a = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final b = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono, textScaler: const TextScaler.linear(2));
      expect(identical(a, b), isFalse);
      expect(cache.length, 2);
    });

    test('a null fallback and an empty fallback are distinguished', () {
      // Guards the null-vs-hashAll branch in the key.
      final cache = GlyphCache();
      cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono, fontFamilyFallback: const []);
      expect(cache.length, 2);
    });
  });

  group('bounded growth', () {
    test('the LRU evicts rather than growing without limit', () {
      final cache = GlyphCache(maximumSize: 8);
      for (var i = 0; i < 200; i++) {
        cache.paragraph(String.fromCharCode(0x30 + (i % 10)), color: Color(0xFF000000 + i), fontSize: 14, fontFamily: _mono);
      }
      expect(cache.length, lessThanOrEqualTo(8));
    });

    test('the default size comfortably holds the working set', () {
      // 42 rain glyphs plus the face glyphs, across a handful of token colours
      // and two sizes — sizing it too small is the only real failure mode.
      final cache = GlyphCache();
      for (var g = 0; g < 60; g++) {
        for (final c in const [_white, _grey, Color(0xFF37FF8B)]) {
          cache.paragraph(String.fromCharCode(0x30 + g), color: c, fontSize: 14, fontFamily: _mono);
        }
      }
      expect(cache.length, 180, reason: 'working set was evicted at default size');
    });
  });

  group('metrics', () {
    test('reports a positive cell size', () {
      final cache = GlyphCache();
      final m = cache.metrics(fontSize: 14, fontFamily: _mono);
      expect(m.width, greaterThan(0));
      expect(m.height, greaterThan(0));
    });

    test('measuring reuses the cache rather than laying out fresh each call', () {
      final cache = GlyphCache();
      cache.metrics(fontSize: 14, fontFamily: _mono);
      final after = cache.length;
      cache.metrics(fontSize: 14, fontFamily: _mono);
      expect(cache.length, after, reason: 'metrics() added an entry on a repeat call');
    });

    test('a larger font measures larger', () {
      final cache = GlyphCache();
      final small = cache.metrics(fontSize: 10, fontFamily: _mono);
      final large = cache.metrics(fontSize: 20, fontFamily: _mono);
      expect(large.width, greaterThan(small.width));
      expect(large.height, greaterThan(small.height));
    });
  });

  group('clear', () {
    test('drops every entry', () {
      final cache = GlyphCache();
      cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      cache.paragraph('1', color: _white, fontSize: 14, fontFamily: _mono);
      expect(cache.length, 2);
      cache.clear();
      expect(cache.length, 0);
    });

    test('is memory hygiene, not a correctness requirement', () {
      // Style is in the key, so a theme switch WITHOUT a clear must still
      // produce the new colour. This is the property that makes forgetting to
      // clear a memory issue rather than a rendering bug.
      final cache = GlyphCache();
      final before = cache.paragraph('0', color: _white, fontSize: 14, fontFamily: _mono);
      final afterThemeSwitch = cache.paragraph('0', color: _grey, fontSize: 14, fontFamily: _mono);
      expect(identical(before, afterThemeSwitch), isFalse);
    });
  });
}
