/// The typed SVG scene model the painter draws (T-320 / D-103).
///
/// The document builder ([buildSvgDocument]) lowers a normalized XML tree into
/// this model: every node carries a resolved [SvgStyle] (inheritance already
/// flattened), an optional [Affine] transform, and typed geometry. Colours are
/// packed ARGB ints, not `dart:ui` Colors, so the model stays Flutter-free and
/// `dart test`-able; the painter converts.
///
/// `null` style fields mean "unspecified" — the painter applies the SVG default
/// (fill black, stroke none, stroke-width 1).
library;

import 'svg_path.dart';
import 'svg_transform.dart';

enum SvgLineCap { butt, round, square }

enum SvgLineJoin { miter, round, bevel }

enum SvgTextAnchor { start, middle, end }

enum SvgBaseline { auto, middle, hanging }

/// Resolved presentation style for a node, with inheritance already applied.
class SvgStyle {
  const SvgStyle({
    this.fill,
    this.stroke,
    this.strokeWidth,
    this.opacity = 1.0,
    this.fillOpacity,
    this.strokeOpacity,
    this.dashArray,
    this.lineCap,
    this.lineJoin,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.textAnchor,
    this.baseline,
  });

  /// The root inheritance context: nothing specified, full opacity.
  static const initial = SvgStyle();

  final int? fill; // ARGB; 0x00000000 = explicit none
  final int? stroke; // ARGB
  final double? strokeWidth;
  final double opacity; // element/group opacity — NOT inherited
  final double? fillOpacity;
  final double? strokeOpacity;
  final List<double>? dashArray;
  final SvgLineCap? lineCap;
  final SvgLineJoin? lineJoin;
  final String? fontFamily;
  final double? fontSize;
  final int? fontWeight; // 400, 700, …
  final SvgTextAnchor? textAnchor;
  final SvgBaseline? baseline;
}

/// A node in the typed scene — group or leaf. [style] is fully resolved;
/// [transform] is `null` when identity.
sealed class SvgNode {
  const SvgNode(this.style, this.transform);
  final SvgStyle style;
  final Affine? transform;
}

class SvgGroup extends SvgNode {
  const SvgGroup(super.style, super.transform, this.children);
  final List<SvgNode> children;
}

class SvgRect extends SvgNode {
  const SvgRect(super.style, super.transform, this.x, this.y, this.width, this.height, this.rx, this.ry);
  final double x, y, width, height, rx, ry;
}

/// Circle is an ellipse with `rx == ry`.
class SvgEllipse extends SvgNode {
  const SvgEllipse(super.style, super.transform, this.cx, this.cy, this.rx, this.ry);
  final double cx, cy, rx, ry;
}

class SvgLine extends SvgNode {
  const SvgLine(super.style, super.transform, this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
}

/// Polyline (open) or polygon (`closed == true`). [points] is `[x0,y0,x1,y1,…]`.
class SvgPolyline extends SvgNode {
  const SvgPolyline(super.style, super.transform, this.points, this.closed);
  final List<double> points;
  final bool closed;
}

class SvgPath extends SvgNode {
  const SvgPath(super.style, super.transform, this.segments, {this.markerStart, this.markerMid, this.markerEnd});
  final List<SvgPathSeg> segments;

  /// Ids (sans `url(#…)`) of `marker-start`/`mid`/`end` definitions, if any.
  final String? markerStart, markerMid, markerEnd;
}

/// A `<marker>` definition (e.g. an arrowhead), referenced by `marker-*`.
class SvgMarker {
  const SvgMarker({
    required this.refX,
    required this.refY,
    required this.orientAuto,
    required this.orientAngle,
    required this.strokeScaled,
    required this.children,
    this.viewBox,
  });

  final double refX, refY;
  final bool orientAuto; // orient="auto"
  final double orientAngle; // fixed angle (degrees) when not auto
  final bool strokeScaled; // markerUnits=strokeWidth (default) vs userSpaceOnUse
  final SvgViewBox? viewBox;
  final List<SvgNode> children;
}

class SvgText extends SvgNode {
  const SvgText(super.style, super.transform, this.x, this.y, this.text);
  final double x, y;
  final String text;
}

class SvgImage extends SvgNode {
  const SvgImage(super.style, super.transform, this.x, this.y, this.width, this.height, this.href);
  final double x, y, width, height;
  final String href;
}

/// `viewBox="minX minY width height"`.
class SvgViewBox {
  const SvgViewBox(this.minX, this.minY, this.width, this.height);
  final double minX, minY, width, height;
}

/// A per-object overlay annotation (T-318, D-103): a caption and/or lightbox
/// affordance anchored to an SVG element carrying `data-label` /
/// `data-description` / `data-lightbox`. The rect is the element's axis-aligned
/// bounding box in viewBox (user-space) coordinates with its transform applied;
/// the Flutter overlay maps it through the same viewBox→size fit the painter
/// uses, so captions sit under the right spot.
class SvgAnnotation {
  const SvgAnnotation({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.label,
    this.description,
    this.lightbox = false,
    this.href,
  });

  final double x, y, width, height;
  final String? label, description;
  final bool lightbox;
  final String? href; // image href, for a lightbox target
}

/// A parsed SVG document: optional intrinsic [width]/[height] (px), optional
/// [viewBox], the [root] group, marker defs, and per-object overlay
/// [annotations].
class SvgDocument {
  const SvgDocument({this.width, this.height, this.viewBox, required this.root, this.markers = const {}, this.annotations = const []});

  static const empty = SvgDocument(root: SvgGroup(SvgStyle.initial, null, []));

  final double? width, height;
  final SvgViewBox? viewBox;
  final SvgGroup root;

  /// `<marker>` definitions by id, referenced by path `marker-*`.
  final Map<String, SvgMarker> markers;

  /// Overlay captions/lightbox anchors extracted from `data-*` attributes.
  final List<SvgAnnotation> annotations;
}
