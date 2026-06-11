/// Pure-Dart tests for `lib/src/terminal/src/ui/` files that don't
/// require a Flutter widget harness — palette construction, paragraph
/// cache, text style, key/char mapping, controller state machine,
/// small enums + value classes, char-metrics and theme constants.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clide/src/terminal/src/core/buffer/cell_offset.dart';
import 'package:clide/src/terminal/src/core/buffer/line.dart';
import 'package:clide/src/terminal/src/core/buffer/range_block.dart';
import 'package:clide/src/terminal/src/core/buffer/range_line.dart';
import 'package:clide/src/terminal/src/core/input/keys.dart';
import 'package:clide/src/terminal/src/utils/circular_buffer.dart';
import 'package:clide/src/terminal/src/ui/char_metrics.dart';
import 'package:clide/src/terminal/src/ui/controller.dart';
import 'package:clide/src/terminal/src/ui/cursor_type.dart';
import 'package:clide/src/terminal/src/ui/input_map.dart';
import 'package:clide/src/terminal/src/ui/palette_builder.dart';
import 'package:clide/src/terminal/src/ui/paragraph_cache.dart';
import 'package:clide/src/terminal/src/ui/pointer_input.dart';
import 'package:clide/src/terminal/src/ui/selection_mode.dart';
import 'package:clide/src/terminal/src/ui/terminal_size.dart';
import 'package:clide/src/terminal/src/ui/terminal_text_style.dart';
import 'package:clide/src/terminal/src/ui/themes.dart';

void main() {
  group('PaletteBuilder', () {
    final builder = PaletteBuilder(TerminalThemes.defaultTheme);

    test('build() returns exactly 256 colors', () {
      final palette = builder.build();
      expect(palette, hasLength(256));
    });

    test('first 16 indices map directly to the named theme colors', () {
      expect(builder.paletteColor(0), TerminalThemes.defaultTheme.black);
      expect(builder.paletteColor(1), TerminalThemes.defaultTheme.red);
      expect(builder.paletteColor(2), TerminalThemes.defaultTheme.green);
      expect(builder.paletteColor(3), TerminalThemes.defaultTheme.yellow);
      expect(builder.paletteColor(4), TerminalThemes.defaultTheme.blue);
      expect(builder.paletteColor(5), TerminalThemes.defaultTheme.magenta);
      expect(builder.paletteColor(6), TerminalThemes.defaultTheme.cyan);
      expect(builder.paletteColor(7), TerminalThemes.defaultTheme.white);
      expect(builder.paletteColor(8), TerminalThemes.defaultTheme.brightBlack);
      expect(builder.paletteColor(9), TerminalThemes.defaultTheme.brightRed);
      expect(builder.paletteColor(10), TerminalThemes.defaultTheme.brightGreen);
      expect(builder.paletteColor(11), TerminalThemes.defaultTheme.brightYellow);
      expect(builder.paletteColor(12), TerminalThemes.defaultTheme.brightBlue);
      expect(builder.paletteColor(13), TerminalThemes.defaultTheme.brightMagenta);
      expect(builder.paletteColor(14), TerminalThemes.defaultTheme.brightCyan);
      expect(builder.paletteColor(15), TerminalThemes.defaultTheme.white);
    });

    test('index 16 is the start of the 6×6×6 RGB cube — pure black at (0,0,0)', () {
      // The cube starts with r=g=b=0 and walks the b-axis first by 95, then 40.
      expect(builder.paletteColor(16), const Color.fromARGB(0xFF, 0, 0, 0));
    });

    test('cube walks blue → green → red, with first step 95 and subsequent +40', () {
      // Index 17: b becomes 95.
      expect(builder.paletteColor(17), const Color.fromARGB(0xFF, 0, 0, 95));
      // Index 18: b += 40 → 135.
      expect(builder.paletteColor(18), const Color.fromARGB(0xFF, 0, 0, 135));
    });

    test('231 is the cube terminus — pure white-ish corner', () {
      // After a full 6-step walk on each axis, the 6³ cube ends at (255,255,255).
      expect(builder.paletteColor(231), const Color.fromARGB(0xFF, 255, 255, 255));
    });

    test('grayscale ramp at 232..255', () {
      expect(builder.paletteColor(232), const Color(0xff080808));
      expect(builder.paletteColor(255), const Color(0xffeeeeee));
    });

    test('out-of-range indices clamp to grayscale endpoints', () {
      // The implementation falls through to grayscale with clamp(232, 255).
      expect(builder.paletteColor(999), const Color(0xffeeeeee));
    });
  });

  group('ParagraphCache', () {
    test('caches and retrieves a paragraph by integer key', () {
      final cache = ParagraphCache(8);
      const style = TextStyle(fontSize: 14);
      final p = cache.performAndCacheLayout('a', style, TextScaler.noScaling, 1);
      expect(cache.getLayoutFromCache(1), same(p));
      expect(cache.length, 1);
    });

    test('moves recently-accessed entries to the end (LRU promotion)', () {
      final cache = ParagraphCache(2);
      const style = TextStyle(fontSize: 14);
      cache.performAndCacheLayout('a', style, TextScaler.noScaling, 1);
      cache.performAndCacheLayout('b', style, TextScaler.noScaling, 2);
      // Touch key 1 — promotes it.
      cache.getLayoutFromCache(1);
      // Inserting a third entry evicts the LRU (key 2).
      cache.performAndCacheLayout('c', style, TextScaler.noScaling, 3);
      expect(cache.getLayoutFromCache(1), isNotNull);
      expect(cache.getLayoutFromCache(2), isNull);
      expect(cache.getLayoutFromCache(3), isNotNull);
    });

    test('clear empties the cache', () {
      final cache = ParagraphCache(4);
      const style = TextStyle(fontSize: 14);
      cache.performAndCacheLayout('a', style, TextScaler.noScaling, 1);
      expect(cache.length, 1);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.getLayoutFromCache(1), isNull);
    });

    test('miss on a never-set key returns null', () {
      final cache = ParagraphCache(2);
      expect(cache.getLayoutFromCache(99), isNull);
    });
  });

  group('TerminalStyle', () {
    test('default constructor uses the documented defaults', () {
      const s = TerminalStyle();
      expect(s.fontSize, 13.0);
      expect(s.height, 1.2);
      expect(s.fontFamily, 'monospace');
      expect(s.fontFamilyFallback, contains('Menlo'));
    });

    test('fromTextStyle picks fontFamily, falling back through fontFamilyFallback', () {
      final s1 = TerminalStyle.fromTextStyle(const TextStyle(fontFamily: 'Hack'));
      expect(s1.fontFamily, 'Hack');

      final s2 = TerminalStyle.fromTextStyle(const TextStyle(fontFamilyFallback: ['Mono', 'Courier']));
      expect(s2.fontFamily, 'Mono');

      final s3 = TerminalStyle.fromTextStyle(const TextStyle());
      expect(s3.fontFamily, 'monospace');
    });

    test('fromTextStyle picks fontSize / height / fontFamilyFallback through to TerminalStyle', () {
      final s = TerminalStyle.fromTextStyle(const TextStyle(fontSize: 18, height: 1.5, fontFamilyFallback: ['Mono']));
      expect(s.fontSize, 18);
      expect(s.height, 1.5);
      expect(s.fontFamilyFallback, ['Mono']);
    });

    test('toTextStyle threads attribute flags into the resulting TextStyle', () {
      const s = TerminalStyle(fontSize: 16);
      final t = s.toTextStyle(color: const Color(0xFF112233), bold: true, italic: true, underline: true);
      expect(t.fontSize, 16);
      expect(t.fontWeight, FontWeight.bold);
      expect(t.fontStyle, FontStyle.italic);
      expect(t.decoration, TextDecoration.underline);
      expect(t.color, const Color(0xFF112233));
    });

    test('copyWith overrides only specified fields', () {
      const s = TerminalStyle(fontSize: 14);
      final copied = s.copyWith(fontSize: 20);
      expect(copied.fontSize, 20);
      expect(copied.fontFamily, s.fontFamily); // unchanged
    });

    test('copyWith with no arguments returns a value-equal clone', () {
      // Hits the `?? this.X` right-hand side for every parameter.
      const s = TerminalStyle(fontSize: 14);
      final clone = s.copyWith();
      expect(clone.fontSize, s.fontSize);
      expect(clone.height, s.height);
      expect(clone.fontFamily, s.fontFamily);
      expect(clone.fontFamilyFallback, s.fontFamilyFallback);
    });
  });

  group('input_map', () {
    test('keyToTerminalKey maps logical keys 1:1', () {
      expect(keyToTerminalKey(LogicalKeyboardKey.arrowUp), TerminalKey.arrowUp);
      expect(keyToTerminalKey(LogicalKeyboardKey.keyA), TerminalKey.keyA);
      expect(keyToTerminalKey(LogicalKeyboardKey.escape), TerminalKey.escape);
    });

    test('keyToTerminalKey returns null for an unmapped logical key', () {
      // gameButtonStart is mapped; pick something that is not — there's no
      // TerminalKey for `LogicalKeyboardKey.colon`, etc. Verify by walking
      // a synthesized key id.
      const synthetic = LogicalKeyboardKey(0xDEADBEEF);
      expect(keyToTerminalKey(synthetic), isNull);
    });

    test('charToTerminalKey maps a single ASCII char (case-insensitive)', () {
      expect(charToTerminalKey('a'), TerminalKey.keyA);
      expect(charToTerminalKey('A'), TerminalKey.keyA);
      expect(charToTerminalKey('1'), TerminalKey.digit1);
    });

    test('charToTerminalKey returns null for multi-char strings or unknown chars', () {
      expect(charToTerminalKey('ab'), isNull);
      expect(charToTerminalKey(''), isNull);
      // Some printable characters don't have keytab mappings (e.g. ¥ ñ).
      expect(charToTerminalKey('¥'), isNull);
    });
  });

  group('TerminalSize', () {
    test('value semantics — operator== / hashCode / toString', () {
      const a = TerminalSize(80, 24);
      const b = TerminalSize(80, 24);
      const c = TerminalSize(100, 24);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), 'TerminalSize(80, 24)');
      // identity branch
      expect(identical(a, a), isTrue);
      // type-mismatch branch (typed Object so we don't trip the unrelated lint)
      const Object notASize = 'not a size';
      expect(a == notASize, isFalse);
    });
  });

  group('PointerInputs', () {
    test('default constructor wraps the supplied set', () {
      const p = PointerInputs({PointerInput.tap, PointerInput.drag});
      expect(p.inputs, {PointerInput.tap, PointerInput.drag});
    });

    test('.none() is empty; .all() contains every PointerInput value', () {
      expect(const PointerInputs.none().inputs, isEmpty);
      expect(const PointerInputs.all().inputs, PointerInput.values.toSet());
    });
  });

  group('SelectionMode + TerminalCursorType enums', () {
    test('all enum values exist and are distinct', () {
      expect(SelectionMode.values, [SelectionMode.line, SelectionMode.block]);
      expect(TerminalCursorType.values, [TerminalCursorType.block, TerminalCursorType.underline, TerminalCursorType.verticalBar]);
    });
  });

  group('TerminalThemes (bundled themes are well-formed)', () {
    test('defaultTheme exposes the documented core palette', () {
      const t = TerminalThemes.defaultTheme;
      expect(t.foreground, const Color(0XFFCCCCCC));
      expect(t.background, const Color(0XFF1E1E1E));
      expect(t.brightWhite, const Color(0XFFFFFFFF));
    });

    test('whiteOnBlack and any other bundled themes are valid TerminalTheme instances', () {
      // Touch every static field that PaletteBuilder needs so that any
      // missing field would surface as an error here, before runtime.
      const t = TerminalThemes.whiteOnBlack;
      final palette = PaletteBuilder(t).build();
      expect(palette, hasLength(256));
    });
  });

  group('calcCharSize (char_metrics)', () {
    test('returns positive-width / positive-height for a default style', () {
      const style = TerminalStyle();
      final size = calcCharSize(style, TextScaler.noScaling);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test('text-scaler scales the size monotonically', () {
      const style = TerminalStyle();
      final small = calcCharSize(style, const TextScaler.linear(1.0));
      final big = calcCharSize(style, const TextScaler.linear(2.0));
      expect(big.width, greaterThan(small.width));
      expect(big.height, greaterThan(small.height));
    });
  });

  group('TerminalController', () {
    test('default state: no selection, no highlights, line mode, tap-only inputs', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      expect(c.selection, isNull);
      expect(c.highlights, isEmpty);
      expect(c.selectionMode, SelectionMode.line);
      expect(c.suspendedPointerInputs, isFalse);
      expect(c.pointerInput.inputs, {PointerInput.tap});
    });

    test('setSelection records anchors and notifies listeners', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      var notifs = 0;
      c.addListener(() => notifs++);

      // Build a pair of attached anchors via a ring + line.
      final ring = IndexAwareCircularBuffer<BufferLine>(4);
      final line = BufferLine(8);
      ring.push(line);
      final base = line.createAnchor(0);
      final extent = line.createAnchor(2);

      c.setSelection(base, extent);
      expect(notifs, 1);
      expect(c.selection, isA<BufferRangeLine>());
      expect(c.selection!.begin, const CellOffset(0, 0));
      expect(c.selection!.end, const CellOffset(2, 0));
    });

    test('setSelection mode override switches to block range', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      final ring = IndexAwareCircularBuffer<BufferLine>(4);
      final line = BufferLine(8);
      ring.push(line);
      final base = line.createAnchor(0);
      final extent = line.createAnchor(3);
      c.setSelection(base, extent, mode: SelectionMode.block);
      expect(c.selectionMode, SelectionMode.block);
      expect(c.selection, isA<BufferRangeBlock>());
    });

    test('selection getter returns null when an anchor is detached', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      // Anchors not attached to a circular buffer are detached by definition.
      final detachedLine = BufferLine(8);
      final base = detachedLine.createAnchor(0);
      final extent = detachedLine.createAnchor(2);
      c.setSelection(base, extent);
      expect(c.selection, isNull);
    });

    test('setSelection a second time disposes the previous anchors', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      final ring = IndexAwareCircularBuffer<BufferLine>(4);
      final line = BufferLine(8);
      ring.push(line);
      final base1 = line.createAnchor(0);
      final extent1 = line.createAnchor(2);
      c.setSelection(base1, extent1);
      expect(line.anchors.length, 2);

      // Replace with new anchors — old ones should be dropped from the line.
      final base2 = line.createAnchor(3);
      final extent2 = line.createAnchor(5);
      c.setSelection(base2, extent2);
      expect(line.anchors.length, 2);
      expect(line.anchors.contains(base2), isTrue);
      expect(line.anchors.contains(extent2), isTrue);
      expect(line.anchors.contains(base1), isFalse);
    });

    test('setSelectionMode is a no-op when the new mode equals the old', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      var notifs = 0;
      c.addListener(() => notifs++);
      c.setSelectionMode(SelectionMode.line); // same as default
      expect(notifs, 0);
      c.setSelectionMode(SelectionMode.block);
      expect(notifs, 1);
      expect(c.selectionMode, SelectionMode.block);
    });

    test('clearSelection drops anchors and notifies', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      final ring = IndexAwareCircularBuffer<BufferLine>(4);
      final line = BufferLine(8);
      ring.push(line);
      c.setSelection(line.createAnchor(0), line.createAnchor(2));
      var notifs = 0;
      c.addListener(() => notifs++);
      c.clearSelection();
      expect(c.selection, isNull);
      expect(notifs, 1);
    });

    test('setPointerInputs and setSuspendPointerInput notify and update the gate', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      var notifs = 0;
      c.addListener(() => notifs++);

      c.setPointerInputs(const PointerInputs({PointerInput.scroll, PointerInput.drag}));
      expect(notifs, 1);
      expect(c.shouldSendPointerInput(PointerInput.scroll), isTrue);
      expect(c.shouldSendPointerInput(PointerInput.tap), isFalse);

      c.setSuspendPointerInput(true);
      expect(c.suspendedPointerInputs, isTrue);
      expect(notifs, 2);
      // Suspended → all queries return false even if the input is in the set.
      expect(c.shouldSendPointerInput(PointerInput.scroll), isFalse);
    });

    test('highlight registers + auto-removes via Disposable', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      final ring = IndexAwareCircularBuffer<BufferLine>(4);
      final line = BufferLine(8);
      ring.push(line);
      final p1 = line.createAnchor(0);
      final p2 = line.createAnchor(3);

      final h = c.highlight(p1: p1, p2: p2, color: const Color(0xFF112233));
      expect(c.highlights, contains(h));
      // Range from highlight resolves to the same span via attached anchors.
      expect(h.range, isA<BufferRangeLine>());

      h.dispose();
      expect(c.highlights, isNot(contains(h)));
    });

    test('TerminalHighlight.range returns null when its anchors are detached', () {
      final c = TerminalController();
      addTearDown(c.dispose);
      // Anchors on a non-attached line.
      final freeLine = BufferLine(8);
      final p1 = freeLine.createAnchor(0);
      final p2 = freeLine.createAnchor(2);
      final h = c.highlight(p1: p1, p2: p2, color: const Color(0xFFAA0000));
      expect(h.range, isNull);
    });
  });
}
