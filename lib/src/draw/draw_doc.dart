/// The drawing-card document model + envelope parser (T-318 / D-91 / D-103).
///
/// A `clide draw` payload is a JSON document. In PRIMITIVE mode it carries raw
/// SVG (`svg` inline or `svgPath`); in TEMPLATE mode it names a `template`
/// (`d2`, `icon`, `compare`, `image`, …) whose fields a registered handler
/// lowers to SVG. Either way an optional card-level `label`/`description`
/// renders as a caption beneath the drawing (D-103: SVG is the substrate; a thin
/// Flutter overlay carries the chrome).
///
/// This is just the typed envelope + a tolerant parser — template lowering and
/// painting live elsewhere. Never throws; a non-object payload yields `null`.
///
/// Flutter-free: pure Dart, runs under `dart test`.
library;

/// A parsed drawing-card document.
class DrawingCardDoc {
  const DrawingCardDoc({this.label, this.description, this.template, this.svg, this.svgPath, this.fields = const {}});

  /// Card-level caption, shown beneath the drawing when present.
  final String? label, description;

  /// Template name (`d2`, `icon`, …). `null` or `svg` ⇒ primitive mode.
  final String? template;

  /// Primitive-mode SVG: inline source, or a path to an `.svg`.
  final String? svg, svgPath;

  /// The full document map, so a template handler can read its own fields
  /// (`source`, `items`, `path`, …).
  final Map<String, Object?> fields;

  /// True when the card is raw SVG rather than a named template.
  bool get isPrimitive => template == null || template == 'svg';
}

/// Parse a decoded-JSON drawing-card document (a `Map`). Returns `null` only
/// when [json] isn't a JSON object; never throws.
DrawingCardDoc? parseDrawingCardDoc(Object? json) {
  if (json is! Map) return null;
  final card = json['card'];
  final cardMap = card is Map ? card : const {};
  return DrawingCardDoc(
    label: _str(cardMap['label']) ?? _str(json['label']),
    description: _str(cardMap['description']) ?? _str(json['description']),
    template: _str(json['template']),
    svg: _str(json['svg']),
    svgPath: _str(json['svgPath']),
    fields: {
      for (final e in json.entries)
        if (e.key is String) e.key as String: e.value,
    },
  );
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
