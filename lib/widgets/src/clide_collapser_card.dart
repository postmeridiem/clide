/// The conversation stream's collapsible card (T-305) — the category-3 card.
///
/// Holds a list of `1..N` inner item cards as one unit. A single item is just a
/// list of one: there is no separate single-card path, which keeps the model
/// uniform and reliable.
///
/// - **Collapsed** (default): a one-line ticker — the [label], the echoed
///   [collapsedSummary] (the run's latest content line), a fixed-width [counter]
///   ("3 steps"), and the aggregate [status] (spinner / check / cross). The
///   whole row is the toggle.
/// - **Expanded**: a framed inner canvas wrapping the item cards; clicking the
///   frame BACKGROUND (padding, the gaps between items, the gutter — anywhere an
///   item doesn't cover) collapses it. An explicit focusable header caret keeps
///   the control keyboard/AT reachable while a run streams (the tail-follow race
///   — a top-only control would be unreachable as the view auto-scrolls, D-78).
///
/// Chrome is consistent across every collapser: the chevron is hard against the
/// LEFT edge, the status icon hard against the RIGHT edge, the counter sits in a
/// fixed-width slot just inboard of it, and [color] drives the border + the
/// chevron/label tint so each instance keeps its visual identity through one
/// widget. The inner item cards are content (they keep their OWN per-item status
/// + stripe); the aggregate status/count/title shown here are computed by the
/// caller and passed in — this widget stays free of conversation semantics.
library;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/src/clide_card_metrics.dart';
import 'package:clide/widgets/src/clide_icon.dart';
import 'package:clide/widgets/src/clide_status_indicator.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/clide_text.dart';
import 'package:clide/widgets/src/icons/chevron.dart';
import 'package:clide/widgets/src/spacing.dart';
import 'package:clide/widgets/src/typography.dart';
import 'package:flutter/widgets.dart';

class ClideCollapserCard extends StatefulWidget {
  const ClideCollapserCard({
    super.key,
    required this.label,
    required this.children,
    this.color,
    this.collapsedSummary,
    this.counter,
    this.status,
    this.initiallyExpanded = false,
  });

  /// Header label, shown collapsed AND expanded (e.g. `Edits`, `Bash`).
  final String label;

  /// The inner item cards, wrapped in the frame when expanded. A single item is
  /// a list of one.
  final List<Widget> children;

  /// Border + chevron/label tint. Null → panel border with a muted label.
  final Color? color;

  /// The run's latest content line, echoed beside the label while collapsed.
  final String? collapsedSummary;

  /// Fixed-width right-aligned count, e.g. `3 steps`. Null → no counter slot.
  final String? counter;

  /// Aggregate run status (spinner / check / cross) at the right edge. The inner
  /// cards still carry their own per-item marks; this is the roll-up.
  final ClideRunStatus? status;

  final bool initiallyExpanded;

  @override
  State<ClideCollapserCard> createState() => _ClideCollapserCardState();
}

class _ClideCollapserCardState extends State<ClideCollapserCard> {
  late bool _expanded = widget.initiallyExpanded;
  final FocusNode _controlFocus = FocusNode(debugLabel: 'collapser-control');

  @override
  void dispose() {
    _controlFocus.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final semanticCount = widget.counter == null ? '' : ', ${widget.counter}';
    return Semantics(
      button: true,
      expanded: _expanded,
      label: '${widget.label}$semanticCount, ${_expanded ? 'expanded' : 'collapsed'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: kClideCardGap),
        child: _expanded ? _expandedFrame(tokens) : _tickerRow(tokens),
      ),
    );
  }

  /// The header row content, shared by the collapsed ticker and the expanded
  /// header so the chrome is pixel-identical between states.
  Widget _headerContent(SurfaceTokens tokens, {required bool expanded}) {
    final accent = widget.color ?? tokens.globalTextMuted;
    final showSummary = !expanded && widget.collapsedSummary != null;
    return Row(
      children: [
        // Chevron — hard against the left edge; the toggle.
        ClideIcon(expanded ? const ChevronDownIcon() : const ChevronRightIcon(), size: 12, color: accent),
        const SizedBox(width: 8),
        ClideText(widget.label, fontSize: clideFontCaption, fontFamily: clideMonoFamily, color: accent),
        if (showSummary) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ClideText(
              widget.collapsedSummary!,
              fontSize: clideFontCaption,
              fontFamily: clideMonoFamily,
              color: tokens.globalTextMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        // Counter — fixed-width right-aligned slot so the status icon never shifts.
        if (widget.counter != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: kClideCardCounterSlotWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: ClideText(widget.counter!, fontSize: clideFontCaption, color: tokens.globalTextMuted, maxLines: 1),
            ),
          ),
        ],
        // Status — the icon hard against the right edge.
        if (widget.status != null) ...[
          const SizedBox(width: 8),
          ClideStatusIndicator(status: widget.status!, size: clideIconHero),
        ],
      ],
    );
  }

  /// Collapsed: the ticker row IS the toggle, focusable for keyboard/AT.
  Widget _tickerRow(SurfaceTokens tokens) => ClideTappable(
        focusNode: _controlFocus,
        onTap: _toggle,
        tooltip: 'Expand',
        builder: (context, hovered, focused) => Container(
          padding: const EdgeInsets.symmetric(horizontal: kClideCardHeaderPadH, vertical: kClideCardHeaderPadV),
          decoration: BoxDecoration(
            color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
            border: Border.all(color: widget.color ?? tokens.panelBorder),
            borderRadius: BorderRadius.circular(kClideCardRadius),
          ),
          child: _headerContent(tokens, expanded: false),
        ),
      );

  /// Expanded: a framed inner canvas wrapping the item cards. The frame
  /// BACKGROUND is a gesture target behind the items that only fires for hits
  /// the items don't consume.
  Widget _expandedFrame(SurfaceTokens tokens) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: widget.color ?? tokens.panelBorder),
          borderRadius: BorderRadius.circular(kClideCardRadius),
        ),
        child: Stack(
          children: [
            // Background toggle: behind the items, not a whole-card overlay, so
            // item taps are never intercepted. Excluded from focus traversal —
            // the header caret is the single keyboard stop.
            Positioned.fill(
              child: ExcludeFocus(
                child: ClideTappable(
                  onTap: _toggle,
                  tooltip: 'Collapse',
                  builder: (_, __, ___) => const SizedBox.expand(),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerRow(tokens),
                // Even padding around the inner item canvas (T-305): the sides +
                // top match, and each inner item carries a matching bottom margin
                // (so the last item's margin is the bottom inset and items in a
                // multi-item run are evenly separated) — hence bottom 0 here.
                Padding(
                  padding: const EdgeInsets.fromLTRB(kClideCardHeaderPadH, kClideCardHeaderPadH, kClideCardHeaderPadH, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in widget.children)
                        // Each item opaquely consumes its full bounds so a body
                        // tap interacts with that card (or does nothing), never
                        // the collapser background. Deeper controls still win;
                        // only taps are absorbed, so selection drags pass through.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: child,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// The explicit, focusable collapse control in the expanded header. A
  /// background tap alone is not keyboard/AT reachable, so this keeps the
  /// control on the Tab path and Enter/Space-activatable (D-78).
  Widget _headerRow(SurfaceTokens tokens) => ClideTappable(
        focusNode: _controlFocus,
        onTap: _toggle,
        tooltip: 'Collapse',
        builder: (context, hovered, focused) => Container(
          padding: const EdgeInsets.symmetric(horizontal: kClideCardHeaderPadH, vertical: kClideCardHeaderPadV),
          decoration: BoxDecoration(
            color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
            border: Border(bottom: BorderSide(color: widget.color ?? tokens.panelBorder)),
          ),
          child: _headerContent(tokens, expanded: true),
        ),
      );
}
