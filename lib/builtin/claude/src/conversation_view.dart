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
import 'dart:io';

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/facade.dart';
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
    this.hiddenToolUseIds = const <String>{},
    this.toolUseOutcomes = const <String, bool>{},
    this.foldLevel = FoldLevel.tools,
  });

  final ConversationController controller;

  /// How aggressively consecutive meta items (tool calls/results, thinking)
  /// fold into collapsible activity cards (T-230). Default L1 ([FoldLevel.tools]).
  final FoldLevel foldLevel;

  /// tool_use_ids that surfaced as a prompt (permission / AskUserQuestion) —
  /// D-78. While pending (not in [toolUseOutcomes]) the raw tool-use card is
  /// hidden (it shows as a prompt). The result is always kept.
  final Set<String> hiddenToolUseIds;

  /// Resolved outcome per prompted tool_use_id (true = allowed, false = denied)
  /// — a resolved permission tool-use renders collapsed with a green/red
  /// border instead of being hidden (D-78).
  final Map<String, bool> toolUseOutcomes;

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

  /// Hide tool-use payloads that surfaced as a prompt (D-78): AskUserQuestion
  /// (its tool-use *and* result echo are noise — the prompt + the logged answer
  /// cover it), and any permission-prompted tool-use (keep its result — that's
  /// the useful answer).
  List<ConversationItem> _visibleItems(List<ConversationItem> items) {
    final hidden = widget.hiddenToolUseIds;
    final auqIds = {
      for (final it in items)
        if (it is AssistantToolUse && it.name == 'AskUserQuestion') it.toolUseId,
    };
    final outcomes = widget.toolUseOutcomes;
    bool drop(ConversationItem it) {
      if (it is AssistantToolUse) {
        if (it.name == 'AskUserQuestion') return true;
        // Permission-prompted: hide only while pending; once resolved it shows
        // collapsed with a green/red border.
        return hidden.contains(it.toolUseId) && !outcomes.containsKey(it.toolUseId);
      }
      if (it is ToolResultMessage) return auqIds.contains(it.toolUseId); // AUQ result only; keep permission results
      return false;
    }

    return [
      for (final it in items)
        if (!drop(it)) it,
    ];
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
    final items = _visibleItems(widget.controller.items);

    if (items.isEmpty) {
      return ColoredBox(
        color: tokens.panelBackground,
        child: widget.emptyState ?? const Center(child: ClideText('Waiting for Claude…', muted: true)),
      );
    }

    // Fold runs of meta items into collapsible activity cards (T-230); sticky
    // items (user/prose/surfaced errors) render first-class as before.
    final groups = groupConversation(items, widget.foldLevel);
    final list = ClideScrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          return switch (g) {
            StickyItem(:final item) => _ConversationTurn(
                item: item,
                tokens: tokens,
                toolUseOutcomes: widget.toolUseOutcomes,
                toolUseById: widget.controller.toolUseById,
              ),
            FoldedCluster(:final items) => _ActivityCard(
                items: items,
                tokens: tokens,
                toolUseOutcomes: widget.toolUseOutcomes,
                toolUseById: widget.controller.toolUseById,
              ),
          };
        },
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
  const _ConversationTurn({
    required this.item,
    required this.tokens,
    this.toolUseOutcomes = const <String, bool>{},
    this.toolUseById = const <String, AssistantToolUse>{},
  });

  final ConversationItem item;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;

  /// Index from toolUseId → AssistantToolUse, for result-card pairing (T-168).
  final Map<String, AssistantToolUse> toolUseById;

  @override
  Widget build(BuildContext context) {
    final i = item;
    return switch (i) {
      UserMessage() => i.injected
          // Harness-injected (skill load / command expansion / system
          // reminder) — not typed by the user, so de-emphasise: a muted,
          // collapsed "context" card rather than the "you" accent (D-78).
          ? ConversationCard(
              variant: ConversationCardVariant.bare,
              accent: tokens.globalTextMuted,
              label: 'context',
              copyText: i.text,
              collapsible: true,
              collapsedByDefault: true,
              collapsedSummary: _firstLine(i.text),
              body: ClideText(i.text, muted: true, fontSize: clideFontMeta),
            )
          : ConversationCard(
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
      ImageMessage() => _image(context, i),
    };
  }

  /// A driven-in image card (T-249): the image rendered inline, clide-owned
  /// (Flutter's [Image.file], no third-party viewer), display-only per D-78.
  /// Bounded so a large image scales down to the pane width and never pushes
  /// past a readable height; a missing/unreadable file degrades to a muted
  /// placeholder rather than throwing.
  Widget _image(BuildContext context, ImageMessage m) {
    final caption = m.caption;
    return ConversationCard(
      accent: tokens.globalTextMuted,
      label: 'image',
      copyText: m.path,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The card stays display-only (D-78); the click is a navigation
          // gesture that opens the full-screen lightbox (T-252), not an inline
          // control.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openLightbox(context, m.path),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Image.file(
                    File(m.path),
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(m.path),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            ClideText(caption, fontSize: clideFontMeta, color: tokens.globalTextMuted),
          ],
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, String path) {
    ClideKernel.of(context).dialog.show<Object>(
          (ctx, dismiss) => ClideLightbox(
            onDismiss: dismiss,
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _imagePlaceholder(path),
            ),
          ),
        );
  }

  Widget _imagePlaceholder(String path) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.panelBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClideIcon(PhosphorIcons.image, size: 16, color: tokens.globalTextMuted),
            const SizedBox(width: 8),
            Flexible(
              child: ClideText('could not load $path', fontSize: clideFontMeta, color: tokens.globalTextMuted, maxLines: 1),
            ),
          ],
        ),
      );

  Widget _toolUse(AssistantToolUse t) {
    // A resolved permission-prompted call: collapsed, green if approved / red
    // if denied — a quiet record of what was permitted (D-78).
    final outcome = toolUseOutcomes[t.toolUseId];
    if (outcome != null) {
      final color = outcome ? tokens.statusSuccess : tokens.statusError;
      return ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: color,
        borderColor: color,
        label: t.name,
        copyText: const JsonEncoder.withIndent('  ').convert(t.input),
        collapsible: true,
        collapsedByDefault: true,
        collapsedSummary: _toolUseSummary(t),
        body: toolInputBody(tokens, t.name, t.input),
      );
    }
    // Per-tool body rendering (T-168): Bash → command block, Edit/Write → diff,
    // Read/Grep/LS → path label, others → indented JSON. Always collapsible so
    // a bulky write body doesn't dominate the scroll.
    final body = toolInputBody(tokens, t.name, t.input);
    final summary = _toolUseSummary(t);
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: tokens.globalFocus,
      label: t.name,
      copyText: const JsonEncoder.withIndent('  ').convert(t.input),
      collapsible: true,
      collapsedByDefault: true,
      collapsedSummary: summary,
      body: body,
    );
  }

  Widget _toolResult(ToolResultMessage t) {
    final paired = toolUseById[t.toolUseId];
    final accent = t.isError ? tokens.statusError : tokens.globalTextMuted;
    final label = t.isError ? 'error' : 'result';

    // Error result: render the error message prominently (T-168). If we have
    // the paired tool_use, show the tool name as a sub-label so the user can
    // see what failed without expanding.
    if (t.isError) {
      final multiline = t.content.contains('\n');
      return ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: accent,
        borderColor: tokens.statusError,
        label: paired != null ? '${paired.name} · $label' : label,
        copyText: t.content,
        collapsible: multiline,
        collapsedByDefault: false, // errors default expanded so they're visible
        collapsedSummary: multiline ? _firstLine(t.content) : null,
        body: ClideText(
          t.content,
          fontSize: clideFontMeta,
          fontFamily: clideMonoFamily,
          color: tokens.statusError,
        ),
      );
    }

    // Success result (T-168): for tools where the output is the main event
    // (Bash, Read, Grep, LS), show the output as a code block so it's readable.
    // For Write/Edit, the result is usually "OK" — keep it as plain text.
    final multiline = t.content.contains('\n');
    final isOutputTool = paired != null && const {'Bash', 'Read', 'Grep', 'LS'}.contains(paired.name);
    final resultLabel = paired != null ? '${paired.name} · $label' : label;
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: accent,
      borderColor: tokens.panelBorder,
      label: resultLabel,
      copyText: t.content,
      collapsible: multiline,
      collapsedByDefault: multiline,
      collapsedSummary: multiline ? _firstLine(t.content) : null,
      body: isOutputTool
          ? ClideCodeBlock(source: t.content, language: 'text')
          : ClideText(
              t.content,
              fontSize: clideFontMeta,
              fontFamily: clideMonoFamily,
              color: tokens.globalForeground,
            ),
    );
  }

  /// A compact one-liner for a collapsed tool-use card: the most telling arg.
  String _toolUseSummary(AssistantToolUse t) {
    final input = t.input;
    final key =
        input['file_path'] ?? input['command'] ?? input['path'] ?? input['pattern'] ?? input['url'] ?? (input.values.isNotEmpty ? input.values.first : null);
    final s = key?.toString().replaceAll('\n', ' ') ?? '';
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  String _firstLine(String content) {
    final line = content.split('\n').first.trim();
    return line.length > 80 ? '${line.substring(0, 80)}…' : line;
  }
}

/// A folded run of meta items rendered as one collapsible activity card
/// (T-230). Collapsed (default): a one-line live ticker of the latest step +
/// a step count — re-grouped on every rebuild, so the ticker updates in place
/// as the run grows. Expanded: every folded step in order. Keyboard + screen
/// reader accessible: [ClideTappable] activates on Enter/Space, and the
/// Semantics announces the step count + expanded/collapsed state.
class _ActivityCard extends StatefulWidget {
  const _ActivityCard({
    required this.items,
    required this.tokens,
    required this.toolUseOutcomes,
    required this.toolUseById,
  });

  final List<ConversationItem> items;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;
  final Map<String, AssistantToolUse> toolUseById;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final count = widget.items.length;
    final stepLabel = count == 1 ? '1 step' : '$count steps';

    final header = ClideTappable(
      onTap: () => setState(() => _expanded = !_expanded),
      builder: (context, hovered, focused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (hovered || focused) ? tokens.listItemHoverBackground : tokens.listItemBackground,
          border: Border.all(color: tokens.panelBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            ClideIcon(_expanded ? const ChevronDownIcon() : const ChevronRightIcon(), size: 12, color: tokens.globalTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: ClideText(
                _expanded ? 'Activity' : _summarizeActivity(widget.items.last),
                fontSize: clideFontCaption,
                fontFamily: clideMonoFamily,
                color: tokens.globalTextMuted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ClideText(stepLabel, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      expanded: _expanded,
      label: 'Activity, $stepLabel, ${_expanded ? 'expanded' : 'collapsed'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in widget.items)
                      _ConversationTurn(
                        item: item,
                        tokens: tokens,
                        toolUseOutcomes: widget.toolUseOutcomes,
                        toolUseById: widget.toolUseById,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One-line summary of a folded item for the collapsed ticker.
String _summarizeActivity(ConversationItem item) {
  switch (item) {
    case AssistantToolUse(:final name, :final input):
      final raw = input['command'] ?? input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['url'];
      final detail = raw is String ? raw.split('\n').first.trim() : '';
      final clipped = detail.length > 72 ? '${detail.substring(0, 72)}…' : detail;
      return clipped.isEmpty ? name : '$name  $clipped';
    case ToolResultMessage(:final isError):
      return isError ? '↳ result · error' : '↳ result';
    case AssistantThinkingMessage():
      return 'thinking…';
    case UserMessage(:final text):
      return text;
    case AssistantTextMessage(:final text):
      return text;
    case ImageMessage(:final path):
      return 'image $path';
  }
}
