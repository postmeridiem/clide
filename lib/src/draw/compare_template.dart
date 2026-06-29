/// The `compare` drawing-card template (T-319 / D-91 / D-103).
///
/// A before/after (or N-up) comparison: the doc's `images` array — each
/// `{path, label, description}` — lowers to an SVG of side-by-side `<image>`
/// cells, every cell carrying the per-object `data-label` / `data-description`
/// (the T-318 caption overlay) and `data-lightbox` (tap-to-zoom, shared with the
/// image template). The same renderer (T-320) paints it; the painter aspect-fits
/// each image into its cell so differing shapes don't distort.
///
/// Paths are resolved to absolute up front via an injected resolver (like
/// image.show), so the card loader just reads the file — and an unresolvable
/// path is an honest [DrawErr], not a broken cell.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'draw_dispatch.dart';

/// Resolves a user-supplied image path to an absolute existing path, or null.
typedef ComparePathResolver = String? Function(String path);

const _cellW = 320, _cellH = 240, _gap = 20, _capH = 56;

/// Handler for `template: "compare"` — reads the doc's `images` array. Register
/// this in the [DrawingRegistry] with a path [resolvePath] (wired to the
/// workspace root in main.dart).
DrawingTemplateHandler compareTemplateHandler({required ComparePathResolver resolvePath}) {
  return (doc) async {
    final images = doc.fields['images'];
    if (images is! List || images.isEmpty) {
      return const DrawErr('the compare template needs a non-empty "images" array of {path,label,description}');
    }
    final cells = StringBuffer();
    for (var i = 0; i < images.length; i++) {
      final item = images[i];
      if (item is! Map) return const DrawErr('each compare image must be an object with a "path"');
      final path = _str(item['path']);
      if (path == null) return const DrawErr('each compare image needs a "path"');
      final abs = resolvePath(path);
      if (abs == null) return DrawErr('no such image: $path');
      final x = i * (_cellW + _gap);
      final label = _str(item['label']);
      final desc = _str(item['description']);
      cells.write('<image href="${_esc(abs)}" x="$x" y="0" width="$_cellW" height="$_cellH"');
      if (label != null) cells.write(' data-label="${_esc(label)}"');
      if (desc != null) cells.write(' data-description="${_esc(desc)}"');
      cells.write(' data-lightbox=""/>');
    }
    final n = images.length;
    final totalW = n * _cellW + (n - 1) * _gap;
    return DrawOk('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $totalW ${_cellH + _capH}">$cells</svg>');
  };
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
