/// A collapsible container that holds a run of sub-cards as one unit (T-266).
///
/// Collapsed (default): a one-line ticker — the latest step summary + a step
/// count — that toggles to expand. Expanded: a titled, framed container that
/// WRAPS the sub-cards; clicking the holder's own BACKGROUND (its padding, the
/// gaps between sub-cards, its gutter — anywhere a child doesn't cover)
/// collapses it. Taps on a child sub-card interact with that card, never the
/// holder, because each child opaquely consumes its full bounds.
///
/// Why a background toggle (not just a top header): the conversation
/// tail-follows on every write, so a top-anchored collapse control is
/// unreachable while a run streams. A click on whatever background is currently
/// in view collapses the holder, ending that race. An explicit focusable caret
/// keeps the control keyboard/AT reachable (D-78).
///
/// Shared primitive: the activity card (T-230) and the nested sub-agent run
/// (T-264) both render through this, so the container model is settled once.
library;

import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClideHolderCard extends StatefulWidget {
  const ClideHolderCard({
    super.key,
    required this.collapsedSummary,
    required this.stepLabel,
    required this.children,
    this.title = 'Activity',
    this.initiallyExpanded = false,
  });

  /// One-line gist of the latest step, shown in the collapsed ticker.
  final String collapsedSummary;

  /// Count label, e.g. `3 steps` — shown in both the ticker and the header,
  /// and announced for AT.
  final String stepLabel;

  /// The sub-cards, shown wrapped when expanded.
  final List<Widget> children;

  /// Title shown in the expanded header (default `Activity`).
  final String title;

  final bool initiallyExpanded;

  @override
  State<ClideHolderCard> createState() => _ClideHolderCardState();
}

class _ClideHolderCardState extends State<ClideHolderCard> {
  late bool _expanded = widget.initiallyExpanded;
  final FocusNode _controlFocus = FocusNode(debugLabel: 'holder-control');

  @override
  void dispose() {
    _controlFocus.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      expanded: _expanded,
      label: '${widget.title}, ${widget.stepLabel}, ${_expanded ? 'expanded' : 'collapsed'}',
      excludeSemantics: true,
      child: Padding(
        // Match ConversationCard's inter-card margin (bottom 14, no top) so a
        // folded activity / agent-run card sits in the same rhythm as the prose
        // cards around it — not crammed 3px below the next one (T-282).
        padding: const EdgeInsets.only(bottom: 14),
        child: _expanded ? _expandedFrame(tokens) : _tickerRow(tokens),
      ),
    );
  }

  /// Collapsed: the ticker row IS the toggle, focusable for keyboard/AT.
  Widget _tickerRow(SurfaceTokens tokens) => ClideTappable(
        focusNode: _controlFocus,
        onTap: _toggle,
        tooltip: 'Expand',
        builder: (context, hovered, focused) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
            border: Border.all(color: tokens.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ClideIcon(const ChevronRightIcon(), size: 12, color: tokens.globalTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: ClideText(
                  widget.collapsedSummary,
                  fontSize: clideFontCaption,
                  fontFamily: clideMonoFamily,
                  color: tokens.globalTextMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ClideText(widget.stepLabel, fontSize: clideFontCaption, color: tokens.globalTextMuted),
            ],
          ),
        ),
      );

  /// Expanded: a framed container wrapping the sub-cards. The frame BACKGROUND
  /// is a gesture target behind the children that only fires for hits the
  /// children don't consume.
  Widget _expandedFrame(SurfaceTokens tokens) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.panelBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Background toggle: behind the children, not a whole-card overlay,
            // so child taps are never intercepted. Excluded from focus traversal
            // — the header caret is the single keyboard stop.
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in widget.children)
                        // Each child opaquely consumes its full bounds so a body
                        // tap interacts with the card (or does nothing), never
                        // the holder background. Deeper controls (caret/copy)
                        // still win; only taps are absorbed, so selection drags
                        // pass through to the SelectionArea.
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

  /// The explicit, focusable collapse control. A background tap is not
  /// keyboard/AT reachable on its own, so this keeps the control on the Tab
  /// path and Enter/Space-activatable (D-78).
  Widget _headerRow(SurfaceTokens tokens) => ClideTappable(
        focusNode: _controlFocus,
        onTap: _toggle,
        tooltip: 'Collapse',
        builder: (context, hovered, focused) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
            border: Border(bottom: BorderSide(color: tokens.panelBorder)),
          ),
          child: Row(
            children: [
              ClideIcon(const ChevronDownIcon(), size: 12, color: tokens.globalTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: ClideText(widget.title, fontSize: clideFontCaption, fontFamily: clideMonoFamily, color: tokens.globalTextMuted),
              ),
              const SizedBox(width: 8),
              ClideText(widget.stepLabel, fontSize: clideFontCaption, color: tokens.globalTextMuted),
            ],
          ),
        ),
      );
}
