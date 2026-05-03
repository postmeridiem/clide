import 'dart:math' as math;
import 'dart:ui';

import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:flutter/foundation.dart';

/// A foreground/background token pair the a11y contrast suite walks.
@immutable
class ContrastPair {
  const ContrastPair({
    required this.name,
    required this.foreground,
    required this.background,
    this.largeText = false,
  });

  final String name;
  final Color foreground;
  final Color background;

  /// WCAG AA threshold for "large text" (18pt, or 14pt bold) is 3:1;
  /// normal text is 4.5:1. Mark a pair as [largeText] when the rendered
  /// typography qualifies.
  final bool largeText;
}

/// Compute the WCAG 2.x relative-luminance ratio between two colors.
///
/// Alpha is pre-composited against a neutral grey so semi-transparent
/// tokens don't spuriously pass. Returns a value in `[1, 21]`.
double contrastRatio(Color a, Color b, {Color onto = const Color(0xFF808080)}) {
  final la = _relativeLuminance(_composite(a, onto));
  final lb = _relativeLuminance(_composite(b, onto));
  final brighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (brighter + 0.05) / (darker + 0.05);
}

/// Minimum ratio required for this pair per WCAG AA.
double minimumRatio(ContrastPair pair) => pair.largeText ? 3.0 : 4.5;

/// Canonical set of token pairs each bundled theme must honour.
///
/// The a11y contrast test walks this list per-theme.
List<ContrastPair> canonicalPairs(SurfaceTokens s) => [
      ContrastPair(
        name: 'global.text_on_background',
        foreground: s.globalForeground,
        background: s.globalBackground,
      ),
      ContrastPair(
        name: 'panel.header_foreground_on_panel',
        foreground: s.panelHeaderForeground,
        background: s.panelHeader,
      ),
      ContrastPair(
        name: 'sidebar.foreground_on_sidebar',
        foreground: s.sidebarForeground,
        background: s.sidebarBackground,
      ),
      ContrastPair(
        name: 'statusbar.foreground_on_statusbar',
        foreground: s.statusBarForeground,
        background: s.statusBarBackground,
      ),
      ContrastPair(
        name: 'tab.active_text_on_active_bg',
        foreground: s.tabActiveForeground,
        background: s.tabActive,
      ),
      ContrastPair(
        name: 'tab.inactive_text_on_inactive_bg',
        foreground: s.tabInactiveForeground,
        background: s.tabInactive,
      ),
      ContrastPair(
        name: 'button.text_on_button',
        foreground: s.buttonForeground,
        background: s.buttonBackground,
      ),
      ContrastPair(
        name: 'listItem.selected_text_on_selected_bg',
        foreground: s.listItemSelectedForeground,
        background: s.listItemSelectedBackground,
      ),
      ContrastPair(
        name: 'listItem.text_on_list',
        foreground: s.listItemForeground,
        background: s.listItemBackground,
      ),
      ContrastPair(
        name: 'tooltip.text_on_tooltip',
        foreground: s.tooltipForeground,
        background: s.tooltipBackground,
      ),
      ContrastPair(
        name: 'dropdown.text_on_dropdown',
        foreground: s.dropdownForeground,
        background: s.dropdownBackground,
      ),
    ];

/// Convenience for tests: returns the list of pairs that fail WCAG AA.
List<ContrastFailure> failingPairs(SurfaceTokens tokens) {
  final out = <ContrastFailure>[];
  for (final p in canonicalPairs(tokens)) {
    final ratio = contrastRatio(p.foreground, p.background);
    final need = minimumRatio(p);
    if (ratio < need) {
      out.add(ContrastFailure(pair: p, ratio: ratio, minimum: need));
    }
  }
  return out;
}

@immutable
class ContrastFailure {
  const ContrastFailure({
    required this.pair,
    required this.ratio,
    required this.minimum,
  });

  final ContrastPair pair;
  final double ratio;
  final double minimum;

  @override
  String toString() => 'contrast ${pair.name}: ${ratio.toStringAsFixed(2)} < '
      '${minimum.toStringAsFixed(1)}';
}

// -- internals ---------------------------------------------------------------

Color _composite(Color src, Color dst) {
  final a = src.a;
  if (a >= 0.999) return src;
  double mix(double s, double d) => s * a + d * (1 - a);
  return Color.from(
    alpha: 1.0,
    red: mix(src.r, dst.r),
    green: mix(src.g, dst.g),
    blue: mix(src.b, dst.b),
  );
}

double _relativeLuminance(Color c) {
  double chan(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
}
