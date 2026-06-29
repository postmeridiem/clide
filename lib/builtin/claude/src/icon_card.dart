/// The Phosphor glyph card (T-313) — display-only per D-78.
///
/// Each entry shows a HERO glyph (legible detail) plus a continuous sample strip
/// at the real UI sizes (10–48), so a reviewer judges how the glyph reads where
/// the app actually uses it; the optional per-entry label + description turn the
/// card into a labelled offer the interaction zone can mirror as a choice list.
/// A per-entry or card-level `color` (hex or CSS name) tints the glyph — content
/// color, not a clide token (the glyph is for whatever project we're on); it
/// falls back to the card foreground.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart' show IconEntry;
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/svg/svg_color.dart' show parseSvgColor;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class IconGlyphCard extends StatelessWidget {
  const IconGlyphCard({super.key, required this.entries, this.defaultColor});

  final List<IconEntry> entries;

  /// Card-level default glyph color (hex / CSS name), applied to entries without
  /// their own.
  final String? defaultColor;

  /// One continuous sample strip, smallest → largest (T-313, finalized set).
  static const _sizes = <double>[10, 11, 12, 13, 14, 15, 18, 20, 24, 32, 48];
  static const _hero = 52.0;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final cardColor = _parse(defaultColor) ?? tokens.globalForeground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[if (i > 0) const SizedBox(height: 18), _entry(tokens, entries[i], cardColor)],
      ],
    );
  }

  Widget _entry(SurfaceTokens tokens, IconEntry e, Color cardColor) {
    final color = _parse(e.color) ?? cardColor;
    final painter = PhosphorIconPainter(e.codepoint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (e.label != null && e.label!.isNotEmpty) ClideText(e.label!, fontSize: clideFontMeta, fontWeight: FontWeight.w600, color: tokens.globalForeground),
        if (e.description != null && e.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClideText(e.description!, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClideIcon(painter, size: _hero, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [for (final s in _sizes) _sample(tokens, painter, color, s)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sample(SurfaceTokens tokens, PhosphorIconPainter painter, Color color, double size) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClideIcon(painter, size: size, color: color),
      const SizedBox(height: 2),
      ClideText('${size.toInt()}', fontSize: clideFontBadge, color: tokens.globalTextMuted),
    ],
  );

  Color? _parse(String? raw) {
    if (raw == null) return null;
    final argb = parseSvgColor(raw);
    return argb == null ? null : Color(argb);
  }
}
