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

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ConversationView extends StatefulWidget {
  const ConversationView({super.key, required this.controller});

  final ConversationController controller;

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
        child: const Center(
          child: ClideText('Waiting for Claude…', muted: true),
        ),
      );
    }

    return ColoredBox(
      color: tokens.panelBackground,
      child: ClideSelectionArea(
        child: ClideScrollbar(
          controller: _scroll,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, i) => _ConversationTurn(item: items[i], tokens: tokens),
          ),
        ),
      ),
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
      UserMessage() => _messageCard('you', tokens.globalFocus, ClideMarkdown(i.text)),
      AssistantTextMessage() => _messageCard('claude', claudeAccent, ClideMarkdown(i.text)),
      AssistantThinkingMessage() => _labelled(
          'thinking',
          tokens.globalTextMuted,
          ClideText(i.thinking, muted: true, fontSize: clideFontMeta),
        ),
      AssistantToolUse() => _toolUse(i),
      ToolResultMessage() => _toolResult(i),
    };
  }

  /// A turn rendered as a distinct card: an [accent]-coloured left stripe
  /// and label over a filled background, so user and Claude turns read
  /// apart from each other (and from the panel canvas) by accent.
  Widget _messageCard(String label, Color accent, Widget body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ColoredBox(
          color: tokens.globalBackground,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClideText(
                          label,
                          fontSize: clideFontSmall,
                          color: accent,
                          fontFamily: clideMonoFamily,
                        ),
                        const SizedBox(height: 4),
                        body,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A labelled turn: a small role tag above the body.
  Widget _labelled(String label, Color labelColor, Widget body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(
            label,
            fontSize: clideFontSmall,
            color: labelColor,
            fontFamily: clideMonoFamily,
          ),
          const SizedBox(height: 4),
          body,
        ],
      ),
    );
  }

  Widget _toolUse(AssistantToolUse t) {
    final pretty = const JsonEncoder.withIndent('  ').convert(t.input);
    return _card(
      borderColor: tokens.panelBorder,
      header: Row(
        children: [
          ClideText('›', color: tokens.globalFocus, fontFamily: clideMonoFamily),
          const SizedBox(width: 6),
          ClideText(t.name, fontWeight: FontWeight.w500, fontFamily: clideMonoFamily),
        ],
      ),
      body: ClideCodeBlock(source: pretty, language: 'json'),
    );
  }

  Widget _toolResult(ToolResultMessage t) {
    final color = t.isError ? tokens.statusError : tokens.globalTextMuted;
    return _card(
      borderColor: t.isError ? tokens.statusError : tokens.panelBorder,
      header: ClideText(
        t.isError ? 'error' : 'result',
        fontSize: clideFontSmall,
        color: color,
        fontFamily: clideMonoFamily,
      ),
      body: ClideText(
        t.content,
        fontSize: clideFontMeta,
        fontFamily: clideMonoFamily,
        color: tokens.globalForeground,
      ),
    );
  }

  Widget _card({required Color borderColor, required Widget header, required Widget body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.globalBackground,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: 6), body],
        ),
      ),
    );
  }
}
