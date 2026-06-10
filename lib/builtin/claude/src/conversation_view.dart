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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/image_thumbnail.dart';
import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/facade.dart';
import 'package:clide/kernel/src/syntax/language_map.dart';
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

  /// Whether the view is pinned to the tail — only then do we re-anchor on a
  /// viewport resize, so a user who scrolled up isn't yanked back down (T-297).
  bool _atBottom = true;

  /// Last laid-out viewport height; a change means the bottom interaction zone
  /// grew/shrank (a permission prompt / AskUserQuestion opened, D-78) and the
  /// tail needs re-anchoring above the newly-sized box.
  double? _lastViewportHeight;

  static const double _bottomEpsilon = 8;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _scroll.addListener(_trackBottom);
  }

  void _trackBottom() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _atBottom = (p.maxScrollExtent - p.pixels) <= _bottomEpsilon;
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
    _scroll.removeListener(_trackBottom);
    _scroll.dispose();
    super.dispose();
  }

  /// Hide tool-use payloads that surfaced as a prompt (D-78): AskUserQuestion
  /// (its tool-use *and* result echo are noise — the prompt + the logged answer
  /// cover it), and any permission-prompted tool-use (keep its result — that's
  /// the useful answer).
  List<ConversationItem> _visibleItems(List<ConversationItem> items, Set<String> ownedSidechainUuids) {
    final hidden = widget.hiddenToolUseIds;
    final auqIds = {
      for (final it in items)
        if (it is AssistantToolUse && it.name == 'AskUserQuestion') it.toolUseId,
    };
    final outcomes = widget.toolUseOutcomes;
    final toolUseById = {
      for (final it in items)
        if (it is AssistantToolUse) it.toolUseId: it,
    };

    // A tool-use is dropped (not rendered as a card) when it's an
    // AskUserQuestion or a still-pending permission prompt.
    bool toolUseDropped(AssistantToolUse t) {
      if (t.name == 'AskUserQuestion') return true;
      return hidden.contains(t.toolUseId) && !outcomes.containsKey(t.toolUseId);
    }

    bool drop(ConversationItem it) {
      // T-263/T-264: a sidechain item owned by an Agent run folds into (prompt)
      // or nests under (the run) its Agent card — suppress it from the top level
      // so it doesn't also render loose in the main chain. Checked first because
      // a run's items include AssistantToolUse / ToolResultMessage too.
      if (it.isSidechain && ownedSidechainUuids.contains(it.uuid)) return true;
      if (it is AssistantToolUse) return toolUseDropped(it);
      if (it is ToolResultMessage) {
        if (auqIds.contains(it.toolUseId)) return true; // AUQ result echo — noise
        // T-262: a successful result whose paired tool-use is going to render
        // folds INTO that card — suppress the standalone result here so it
        // doesn't double-render. Errors stay standalone (prominent red card);
        // orphan results (no paired tool-use) stay standalone too.
        if (it.isError) return false;
        final tu = toolUseById[it.toolUseId];
        if (tu == null) return false;
        return !toolUseDropped(tu);
      }
      return false;
    }

    return [
      for (final it in items)
        if (!drop(it)) it,
    ];
  }

  /// Resolves how a sub-agent (sidechain) run attaches to its spawning
  /// Agent/Task card (T-263 + T-264).
  ///
  /// Every sidechain item is routed to its owning Agent tool-use by walking its
  /// `parentUuid` chain up to the Agent message it branches off — robust when
  /// several agents run in parallel in one turn — with the nearest preceding
  /// Agent tool-use as a fallback. Returns:
  /// - [ownedSidechainUuids]: sidechain item uuids to suppress from the top
  ///   level (they fold into, or nest under, their Agent card).
  /// - [promptsByToolUseId]: the prompt(s) folded into the Agent CALL (T-263).
  /// - [runByToolUseId]: the rest of the run — prose / thinking / tool cards —
  ///   nested in a holder UNDER the Agent card (T-264), with a successful
  ///   sidechain tool result left out (it folds into its own tool card).
  ({
    Set<String> ownedSidechainUuids,
    Map<String, List<UserMessage>> promptsByToolUseId,
    Map<String, List<ConversationItem>> runByToolUseId,
  }) _sidechainFold(List<ConversationItem> items) {
    final agentByMsgUuid = <String, AssistantToolUse>{
      for (final it in items)
        if (it is AssistantToolUse && _isAgentTool(it.name)) it.uuid: it,
    };
    // Envelope-level chain info (consistent across items sharing a uuid).
    final parentByUuid = <String, String?>{};
    final sidechainByUuid = <String, bool>{};
    final toolUseIds = <String>{};
    for (final it in items) {
      parentByUuid[it.uuid] = it.parentUuid;
      sidechainByUuid[it.uuid] = it.isSidechain;
      if (it is AssistantToolUse) toolUseIds.add(it.toolUseId);
    }

    AssistantToolUse? resolveOwner(ConversationItem item, AssistantToolUse? nearest) {
      var cur = item.uuid;
      final seen = <String>{};
      while (seen.add(cur)) {
        final parent = parentByUuid[cur];
        if (parent == null) break;
        final agent = agentByMsgUuid[parent];
        if (agent != null) return agent; // chain roots at this Agent message
        if (sidechainByUuid[parent] != true) break; // left the run's chain
        cur = parent;
      }
      return nearest;
    }

    final owned = <String>{};
    final prompts = <String, List<UserMessage>>{};
    final run = <String, List<ConversationItem>>{};
    AssistantToolUse? lastAgent;
    for (final it in items) {
      if (it is AssistantToolUse && _isAgentTool(it.name)) {
        lastAgent = it;
        continue;
      }
      if (!it.isSidechain) continue;
      if (it is UserMessage && it.injected) continue; // harness noise inside a run
      final owner = resolveOwner(it, lastAgent);
      if (owner == null) continue; // orphan — rendered inline + attributed
      owned.add(it.uuid);
      if (it is UserMessage) {
        (prompts[owner.toolUseId] ??= <UserMessage>[]).add(it); // folded into the call
      } else if (it is ToolResultMessage && !it.isError && toolUseIds.contains(it.toolUseId)) {
        // A successful sidechain result folds into its own tool card inside the
        // run — owned (suppressed up top) but not a standalone run item.
        continue;
      } else {
        (run[owner.toolUseId] ??= <ConversationItem>[]).add(it);
      }
    }
    return (ownedSidechainUuids: owned, promptsByToolUseId: prompts, runByToolUseId: run);
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
    final allItems = widget.controller.items;
    // T-263/T-264: resolve each sidechain run → owning Agent card before
    // culling, so the run is suppressed up top and folded into / nested under
    // its card.
    final fold = _sidechainFold(allItems);
    final items = _visibleItems(allItems, fold.ownedSidechainUuids);

    if (items.isEmpty) {
      return ColoredBox(
        color: tokens.panelBackground,
        child: widget.emptyState ?? const Center(child: ClideText('Waiting for Claude…', muted: true)),
      );
    }

    // Reverse pairing (T-262): toolUseId → its result, so a tool-use card can
    // fold a successful result in. Built from the full item list (not the
    // visible one — the success result is suppressed from `items`).
    final resultByToolUseId = <String, ToolResultMessage>{
      for (final it in allItems)
        if (it is ToolResultMessage) it.toolUseId: it,
    };

    // Fold runs of meta items into collapsible activity cards (T-230); sticky
    // items (user/prose/surfaced errors) render first-class as before. Then
    // bundle consecutive same-file edits into one "# edits" card (T-296).
    final groups = coalesceEditRuns(groupConversation(items, widget.foldLevel));
    final list = ClideScrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          // Stable keys pin each card's State (collapse/hover, cluster expand)
          // to its logical item, so streaming result updates that reshape the
          // visible list don't reattach State to the wrong card (T-285).
          return switch (g) {
            StickyItem(:final item) => _ConversationTurn(
                key: ValueKey('turn.${item.uuid}'),
                item: item,
                tokens: tokens,
                toolUseOutcomes: widget.toolUseOutcomes,
                toolUseById: widget.controller.toolUseById,
                resultByToolUseId: resultByToolUseId,
                promptsByToolUseId: fold.promptsByToolUseId,
                runByToolUseId: fold.runByToolUseId,
              ),
            FoldedCluster(:final items) => _ActivityCard(
                key: ValueKey('cluster.${items.first.uuid}'),
                items: items,
                tokens: tokens,
                toolUseOutcomes: widget.toolUseOutcomes,
                toolUseById: widget.controller.toolUseById,
                resultByToolUseId: resultByToolUseId,
                promptsByToolUseId: fold.promptsByToolUseId,
                runByToolUseId: fold.runByToolUseId,
              ),
            EditRun(:final edits) => _EditRunCard(
                key: ValueKey('edits.${edits.first.uuid}'),
                edits: edits,
                tokens: tokens,
                toolUseOutcomes: widget.toolUseOutcomes,
                toolUseById: widget.controller.toolUseById,
                resultByToolUseId: resultByToolUseId,
                promptsByToolUseId: fold.promptsByToolUseId,
                runByToolUseId: fold.runByToolUseId,
              ),
          };
        },
      ),
    );
    // Re-anchor the tail when the viewport height changes — the bottom
    // interaction zone (composer ↔ permission prompt / AskUserQuestion, D-78)
    // resizing would otherwise leave the last card hidden behind the taller box
    // (T-297). Only when already pinned to the bottom, so scrolled-up reading
    // is undisturbed.
    final sized = LayoutBuilder(
      builder: (ctx, constraints) {
        final h = constraints.maxHeight;
        if (_lastViewportHeight != null && h != _lastViewportHeight && _atBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
        }
        _lastViewportHeight = h;
        return list;
      },
    );
    return ColoredBox(
      color: tokens.panelBackground,
      child: widget.wrapInSelectionArea ? ClideSelectionArea(child: sized) : sized,
    );
  }
}

/// Claude's brand coral-orange — a fixed brand accent (not a theme token)
/// used for the "claude" message card's stripe + label.
const claudeAccent = Color(0xFFD97757);

/// The tool names that launch a sub-agent (sidechain). Claude Code emits
/// `Task`; the Agent SDK surface uses `Agent` — accept both (T-263).
bool _isAgentTool(String name) => name == 'Task' || name == 'Agent';

/// Open a governance/ticket record clicked in the conversation (T-279) in its
/// context-pane reader, reusing the existing `selection` MessageBus addressing
/// (the same path `clide ui open` and the panels use, T-231/T-233): T-NNN → the
/// tickets reader, D/Q/R-NNN → the decisions reader.
void _openRecord(BuildContext context, String id) {
  final publisher = id.startsWith('T-') ? 'builtin.tickets' : 'builtin.decisions';
  ClideKernel.of(context).messages.publish(publisher, 'selection', {'id': id});
}

/// Hand a clicked conversation link to the OS URL handler (T-253).
void _openUrl(BuildContext context, String url) {
  unawaited(ClideKernel.of(context).os.openURL(url));
}

/// One conversation item, rendered by kind.
class _ConversationTurn extends StatelessWidget {
  const _ConversationTurn({
    super.key,
    required this.item,
    required this.tokens,
    this.toolUseOutcomes = const <String, bool>{},
    this.toolUseById = const <String, AssistantToolUse>{},
    this.resultByToolUseId = const <String, ToolResultMessage>{},
    this.promptsByToolUseId = const <String, List<UserMessage>>{},
    this.runByToolUseId = const <String, List<ConversationItem>>{},
  });

  final ConversationItem item;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;

  /// Index from toolUseId → AssistantToolUse, for result-card pairing (T-168).
  final Map<String, AssistantToolUse> toolUseById;

  /// Index from toolUseId → its result, so a tool-use card can fold a
  /// successful result into one merged card (T-262).
  final Map<String, ToolResultMessage> resultByToolUseId;

  /// Index from an Agent/Task toolUseId → the sidechain prompt(s) it owns, so
  /// the Agent card can fold its prompt in (T-263).
  final Map<String, List<UserMessage>> promptsByToolUseId;

  /// Index from an Agent/Task toolUseId → the sidechain run items (prose,
  /// thinking, tool cards) nested under the Agent card in a holder (T-264).
  final Map<String, List<ConversationItem>> runByToolUseId;

  @override
  Widget build(BuildContext context) {
    final i = item;
    return switch (i) {
      // Harness-injected (skill load / command expansion / system reminder) and
      // sidechain agent prompts are both NOT typed by the user, so de-emphasise:
      // a muted, collapsed card rather than the blue "you" accent (D-78). A
      // sidechain prompt here is an orphan one (its Agent card couldn't be
      // resolved) — folded prompts are suppressed upstream (T-263).
      UserMessage() when i.injected || i.isSidechain => ConversationCard(
          variant: ConversationCardVariant.bare,
          accent: tokens.globalTextMuted,
          label: i.isSidechain ? 'agent prompt' : 'context',
          copyText: i.text,
          collapsible: true,
          collapsedByDefault: true,
          collapsedSummary: _firstLine(i.text),
          body: ClideText(i.text, muted: true, fontSize: clideFontMeta),
        ),
      UserMessage() => ConversationCard(
          accent: tokens.globalFocus,
          label: 'you',
          copyText: i.text,
          // Pasted-image @path tokens render as inline thumbnails that open the
          // lightbox (T-236/T-254); copyText keeps the original text verbatim.
          body: ClideMarkdown(
            i.text,
            onRecordTap: (id) => _openRecord(context, id),
            onImageToken: (path) => ImageThumbnail(path: path, size: 48),
            onLinkTap: (url) => _openUrl(context, url),
          ),
        ),
      // Sub-agent (sidechain) prose is NOT the main Claude — attribute it to the
      // agent with a muted accent, never the coral "claude" brand (T-265). The
      // coral claudeAccent is reserved for the real main-thread Claude.
      AssistantTextMessage() => ConversationCard(
          accent: i.isSidechain ? tokens.globalTextMuted : claudeAccent,
          label: i.isSidechain ? 'agent' : 'claude',
          copyText: i.text,
          body: ClideMarkdown(i.text, onRecordTap: (id) => _openRecord(context, id), onLinkTap: (url) => _openUrl(context, url)),
        ),
      AssistantThinkingMessage() => ConversationCard(
          variant: ConversationCardVariant.bare,
          accent: tokens.globalTextMuted,
          label: i.isSidechain ? 'agent thinking' : 'thinking',
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
    // T-262: fold the paired result into this card. A successful result becomes
    // a "result" segment below the call + a green header check; a failed result
    // stamps a red header cross but stays a separate prominent error card (the
    // result is not suppressed — see _visibleItems). No result yet (in-flight) →
    // no mark, no segment.
    final result = resultByToolUseId[t.toolUseId];
    final succeeded = result != null && !result.isError;
    final status = result == null ? ConversationCardStatus.none : (result.isError ? ConversationCardStatus.error : ConversationCardStatus.success);

    // T-264: an Agent/Task call nests its whole sub-agent run in a holder below
    // the card. When a run is shown, the returned-result segment would just
    // duplicate the run's final output, so drop it (note E) — but keep it when
    // there's no captured run, so the output is never lost.
    final isAgent = _isAgentTool(t.name);
    final runItems = isAgent ? (runByToolUseId[t.toolUseId] ?? const <ConversationItem>[]) : const <ConversationItem>[];
    final hasRun = runItems.isNotEmpty;

    // T-263: an Agent/Task card folds its sub-agent prompt(s) in. Layered order
    // when expanded (note E): call input (body) → prompt → returned result.
    final segments = <CardSegment>[
      for (final p in promptsByToolUseId[t.toolUseId] ?? const <UserMessage>[])
        CardSegment(label: 'prompt', child: ClideText(p.text, muted: true, fontSize: clideFontMeta)),
      if (succeeded && !(isAgent && hasRun)) CardSegment(label: 'result', child: ClideCodeBlock(source: result.content, language: _resultLanguage(t))),
    ];

    // A resolved permission-prompted call: collapsed, green if approved / red
    // if denied — a quiet record of what was permitted (D-78). It still folds
    // its result + outcome check like any other merged card (T-262).
    final outcome = toolUseOutcomes[t.toolUseId];
    final ConversationCard card;
    if (outcome != null) {
      final color = outcome ? tokens.statusSuccess : tokens.statusError;
      card = ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: color,
        borderColor: color,
        label: t.name,
        copyText: const JsonEncoder.withIndent('  ').convert(t.input),
        collapsible: true,
        collapsedByDefault: true,
        collapsedSummary: _toolUseSummary(t),
        status: status,
        body: toolInputBody(tokens, t.name, t.input),
        extraSegments: segments,
      );
    } else {
      // Per-tool body rendering (T-168): Bash → command block, Edit/Write →
      // diff, Read/Grep/LS → path label, others → indented JSON. Always
      // collapsible so a bulky write body doesn't dominate the scroll.
      card = ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: tokens.globalFocus,
        label: t.name,
        copyText: const JsonEncoder.withIndent('  ').convert(t.input),
        collapsible: true,
        collapsedByDefault: true,
        collapsedSummary: _toolUseSummary(t),
        status: status,
        body: toolInputBody(tokens, t.name, t.input),
        extraSegments: segments,
      );
    }

    if (!hasRun) return card;
    // T-264: nest the sub-agent run in a holder UNDER the Agent card, so a
    // reader can tell where the sub-agent work begins and ends. The run stays
    // VISIBLE (not folded away) — this is attribution + containment.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClideCollapserCard(
            label: 'agent run',
            collapsedSummary: _summarizeActivity(runItems.last),
            counter: runItems.length == 1 ? '1 step' : '${runItems.length} steps',
            children: [
              for (final r in runItems)
                _ConversationTurn(
                  key: ValueKey('run.${r.uuid}'),
                  item: r,
                  tokens: tokens,
                  toolUseOutcomes: toolUseOutcomes,
                  toolUseById: toolUseById,
                  resultByToolUseId: resultByToolUseId,
                  promptsByToolUseId: promptsByToolUseId,
                  runByToolUseId: runByToolUseId,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Per-tool language for the folded result code block (T-262): Read shows the
  /// file's content, so colorize by the file's grammar; Bash output is shell;
  /// everything else (Grep/LS/Write/Edit confirmations/…) falls back to plain.
  String _resultLanguage(AssistantToolUse t) {
    switch (t.name) {
      case 'Read':
        final path = (t.input['file_path'] ?? t.input['path']) as String?;
        return (path != null && path.isNotEmpty ? grammarForPath(path) : null) ?? 'text';
      case 'Bash':
        return 'bash';
      default:
        return 'text';
    }
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
/// (T-230), now through the shared [ClideCollapserCard] container (T-305).
/// Collapsed (default): a one-line live ticker of the latest step + a step
/// count — re-grouped on every rebuild, so the ticker updates in place as the
/// run grows. Expanded: every folded step, wrapped in the collapser frame whose
/// background toggles collapse. Stateless — the collapser owns the expand state.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    super.key,
    required this.items,
    required this.tokens,
    required this.toolUseOutcomes,
    required this.toolUseById,
    required this.resultByToolUseId,
    required this.promptsByToolUseId,
    required this.runByToolUseId,
  });

  final List<ConversationItem> items;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;
  final Map<String, AssistantToolUse> toolUseById;
  final Map<String, ToolResultMessage> resultByToolUseId;
  final Map<String, List<UserMessage>> promptsByToolUseId;
  final Map<String, List<ConversationItem>> runByToolUseId;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    return ClideCollapserCard(
      label: 'Activity',
      collapsedSummary: _summarizeActivity(items.last),
      counter: count == 1 ? '1 step' : '$count steps',
      status: _runStatus(items, resultByToolUseId),
      children: [
        for (final item in items)
          _ConversationTurn(
            key: ValueKey('step.${item.uuid}'),
            item: item,
            tokens: tokens,
            toolUseOutcomes: toolUseOutcomes,
            toolUseById: toolUseById,
            resultByToolUseId: resultByToolUseId,
            promptsByToolUseId: promptsByToolUseId,
            runByToolUseId: runByToolUseId,
          ),
      ],
    );
  }
}

/// Aggregate live status for a run's header tick (T-296): error if any tool in
/// the run failed, else running while its last tool awaits a result, else
/// success. Null (no tools) shows no indicator.
ClideRunStatus? _runStatus(List<ConversationItem> items, Map<String, ToolResultMessage> results) {
  final tools = items.whereType<AssistantToolUse>().toList();
  if (tools.isEmpty) return null;
  for (final t in tools) {
    final r = results[t.toolUseId];
    if (r != null && r.isError) return ClideRunStatus.error;
  }
  return results[tools.last.toolUseId] == null ? ClideRunStatus.running : ClideRunStatus.success;
}

/// A run of consecutive same-file edits, bundled into one collapsible "# edits"
/// card (T-296) through the shared [ClideCollapserCard]. Each edit keeps its own
/// merged tool card when expanded; the header carries the aggregate live tick.
class _EditRunCard extends StatelessWidget {
  const _EditRunCard({
    super.key,
    required this.edits,
    required this.tokens,
    required this.toolUseOutcomes,
    required this.toolUseById,
    required this.resultByToolUseId,
    required this.promptsByToolUseId,
    required this.runByToolUseId,
  });

  final List<ConversationItem> edits;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;
  final Map<String, AssistantToolUse> toolUseById;
  final Map<String, ToolResultMessage> resultByToolUseId;
  final Map<String, List<UserMessage>> promptsByToolUseId;
  final Map<String, List<ConversationItem>> runByToolUseId;

  @override
  Widget build(BuildContext context) {
    final count = edits.length;
    return ClideCollapserCard(
      label: 'Edits',
      collapsedSummary: _summarizeActivity(edits.last),
      counter: count == 1 ? '1 edit' : '$count edits',
      status: _runStatus(edits, resultByToolUseId),
      children: [
        for (final item in edits)
          _ConversationTurn(
            key: ValueKey('edit.${item.uuid}'),
            item: item,
            tokens: tokens,
            toolUseOutcomes: toolUseOutcomes,
            toolUseById: toolUseById,
            resultByToolUseId: resultByToolUseId,
            promptsByToolUseId: promptsByToolUseId,
            runByToolUseId: runByToolUseId,
          ),
      ],
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
