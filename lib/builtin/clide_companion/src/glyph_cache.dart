/// Glyph paragraph cache for the Clide companion face (T-523).
///
/// One `ui.Paragraph` per distinct (glyph, colour, size, font) tuple, reused
/// across every particle and every frame. At `effort` density the field draws
/// ~80 cells per frame at 30fps; laying out a `TextPainter` per cell per frame
/// would be ~2400 layouts a second for a decorative widget.
///
/// Both existing painters (`graph_painter.dart:121`, `canvas_painter.dart:214`)
/// do allocate a `TextPainter` per paint. That is correct for a static painter
/// that repaints on interaction and wrong for a continuous animation — this is
/// deliberately not modelled on them.
///
/// Wraps `ParagraphCache` from the terminal subsystem rather than duplicating
/// its LRU. See the note on [GlyphCache] for why it is imported rather than
/// lifted, and why the key is built with `Object.hash` rather than the XOR the
/// terminal painter uses.
library;

import 'dart:ui' as ui;

import 'package:clide/src/terminal/src/ui/paragraph_cache.dart';
import 'package:flutter/widgets.dart';

/// Laid-out size of a single glyph cell.
typedef GlyphMetrics = ({double width, double height});

/// An LRU of laid-out single-glyph paragraphs.
///
/// **Imported, not lifted.** `ParagraphCache` lives at
/// `lib/src/terminal/src/ui/paragraph_cache.dart` and is used by the terminal
/// painter. Importing it across subsystem lines is the smaller evil than a
/// second copy of the same LRU; if a third consumer appears it should be lifted
/// somewhere shared and both updated. (Code under `lib/` is owned, not vendored,
/// so moving it is allowed — the xterm.dart credit in its header travels with
/// it either way.)
///
/// **Correctness does not depend on clearing.** Every input that changes the
/// rendered pixels — glyph, colour, size, font family and fallback, text scale —
/// is part of the key, so a theme or font switch simply misses and lays out
/// fresh; it can never return a stale paragraph. [clear] therefore exists to
/// release memory, not to preserve correctness, which makes forgetting to call
/// it a memory issue rather than a rendering bug.
class GlyphCache {
  GlyphCache({int maximumSize = 512}) : _cache = ParagraphCache(maximumSize);

  final ParagraphCache _cache;

  /// Entries currently held. Exposed for tests and diagnostics.
  int get length => _cache.length;

  /// A laid-out paragraph for [glyph] in the given style.
  ///
  /// Repeated calls with identical arguments return the *identical* instance —
  /// that reuse is the entire point of this class.
  ui.Paragraph paragraph(
    String glyph, {
    required Color color,
    required double fontSize,
    required String fontFamily,
    List<String>? fontFamilyFallback,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    // Object.hash, not the XOR the terminal painter uses. XOR of two hashes
    // collides readily on structured inputs, and a collision here does not
    // degrade — it silently draws the wrong glyph or the wrong colour.
    final key = Object.hash(glyph, color, fontSize, fontFamily, fontFamilyFallback == null ? null : Object.hashAll(fontFamilyFallback), textScaler);

    final hit = _cache.getLayoutFromCache(key);
    if (hit != null) return hit;

    final style = TextStyle(color: color, fontSize: fontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback);
    return _cache.performAndCacheLayout(glyph, style, textScaler, key);
  }

  /// Size of one glyph cell in the given style, measured from a reference glyph.
  ///
  /// The face and rain both assume a monospace grid, so any glyph's advance is
  /// the cell width. Measured through [paragraph] so the reference layout is
  /// cached alongside everything else rather than rebuilt per frame.
  GlyphMetrics metrics({
    required double fontSize,
    required String fontFamily,
    List<String>? fontFamilyFallback,
    TextScaler textScaler = TextScaler.noScaling,
    Color probeColor = const Color(0xFFFFFFFF),
  }) {
    final p = paragraph('0', color: probeColor, fontSize: fontSize, fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback, textScaler: textScaler);
    return (width: p.maxIntrinsicWidth, height: p.height);
  }

  /// Drop every entry. Memory hygiene — see the class note; correctness does not
  /// depend on this being called.
  void clear() => _cache.clear();
}
