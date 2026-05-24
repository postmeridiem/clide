/// Native render of a Claude conversation from the transcript (epic
/// T-132, D-75) — replaces the terminal as the Claude display surface.
///
/// Renders [ConversationItem]s (from a [ConversationController]) as
/// native cards: user messages, assistant markdown, thinking blocks,
/// tool-use and tool-result cards. The whole list sits under a single
/// [SelectionArea] so text selects + copies across cards (the one
/// terminal affordance we keep — see T-135). Input/composer is a
/// separate concern (T-138).
library;

import 'dart:convert';

import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.controller,
    this.wrapInSelectionArea = true,
    this.emptyState,
  });

  final ConversationController controller;

  /// Whether to wrap the list in its own [ClideSelectionArea]. The team
  /// grid sets this false and wraps all tiles in one shared area so
  /// selection spans tiles — nesting SelectionAreas is illegal (T-140).
  final bool wrapInSelectionArea;

  /// Shown while there are no items yet (e.g. the [ClaudeBanner] startup
  /// banner). Defaults to a plain "Waiting for Claude…" hint.
  final Widget? emptyState;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ConversationView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // Follow the tail — jump to the bottom after the new item lays out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final items = widget.controller.items;

    if (items.isEmpty) {
      return ColoredBox(
        color: tokens.panelBackground,
        child: widget.emptyState ?? const Center(child: ClideText('Waiting for Claude…', muted: true)),
      );
    }

    final list = ClideScrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        itemBuilder: (context, i) => _ConversationTurn(item: items[i], tokens: tokens),
      ),
    );
    return ColoredBox(
      color: tokens.panelBackground,
      child: widget.wrapInSelectionArea ? ClideSelectionArea(child: list) : list,
    );
  }
}

/// Claude's brand coral-orange — a fixed brand accent (not a theme token)
/// used for the "claude" message card's stripe + label.
const claudeAccent = Color(0xFFD97757);

/// One conversation item, rendered by kind.
class _ConversationTurn extends StatelessWidget {
  const _ConversationTurn({required this.item, required this.tokens});

  final ConversationItem item;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final i = item;
    return switch (i) {
      UserMessage() => ConversationCard(
          accent: tokens.globalFocus,
          label: 'you',
          copyText: i.text,
          body: ClideMarkdown(i.text),
        ),
      AssistantTextMessage() => ConversationCard(
          accent: claudeAccent,
          label: 'claude',
          copyText: i.text,
          body: ClideMarkdown(i.text),
        ),
      AssistantThinkingMessage() => ConversationCard(
          variant: ConversationCardVariant.bare,
          accent: tokens.globalTextMuted,
          label: 'thinking',
          copyText: i.thinking,
          collapsible: true,
          collapsedByDefault: true,
          body: ClideText(i.thinking, muted: true, fontSize: clideFontMeta),
        ),
      AssistantToolUse() => _toolUse(i),
      ToolResultMessage() => _toolResult(i),
    };
  }

  Widget _toolUse(AssistantToolUse t) {
    final pretty = const JsonEncoder.withIndent('  ').convert(t.input);
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: tokens.globalFocus,
      label: t.name,
      copyText: pretty,
      collapsible: true,
      body: ClideCodeBlock(source: pretty, language: 'json'),
    );
  }

  Widget _toolResult(ToolResultMessage t) {
    final accent = t.isError ? tokens.statusError : tokens.globalTextMuted;
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: accent,
      borderColor: t.isError ? tokens.statusError : tokens.panelBorder,
      label: t.isError ? 'error' : 'result',
      copyText: t.content,
      collapsible: true,
      collapsedByDefault: true,
      body: ClideText(
        t.content,
        fontSize: clideFontMeta,
        fontFamily: clideMonoFamily,
        color: tokens.globalForeground,
      ),
    );
  }
}
