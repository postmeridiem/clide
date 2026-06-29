/// Drawing-card template dispatch (T-318 / D-103).
///
/// Lowers a [DrawingCardDoc] to an SVG string — the substrate the renderer
/// paints (D-103). In primitive mode the SVG is the doc's inline `svg` or the
/// contents of its `svgPath`; in template mode a registered handler (`d2`,
/// `icon`, `compare`, `image` — the child tickets) produces the SVG from the
/// doc's fields. The handlers and the file reader are injected, so this stays
/// headless- and `dart test`-friendly (no ambient filesystem, mirroring how
/// image.show injects its path resolver).
///
/// Honest result: every failure (no source, unknown template, unreadable path,
/// empty handler output) returns a [DrawErr] with a message rather than
/// throwing — the command layer turns it into an IpcError userError.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

import 'draw_doc.dart';

/// Lowers a template-mode doc to SVG, as a [DrawResult] — [DrawOk] with the SVG
/// or [DrawErr] carrying an honest, user-facing message (e.g. a compile failure
/// or an unresolved tool, with a hint).
typedef DrawingTemplateHandler = Future<DrawResult> Function(DrawingCardDoc doc);

/// Reads a file's contents, or `null` if unreadable. Injected for testability.
typedef DrawingFileReader = Future<String?> Function(String path);

/// Registry of template handlers, keyed by `template` name.
class DrawingRegistry {
  final Map<String, DrawingTemplateHandler> _handlers = {};

  /// Register (or replace) the handler for [template].
  void register(String template, DrawingTemplateHandler handler) => _handlers[template] = handler;

  DrawingTemplateHandler? handlerFor(String template) => _handlers[template];

  bool get isEmpty => _handlers.isEmpty;
}

/// Outcome of lowering a doc to SVG.
sealed class DrawResult {
  const DrawResult();
}

class DrawOk extends DrawResult {
  const DrawOk(this.svg);
  final String svg;
}

class DrawErr extends DrawResult {
  const DrawErr(this.message);
  final String message;
}

/// Lower [doc] to an SVG string. Primitive docs use their inline `svg` or read
/// `svgPath` via [readFile]; template docs use the matching handler in
/// [registry].
Future<DrawResult> resolveDrawingSvg(DrawingCardDoc doc, DrawingRegistry registry, {required DrawingFileReader readFile}) async {
  if (doc.isPrimitive) {
    if (doc.svg != null) return DrawOk(doc.svg!);
    if (doc.svgPath != null) {
      final contents = await readFile(doc.svgPath!);
      return contents == null ? DrawErr('cannot read ${doc.svgPath}') : DrawOk(contents);
    }
    return const DrawErr('drawing card has no svg, svgPath, or template');
  }

  final handler = registry.handlerFor(doc.template!);
  if (handler == null) return DrawErr('unknown drawing template: ${doc.template}');
  return handler(doc);
}
