/// The display-only drawing card (T-318 / D-91 / D-103).
///
/// Renders an [SvgDocument] — the substrate the SVG engine paints — inside a
/// framed region, with an optional clide-themed caption (label + description)
/// beneath it, plus per-object overlay captions anchored to SVG elements that
/// carry `data-label` / `data-description` (mapped to pixel space via the same
/// viewBox fit the painter uses). The SVG is *content* (its own palette); the
/// frame and captions are clide *chrome* and use `SurfaceTokens`. Display-only
/// per D-78 — no interaction lives on the card.
///
/// Sizes the SVG to its intrinsic aspect ratio (viewBox / width-height) within
/// a height cap, filling the available width.
library;

import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_card_metrics.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:clide/src/svg/svg_node.dart';
import 'package:flutter/widgets.dart';

class DrawingCard extends StatelessWidget {
  const DrawingCard({super.key, required this.document, this.label, this.description, this.images, this.onLightbox, this.maxHeight = 360});

  final SvgDocument document;
  final String? label, description;
  final SvgImageResolver? images;

  /// Called when a `data-lightbox` element is tapped (the caller opens the
  /// zoom view). Null ⇒ no lightbox affordance.
  final VoidCallback? onLightbox;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_has(label))
          Padding(
            padding: const EdgeInsets.only(bottom: kClideCardHeaderPadV),
            child: ClideText(label!, fontSize: clideFontMeta, fontWeight: FontWeight.w600, color: tokens.globalForeground),
          ),
        _svgRegion(tokens),
        if (_has(description))
          Padding(
            padding: const EdgeInsets.only(top: kClideCardHeaderPadV),
            child: ClideText(description!, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ),
      ],
    );
  }

  Widget _svgRegion(SurfaceTokens tokens) {
    final view = SvgView(document: document, images: images);
    final anns = document.annotations.where((a) => _has(a.label) || _has(a.description) || (a.lightbox && onLightbox != null)).toList();
    final content = anns.isEmpty
        ? view
        : Stack(
            fit: StackFit.expand,
            children: [
              view,
              LayoutBuilder(
                builder: (ctx, c) {
                  final vp = svgViewportFit(Size(c.maxWidth, c.maxHeight), document);
                  return Stack(children: [for (final a in anns) ..._overlay(a, vp, tokens)]);
                },
              ),
            ],
          );
    final aspect = _aspect(document);
    final sized = aspect != null ? AspectRatio(aspectRatio: aspect, child: content) : SizedBox(height: maxHeight, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(kClideCardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kClideCardRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: sized,
        ),
      ),
    );
  }

  /// The per-object overlay for one annotation: a lightbox tap target over the
  /// element (when `data-lightbox` and [onLightbox] are set) plus a display-only
  /// caption (data-label / data-description) just below its pixel bbox.
  List<Widget> _overlay(SvgAnnotation a, SvgViewport vp, SurfaceTokens tokens) {
    final tl = vp.toPixel(a.x, a.y);
    final br = vp.toPixel(a.x + a.width, a.y + a.height);
    final w = (br.dx - tl.dx).abs();
    final h = (br.dy - tl.dy).abs();
    return [
      if (a.lightbox && onLightbox != null)
        Positioned(
          left: tl.dx,
          top: tl.dy,
          width: w,
          height: h,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onLightbox),
          ),
        ),
      if (_has(a.label) || _has(a.description))
        Positioned(
          left: tl.dx,
          top: tl.dy + h + 2,
          width: w < 48 ? 48.0 : w,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_has(a.label)) ClideText(a.label!, fontSize: clideFontCaption, fontWeight: FontWeight.w600, color: tokens.globalForeground, maxLines: 2),
                if (_has(a.description)) ClideText(a.description!, fontSize: clideFontCaption, color: tokens.globalTextMuted, maxLines: 3),
              ],
            ),
          ),
        ),
    ];
  }

  static double? _aspect(SvgDocument d) {
    final w = d.viewBox?.width ?? d.width;
    final h = d.viewBox?.height ?? d.height;
    return (w != null && h != null && w > 0 && h > 0) ? w / h : null;
  }

  static bool _has(String? s) => s != null && s.isNotEmpty;
}
