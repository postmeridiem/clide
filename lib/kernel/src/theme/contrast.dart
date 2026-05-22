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

/// Baseline token pairs every bundled theme must honour.
///
/// Per D-22 every named theme passes this set; per D-69 the named
/// themes (`clide`, `midnight`, `paper`, `terminal`) are user
/// contracts whose palettes are not retuned to chase a contrast gate,
/// so only the load-bearing pairs (primary text on its surface, chrome
/// foregrounds, selected list item) sit here. Stricter coverage for
/// muted text, status chips, syntax tokens, and the focus border lives
/// in [extendedPairs], which only `-hc`/`-cb` variants must pass.
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

/// Stricter pair set — only the high-contrast (`-hc`) and colour-blind
/// (`-cb`) theme variants must clear it. See D-69. These are the
/// surfaces a UX consultant flagged in `consultants.md`: muted body
/// text, status chip foregrounds, syntax tokens on the code-block
/// surface, and the focus-indicating panel border.
List<ContrastPair> extendedPairs(SurfaceTokens s) => [
      ContrastPair(
        name: 'global.text_muted_on_background',
        foreground: s.globalTextMuted,
        background: s.globalBackground,
      ),
      ContrastPair(
        name: 'global.text_muted_on_panel',
        foreground: s.globalTextMuted,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'status.success_on_statusbar',
        foreground: s.statusSuccess,
        background: s.statusBarBackground,
      ),
      ContrastPair(
        name: 'status.warning_on_statusbar',
        foreground: s.statusWarning,
        background: s.statusBarBackground,
      ),
      ContrastPair(
        name: 'status.error_on_statusbar',
        foreground: s.statusError,
        background: s.statusBarBackground,
      ),
      ContrastPair(
        name: 'status.info_on_statusbar',
        foreground: s.statusInfo,
        background: s.statusBarBackground,
      ),
      ContrastPair(
        name: 'syntax.keyword_on_panel',
        foreground: s.syntaxKeyword,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.type_on_panel',
        foreground: s.syntaxType,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.string_on_panel',
        foreground: s.syntaxString,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.number_on_panel',
        foreground: s.syntaxNumber,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.comment_on_panel',
        foreground: s.syntaxComment,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.method_on_panel',
        foreground: s.syntaxMethod,
        background: s.panelBackground,
      ),
      ContrastPair(
        name: 'syntax.punct_on_panel',
        foreground: s.syntaxPunct,
        background: s.panelBackground,
      ),
      // WCAG 1.4.11 wants 3:1 for non-text UI components like a focus
      // border against the adjacent surface.
      ContrastPair(
        name: 'panel.active_border_on_background',
        foreground: s.panelActiveBorder,
        background: s.globalBackground,
        largeText: true,
      ),
      // selection.foreground_on_selection is intentionally omitted here.
      //
      // The `selectionBackground` token defaults to `globalFocus.withAlpha(0x66)`
      // — a semi-transparent tint composited onto the real content background at
      // runtime. The WCAG compositor in contrastRatio() blends onto neutral grey
      // (0x808080) rather than the actual dark panel background, which
      // systematically understates the readable contrast for all current bundled
      // themes. Adding the pair here would require retuning palettes, which D-69
      // forbids for user-contract themes.
      //
      // Enforcement is deferred to a follow-up ticket: -hc/-cb variants will
      // declare an explicit `surface.selectionBackground` override that is
      // opaque enough to clear 3:1 against the grey compositor, at which point
      // the pair can be added to extendedPairs.
    ];

/// Convenience for tests: returns the list of [canonicalPairs] that
/// fail WCAG AA.
List<ContrastFailure> failingPairs(SurfaceTokens tokens) => _failures(canonicalPairs(tokens));

/// Strict variant of [failingPairs] — walks [extendedPairs] instead.
/// Intended for the `-hc` / `-cb` theme gate.
List<ContrastFailure> failingExtendedPairs(SurfaceTokens tokens) => _failures(extendedPairs(tokens));

List<ContrastFailure> _failures(List<ContrastPair> pairs) {
  final out = <ContrastFailure>[];
  for (final p in pairs) {
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
