/// The base template every conversation turn renders through (T-173).
///
/// One primitive with three [ConversationCardVariant]s (the stripe, bordered,
/// and bare looks the view used to hand-roll), plus chrome wired in once for
/// all message types: a hover-revealed copy button, an always-visible
/// collapse/expand caret for collapsible turns, and an extensible
/// [MessageAction] list. Decoupled from `ConversationItem` — the view maps
/// each item to (variant, accent, label, body, copyText, actions), so future
/// typed cards (T-168) reuse this chrome with a different body.
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
    this.borderColor,
  });

  final ConversationCardVariant variant;
  final Color accent;
  final String label;
  final Widget body;

  /// Raw text the copy action yields; no copy button when null.
  final String? copyText;

  /// Extra actions appended after copy.
  final List<MessageAction> actions;

  final bool collapsible;
  final bool collapsedByDefault;

  /// Border colour for the bordered variant (e.g. error red); defaults to the
  /// panel border.
  final Color? borderColor;

  @override
  State<ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<ConversationCard> {
  bool _hover = false;
  late bool _collapsed = widget.collapsible && widget.collapsedByDefault;

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
        if (!_collapsed) ...[const SizedBox(height: 4), widget.body],
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
          padding: const EdgeInsets.all(10),
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
    return Row(
      children: [
        if (widget.collapsible) _caret(tokens),
        ClideText(widget.label, fontSize: clideFontSmall, color: widget.accent, fontFamily: clideMonoFamily),
        const Spacer(),
        // Hover-revealed actions. (Always-reachable keyboard a11y for these is
        // a follow-up detail; the collapse caret above is always visible.)
        if (_hover) ..._actions(tokens),
      ],
    );
  }

  Widget _caret(SurfaceTokens tokens) {
    return _tap(
      label: _collapsed ? 'Expand' : 'Collapse',
      onTap: () => setState(() => _collapsed = !_collapsed),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ClideIcon(
          _collapsed ? PhosphorIcons.caretRight : PhosphorIcons.caretDown,
          size: 12,
          color: tokens.globalTextMuted,
        ),
      ),
    );
  }

  List<Widget> _actions(SurfaceTokens tokens) {
    Widget btn(String label, VoidCallback onTap) => _tap(
          label: label,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: ClideText(label, fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
          ),
        );
    return [
      if (widget.copyText != null) btn('copy', _copy),
      for (final a in widget.actions) btn(a.label, a.onInvoke),
    ];
  }

  Widget _tap({required String label, required VoidCallback onTap, required Widget child}) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
      ),
    );
  }
}
