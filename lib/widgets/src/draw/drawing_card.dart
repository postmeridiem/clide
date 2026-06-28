/// The display-only drawing card (T-318 / D-91 / D-103).
///
/// Renders an [SvgDocument] — the substrate the SVG engine paints — inside a
/// framed region, with an optional clide-themed caption (label + description)
/// beneath it. The SVG is *content* (its own palette); the frame and caption
/// are clide *chrome* and use `SurfaceTokens`. Display-only per D-78 — no
/// interaction lives on the card.
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
  const DrawingCard({super.key, required this.document, this.label, this.description, this.images, this.maxHeight = 360});

  final SvgDocument document;
  final String? label, description;
  final SvgImageResolver? images;
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
    final aspect = _aspect(document);
    final sized = aspect != null ? AspectRatio(aspectRatio: aspect, child: view) : SizedBox(height: maxHeight, child: view);
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

  static double? _aspect(SvgDocument d) {
    final w = d.viewBox?.width ?? d.width;
    final h = d.viewBox?.height ?? d.height;
    return (w != null && h != null && w > 0 && h > 0) ? w / h : null;
  }

  static bool _has(String? s) => s != null && s.isNotEmpty;
}
