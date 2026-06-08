/// The base template every conversation turn renders through (T-173).
///
/// One primitive with three [ConversationCardVariant]s (the stripe, bordered,
/// and bare looks the view used to hand-roll), plus chrome wired in once for
/// all message types: a hover/focus-revealed copy button, an always-visible
/// collapse/expand caret for collapsible turns, and an extensible
/// [MessageAction] list. Decoupled from `ConversationItem` — the view maps
/// each item to (variant, accent, label, body, copyText, actions), so future
/// typed cards (T-168) reuse this chrome with a different body.
///
/// T-174: action buttons are always in the widget tree (keyboard/AT reachable);
/// they are revealed visually only while the card is hovered OR any action
/// holds keyboard focus. The caret and each action use [ClideTappable] so Tab
/// traversal + Enter/Space activation work without hovering.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// An extensible per-message affordance shown in the card's action bar.
/// Copy is provided by the card from `copyText`; callers add more (e.g.
/// fork-from-here, retry) without touching the template.
class MessageAction {
  const MessageAction({required this.label, required this.onInvoke});
  final String label;
  final VoidCallback onInvoke;
}

enum ConversationCardVariant { stripe, bordered, bare }

/// A trailing status mark shown at the right end of the header (T-262): a
/// green check for a succeeded tool call, a red cross for a failure. [none]
/// renders no mark (the default for non-tool cards).
enum ConversationCardStatus { none, success, error }

/// An extra labelled body segment shown below the primary [ConversationCard.body]
/// when the card is expanded (T-262). Lets one card lay out CALL → RESULT (or,
/// for the Agent card, CALL → PROMPT → RESULT — T-263) with a muted sub-label +
/// divider between segments so the reader can tell the parts apart.
class CardSegment {
  const CardSegment({required this.label, required this.child});
  final String label;
  final Widget child;
}

class ConversationCard extends StatefulWidget {
  const ConversationCard({
    super.key,
    this.variant = ConversationCardVariant.stripe,
    required this.accent,
    required this.label,
    required this.body,
    this.copyText,
    this.actions = const [],
    this.collapsible = false,
    this.collapsedByDefault = false,
    this.collapsedSummary,
    this.borderColor,
    this.status = ConversationCardStatus.none,
    this.extraSegments = const [],
  });

  final ConversationCardVariant variant;
  final Color accent;
  final String label;
  final Widget body;

  /// Trailing header status mark (T-262) — a success check or error cross at
  /// the right end of the header. [ConversationCardStatus.none] shows nothing.
  final ConversationCardStatus status;

  /// Extra labelled segments rendered below [body] when expanded (T-262/T-263);
  /// each gets a muted sub-label + divider so CALL/PROMPT/RESULT read apart.
  final List<CardSegment> extraSegments;

  /// Raw text the copy action yields; no copy button when null.
  final String? copyText;

  /// Extra actions appended after copy.
  final List<MessageAction> actions;

  final bool collapsible;
  final bool collapsedByDefault;

  /// One-line gist shown next to the label while collapsed (e.g. the tool's
  /// key arg, or a result's first line), so a collapsed card still says what
  /// it holds. Null → just the label.
  final String? collapsedSummary;

  /// Border colour for the bordered variant (e.g. error red); defaults to the
  /// panel border.
  final Color? borderColor;

  @override
  State<ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<ConversationCard> {
  bool _hover = false;
  late bool _collapsed = widget.collapsible && widget.collapsedByDefault;

  // Focus nodes for the action buttons (copy + custom), managed so that
  // the Opacity covering the action bar lifts when any action is focused.
  // The caret uses its own always-present node (never hidden by Opacity).
  final FocusNode _caretFocus = FocusNode(debugLabel: 'card-caret');
  List<FocusNode> _actionFocusNodes = [];
  int _focusedActionCount = 0;

  bool get _anyActionFocused => _focusedActionCount > 0;

  /// Rebuilds the action-button focus-node list to match the current set of
  /// actions (copyText present or not, plus widget.actions count).
  void _syncActionFocusNodes() {
    final needed = (widget.copyText != null ? 1 : 0) + widget.actions.length;
    if (needed == _actionFocusNodes.length) return;

    // Dispose the excess or add new ones.
    if (needed < _actionFocusNodes.length) {
      for (var i = needed; i < _actionFocusNodes.length; i++) {
        _actionFocusNodes[i].removeListener(_onActionFocusChange);
        _actionFocusNodes[i].dispose();
      }
      _actionFocusNodes = _actionFocusNodes.sublist(0, needed);
    } else {
      for (var i = _actionFocusNodes.length; i < needed; i++) {
        final node = FocusNode(debugLabel: 'card-action-$i');
        node.addListener(_onActionFocusChange);
        _actionFocusNodes.add(node);
      }
    }
  }

  void _onActionFocusChange() {
    final focused = _actionFocusNodes.where((n) => n.hasFocus).length;
    if (focused != _focusedActionCount) {
      setState(() => _focusedActionCount = focused);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncActionFocusNodes();
  }

  @override
  void didUpdateWidget(ConversationCard old) {
    super.didUpdateWidget(old);
    _syncActionFocusNodes();
  }

  @override
  void dispose() {
    _caretFocus.dispose();
    for (final n in _actionFocusNodes) {
      n.removeListener(_onActionFocusChange);
      n.dispose();
    }
    super.dispose();
  }

  void _copy() {
    final text = widget.copyText;
    if (text != null) unawaited(ClideKernel.of(context).clipboard.writePlain(text));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(tokens),
        if (!_collapsed) ...[
          const SizedBox(height: 4),
          widget.body,
          for (final seg in widget.extraSegments) ...[
            _segmentLabel(tokens, seg.label),
            seg.child,
          ],
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: _frame(tokens, content),
      ),
    );
  }

  Widget _frame(SurfaceTokens tokens, Widget content) {
    switch (widget.variant) {
      case ConversationCardVariant.stripe:
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: tokens.globalBackground,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: widget.accent),
                  Expanded(
                    child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: content),
                  ),
                ],
              ),
            ),
          ),
        );
      case ConversationCardVariant.bordered:
        return Container(
          // Vertical interior padding matches the stripe variant (8) so boxed
          // cards share one rhythm — a collapsed tool/Agent card no longer reads
          // chunkier (taller box + more trailing space) than its neighbours (T-282).
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: tokens.globalBackground,
            border: Border.all(color: widget.borderColor ?? tokens.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: content,
        );
      case ConversationCardVariant.bare:
        return content;
    }
  }

  Widget _header(SurfaceTokens tokens) {
    final summary = widget.collapsedSummary;
    // Action visibility: shown when hovered OR when any action button has
    // keyboard focus. Always in the tree so Tab/AT can reach them.
    final showActions = _hover || _anyActionFocused;
    return Row(
      children: [
        if (widget.collapsible) _caret(tokens),
        ClideText(widget.label, fontSize: clideFontSmall, color: widget.accent, fontFamily: clideMonoFamily),
        // While collapsed, show a one-line gist next to the label so the card
        // still says what it holds.
        if (_collapsed && summary != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ClideText(summary, fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: clideMonoFamily, maxLines: 1),
          ),
        ] else
          const Spacer(),
        // Trailing status mark (T-262): success check / error cross, sitting
        // between the summary/spacer and the action bar.
        if (widget.status != ConversationCardStatus.none) _statusMark(tokens),
        // Actions are always in the tree (keyboard/AT always reachable).
        // Opacity reveals them on hover or keyboard focus; opacity-0 keeps
        // them layout-present but visually hidden so they don't distract.
        // alwaysIncludeSemantics keeps them in the semantics tree even at
        // opacity 0 (RenderOpacity drops semantics at 0 by default) so AT can
        // still discover and activate them without hovering.
        Opacity(
          opacity: showActions ? 1.0 : 0.0,
          alwaysIncludeSemantics: true,
          child: Row(children: _actions(tokens)),
        ),
      ],
    );
  }

  Widget _caret(SurfaceTokens tokens) {
    final label = _collapsed ? 'Expand' : 'Collapse';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => setState(() => _collapsed = !_collapsed),
      child: ClideTappable(
        focusNode: _caretFocus,
        tooltip: label,
        onTap: () => setState(() => _collapsed = !_collapsed),
        builder: (_, hovered, pressed) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ClideIcon(
            _collapsed ? PhosphorIcons.caretRight : PhosphorIcons.caretDown,
            size: 12,
            color: tokens.globalTextMuted,
          ),
        ),
      ),
    );
  }

  /// The trailing success/error mark (T-262). Carries a Semantics label so the
  /// outcome is announced, not just colour-coded.
  Widget _statusMark(SurfaceTokens tokens) {
    final ClideIconPainter icon;
    final Color color;
    final String label;
    switch (widget.status) {
      case ConversationCardStatus.success:
        icon = const CheckIcon();
        color = tokens.statusSuccess;
        label = 'succeeded';
      case ConversationCardStatus.error:
        icon = const CloseIcon();
        color = tokens.statusError;
        label = 'failed';
      case ConversationCardStatus.none:
        return const SizedBox.shrink();
    }
    return Semantics(
      label: label,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ClideIcon(icon, size: 12, color: color),
      ),
    );
  }

  /// A muted sub-label + hairline divider introducing an [CardSegment] below
  /// the primary body (T-262), so CALL/PROMPT/RESULT read as distinct parts.
  Widget _segmentLabel(SurfaceTokens tokens, String label) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            ClideText(label, fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: tokens.panelBorder)),
          ],
        ),
      );

  List<Widget> _actions(SurfaceTokens tokens) {
    final items = <_ActionItem>[];
    if (widget.copyText != null) items.add(_ActionItem('copy', _copy));
    for (final a in widget.actions) {
      items.add(_ActionItem(a.label, a.onInvoke));
    }

    return [
      for (var i = 0; i < items.length; i++)
        Semantics(
          button: true,
          label: items[i].label,
          excludeSemantics: true,
          onTap: items[i].onTap,
          child: ClideTappable(
            focusNode: _actionFocusNodes[i],
            tooltip: items[i].label,
            onTap: items[i].onTap,
            builder: (_, hovered, pressed) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: ClideText(
                items[i].label,
                fontSize: clideFontMeta,
                color: tokens.globalTextMuted,
                fontFamily: clideMonoFamily,
              ),
            ),
          ),
        ),
    ];
  }
}

/// Internal pairing of an action label and its callback.
class _ActionItem {
  _ActionItem(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}
