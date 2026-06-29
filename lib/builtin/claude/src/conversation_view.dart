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
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/bash_tail_source.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show shortModelLabel;
import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/file_tail_follower.dart';
import 'package:clide/builtin/claude/src/icon_card.dart';
import 'package:clide/builtin/claude/src/image_thumbnail.dart';
import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/src/svg/svg_document.dart' show buildSvgDocument;
import 'package:clide/src/svg/svg_node.dart' show SvgDocument;
import 'package:clide/widgets/src/draw/drawing_card.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart' show SvgView;
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:clide/kernel/src/facade.dart';
import 'package:clide/kernel/src/keymap/intents.dart';
import 'package:clide/kernel/src/keymap/pane_key_nav.dart';
import 'package:clide/kernel/src/syntax/language_map.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/src/terminal/terminal.dart';
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
    this.quietErrorToolUseIds = const <String>{},
    this.workflows = const <String, WorkflowRun>{},
    this.foldLevel = FoldLevel.tools,
  });

  final ConversationController controller;

  /// Live Workflow runs keyed by their launching `Workflow` tool-use id
  /// (T-416). A `Workflow` tool-use card with a matching run renders the
  /// dedicated run card (phases, agent rows, status) instead of the generic
  /// tool card; absent (pre-progress, or on reload) it falls back to generic.
  final Map<String, WorkflowRun> workflows;

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

  /// tool_use_ids whose error result should render folded + muted instead of as
  /// a loud red failure (T-340) — expected, user-initiated denials the user
  /// already understands (Deny & simplify). Genuine tool errors (ids not in
  /// here) keep the prominent expanded-red treatment (T-168). A reusable filter:
  /// add ids to quiet more error kinds without string-matching their text.
  final Set<String> quietErrorToolUseIds;

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
  ({Set<String> ownedSidechainUuids, Map<String, List<UserMessage>> promptsByToolUseId, Map<String, List<ConversationItem>> runByToolUseId}) _sidechainFold(
    List<ConversationItem> items,
  ) {
    final agentByMsgUuid = <String, AssistantToolUse>{
      for (final it in items)
        if (it is AssistantToolUse && _isAgentTool(it.name)) it.uuid: it,
    };
    // Stream-json tags sidechain items with the spawning Agent's tool-use id
    // directly (T-338), so map Agent cards by tool-use id for a direct lookup
    // that doesn't depend on the (transcript-only) parentUuid chain.
    final agentByToolUseId = <String, AssistantToolUse>{
      for (final it in items)
        if (it is AssistantToolUse && _isAgentTool(it.name)) it.toolUseId: it,
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

    // With more than one agent in the turn (a parallel fan-out), the
    // "nearest preceding agent" fallback is unsafe: an item with no
    // parent_tool_use_id and no rooted parentUuid chain would mis-file into
    // whichever agent was emitted last — landing in a SIBLING agent's card.
    // Drop the fallback in that case so an unattributable item orphans
    // (rendered inline) rather than cross-attributed (T-342). A single agent
    // has only one possible owner, so the fallback stays safe there.
    final multipleAgents = agentByToolUseId.length > 1;

    AssistantToolUse? resolveOwner(ConversationItem item, AssistantToolUse? nearest) {
      // Direct route: stream-json hands us the spawning Agent's tool-use id on
      // the item itself (T-338) — no chain to walk.
      final byTool = item.parentToolUseId;
      if (byTool != null) {
        final agent = agentByToolUseId[byTool];
        if (agent != null) return agent;
      }
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
      return multipleAgents ? null : nearest;
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
    // Follow the tail — but only when already pinned to it. New items arrive
    // on every streamed token; jumping unconditionally yanks a reader who
    // scrolled up back to the bottom for the whole reply (T-368, twin of the
    // T-297 resize gate).
    if (!_atBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _atBottom) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final allItems = widget.controller.items;
    // T-263/T-264: resolve each sidechain run → owning Agent card before
    // culling, so the run is suppressed up top and folded into / nested under
    // its card.
    final fold = _sidechainFold(allItems);
    final items = _visibleItems(allItems, fold.ownedSidechainUuids);

    if (items.isEmpty) {
      return ColoredBox(
        color: tokens.panelBackground,
        child:
            widget.emptyState ??
            Center(
              child: ClideText(
                ClideSettings.i18n.string(context, 'conversation.empty', namespace: 'builtin.claude', placeholder: 'Waiting for Claude…'),
                muted: true,
              ),
            ),
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
              mono: ClideSettings.fonts.monoOf(context),
              collapseTools: true,
              toolUseOutcomes: widget.toolUseOutcomes,
              quietErrorToolUseIds: widget.quietErrorToolUseIds,
              toolUseById: widget.controller.toolUseById,
              resultByToolUseId: resultByToolUseId,
              promptsByToolUseId: fold.promptsByToolUseId,
              runByToolUseId: fold.runByToolUseId,
              workflows: widget.workflows,
            ),
            FoldedCluster(:final items) => _ActivityCard(
              key: ValueKey('cluster.${items.first.uuid}'),
              items: items,
              tokens: tokens,
              toolUseOutcomes: widget.toolUseOutcomes,
              quietErrorToolUseIds: widget.quietErrorToolUseIds,
              toolUseById: widget.controller.toolUseById,
              resultByToolUseId: resultByToolUseId,
              promptsByToolUseId: fold.promptsByToolUseId,
              runByToolUseId: fold.runByToolUseId,
              workflows: widget.workflows,
            ),
            EditRun(:final edits) => _EditRunCard(
              key: ValueKey('edits.${edits.first.uuid}'),
              edits: edits,
              tokens: tokens,
              toolUseOutcomes: widget.toolUseOutcomes,
              quietErrorToolUseIds: widget.quietErrorToolUseIds,
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
    final body = ColoredBox(
      color: tokens.panelBackground,
      child: widget.wrapInSelectionArea ? ClideSelectionArea(child: sized) : sized,
    );
    // Vim nav scrolls the conversation while this region holds focus under the
    // vim preset (T-406): j/k by a line, ctrl+d/u by half a viewport, gg/G to
    // the ends — G also re-arms follow-tail so new output keeps it pinned.
    return PaneKeyNav(onNav: _onNav, child: body);
  }

  /// One "line" of scroll for j/k — a few text rows' worth.
  static const double _lineScroll = 48;

  void _onNav(NavIntent intent, int count) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final half = p.viewportDimension / 2;
    switch (intent) {
      case NavDownIntent():
        _scrollBy(_lineScroll * count);
      case NavUpIntent():
        _scrollBy(-_lineScroll * count);
      case NavPageDownIntent():
        _scrollBy(half);
      case NavPageUpIntent():
        _scrollBy(-half);
      case NavTopIntent():
        _scroll.jumpTo(0);
        _atBottom = false;
      case NavBottomIntent():
        _scroll.jumpTo(p.maxScrollExtent);
        _atBottom = true; // re-arm follow-tail (T-297)
      case NavExpandOrRightIntent() || NavCollapseOrLeftIntent() || NavActivateIntent():
        break; // a reader pane has no expand/activate semantics
    }
  }

  void _scrollBy(double delta) {
    final p = _scroll.position;
    final target = (p.pixels + delta).clamp(0.0, p.maxScrollExtent);
    _scroll.jumpTo(target);
    _atBottom = (p.maxScrollExtent - target) <= _bottomEpsilon;
  }
}

/// Claude's brand coral-orange — a fixed brand accent (not a theme token)
/// used for the "claude" message card's stripe + label.
const claudeAccent = Color(0xFFD97757);

/// The tool names that launch a sub-agent (sidechain) — shared with the
/// grouping pass so "is this an agent spawn?" has one definition (T-342).
bool _isAgentTool(String name) => isAgentTool(name);

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

/// Resolve a path-like token from the conversation to an absolute workspace
/// file, or null if it doesn't name a real repo file (T-300). Delegates the
/// (pure, testable) path logic to [resolveWorkspaceFilePath] with the open
/// project root.
String? _resolveRepoFile(BuildContext context, String raw) => resolveWorkspaceFilePath(ClideKernel.of(context).project.current?.path, raw);

/// Resolve [raw] (a path-like token) against the workspace [root] to an absolute
/// path, or null if it doesn't name a real file under the repo (T-300). The
/// existence check is what keeps prose ("e.g.", "2.2.0") from linkifying.
/// Relative tokens resolve against [root]; absolute tokens must already live
/// inside it. `..` segments are rejected so a ref can't escape the repo.
@visibleForTesting
String? resolveWorkspaceFilePath(String? root, String raw) {
  if (root == null || raw.isEmpty || raw.contains('..')) return null;
  final abs = raw.startsWith('/') ? raw : '$root/$raw';
  if (!abs.startsWith('$root/')) return null;
  return File(abs).existsSync() ? abs : null;
}

/// Open a clicked workspace file reference in the editor, jumping to [line]
/// when present — the Dart-side twin of `clide editor open <path>` (T-300, D-6).
void _openFile(BuildContext context, String path, int? line) {
  unawaited(ClideKernel.of(context).ipc.request('editor.open', args: {'path': path, 'line': ?line}));
}

/// A live, read-only tail of the file a Bash command follows (T-325).
///
/// Mounts when the Bash card is EXPANDED — the collapser builds its children
/// lazily (clide_collapser_card.dart), so initialising here and tearing down in
/// [dispose] gives the "connect on expand, disconnect on collapse" lifecycle
/// for free. Resolves the followed file from the command against the open
/// workspace; when there's no independent file-backed source (a pipe into
/// `tail`, a path outside the repo) it shows a muted note instead of an empty
/// terminal.
class _BashLiveTail extends StatefulWidget {
  const _BashLiveTail({required this.command});

  final String command;

  @override
  State<_BashLiveTail> createState() => _BashLiveTailState();
}

class _BashLiveTailState extends State<_BashLiveTail> {
  Terminal? _terminal;
  FileTailFollower? _follower;
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return; // resolve once — InheritedWidget access needs context
    _resolved = true;
    final root = ClideKernel.of(context).project.current;
    final source = root == null ? null : detectBashTailSource(widget.command, workspaceRoot: root);
    if (source == null) return; // no file-backed source → muted note in build
    final term = Terminal(maxLines: 1000);
    _terminal = term;
    // writeBytes: the follower's chunk boundaries are arbitrary (it can even
    // start mid-rune by construction) — keep decode state across reads (T-373).
    _follower = FileTailFollower(source, onData: term.writeBytes);
    unawaited(_follower!.start());
  }

  @override
  void dispose() {
    _follower?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _terminal;
    if (term == null) {
      return ClideText(
        ClideSettings.i18n.string(context, 'conversation.bashTail.empty', namespace: 'builtin.claude', placeholder: 'no independent source to follow'),
        muted: true,
        fontSize: clideFontMeta,
      );
    }
    return SizedBox(
      height: 160,
      child: ClipRect(
        child: ClidePtyView(
          terminal: term,
          label: ClideSettings.i18n.string(context, 'conversation.bashTail.label', namespace: 'builtin.claude', placeholder: 'live tail'),
          fontSize: clideFontMeta,
        ),
      ),
    );
  }
}

/// One conversation item, rendered by kind.
class _ConversationTurn extends StatelessWidget {
  const _ConversationTurn({
    super.key,
    required this.item,
    required this.tokens,
    required this.mono,
    this.collapseTools = false,
    this.toolUseOutcomes = const <String, bool>{},
    this.quietErrorToolUseIds = const <String>{},
    this.toolUseById = const <String, AssistantToolUse>{},
    this.resultByToolUseId = const <String, ToolResultMessage>{},
    this.promptsByToolUseId = const <String, List<UserMessage>>{},
    this.runByToolUseId = const <String, List<ConversationItem>>{},
    this.workflows = const <String, WorkflowRun>{},
  });

  final ConversationItem item;
  final SurfaceTokens tokens;

  /// The live monospace family (T-471/T-472), resolved from context by the
  /// parent and threaded in so the context-free tool-body/result helpers honour
  /// the Settings → Appearance choice.
  final String mono;

  /// When true (top-level stream items), a tool use renders as its own
  /// collapser over a one-item list (T-305). When false (already inside a run /
  /// edit collapser), it renders the bare inner content card so collapsers
  /// don't nest.
  final bool collapseTools;

  /// Card bottom margin: the stream rhythm (14) at top level, or the collapser's
  /// even inner spacing (10) when this turn is a collapser child (T-305).
  EdgeInsetsGeometry get _childMargin => collapseTools ? const EdgeInsets.only(bottom: 14) : const EdgeInsets.only(bottom: kClideCardHeaderPadH);
  final Map<String, bool> toolUseOutcomes;

  /// tool_use_ids whose error result folds quietly instead of expanded-red
  /// (T-340) — see [ConversationView.quietErrorToolUseIds].
  final Set<String> quietErrorToolUseIds;

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

  /// Live Workflow runs keyed by launching tool-use id (T-416).
  final Map<String, WorkflowRun> workflows;

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
        // Framed like every other card (T-306) — just muted + collapsed, not
        // the blue "you" accent (D-78); bare read as unfinished next to the
        // carded tool calls.
        variant: ConversationCardVariant.bordered,
        accent: tokens.globalTextMuted,
        label: i.isSidechain
            ? ClideSettings.i18n.string(context, 'conversation.label.agentPrompt', namespace: 'builtin.claude', placeholder: 'agent prompt')
            : ClideSettings.i18n.string(context, 'conversation.label.context', namespace: 'builtin.claude', placeholder: 'context'),
        copyText: i.text,
        collapsible: true,
        collapsedByDefault: true,
        collapsedSummary: _firstLine(i.text),
        margin: _childMargin,
        body: ClideText(i.text, muted: true, fontSize: clideFontMeta),
      ),
      UserMessage() => ConversationCard(
        accent: tokens.globalFocus,
        label: ClideSettings.i18n.string(context, 'conversation.label.you', namespace: 'builtin.claude', placeholder: 'you'),
        copyText: i.text,
        margin: _childMargin,
        // Pasted-image @path tokens render as inline thumbnails that open the
        // lightbox (T-236/T-254); copyText keeps the original text verbatim.
        body: ClideMarkdown(
          i.text,
          onRecordTap: (id) => _openRecord(context, id),
          onImageToken: (path) => ImageThumbnail(path: path, size: 48),
          onLinkTap: (url) => _openUrl(context, url),
          resolveFileRef: (p) => _resolveRepoFile(context, p),
          onOpenFile: (path, line) => _openFile(context, path, line),
        ),
      ),
      // CLI-local output (model "<synthetic>": a forwarded local command's
      // response or a clide-injected notice, T-411) is not Claude speaking —
      // framed + muted like the context card (T-306), attributed to clide.
      AssistantTextMessage() when i.synthetic => ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: tokens.globalTextMuted,
        label: ClideSettings.i18n.string(context, 'conversation.label.clide', namespace: 'builtin.claude', placeholder: 'clide'),
        copyText: i.text,
        margin: _childMargin,
        body: ClideText(i.text, muted: true, fontSize: clideFontMeta),
      ),
      // Sub-agent (sidechain) prose is NOT the main Claude — attribute it to the
      // agent with a muted accent, never the coral "claude" brand (T-265). The
      // coral claudeAccent is reserved for the real main-thread Claude.
      AssistantTextMessage() => ConversationCard(
        accent: i.isSidechain ? tokens.globalTextMuted : claudeAccent,
        label: i.isSidechain
            ? ClideSettings.i18n.string(context, 'conversation.label.agent', namespace: 'builtin.claude', placeholder: 'agent')
            : ClideSettings.i18n.string(context, 'conversation.label.claude', namespace: 'builtin.claude', placeholder: 'claude'),
        copyText: i.text,
        margin: _childMargin,
        body: ClideMarkdown(
          i.text,
          onRecordTap: (id) => _openRecord(context, id),
          onLinkTap: (url) => _openUrl(context, url),
          resolveFileRef: (p) => _resolveRepoFile(context, p),
          onOpenFile: (path, line) => _openFile(context, path, line),
        ),
      ),
      AssistantThinkingMessage() => ConversationCard(
        // Framed + muted like the context card (T-306).
        variant: ConversationCardVariant.bordered,
        accent: tokens.globalTextMuted,
        label: i.isSidechain
            ? ClideSettings.i18n.string(context, 'conversation.label.agentThinking', namespace: 'builtin.claude', placeholder: 'agent thinking')
            : ClideSettings.i18n.string(context, 'conversation.label.thinking', namespace: 'builtin.claude', placeholder: 'thinking'),
        copyText: i.thinking,
        collapsible: true,
        collapsedByDefault: true,
        collapsedSummary: _firstLine(i.thinking),
        margin: _childMargin,
        body: ClideText(i.thinking, muted: true, fontSize: clideFontMeta),
      ),
      AssistantToolUse() => collapseTools ? _toolUseCollapser(context, i) : _toolContentCard(context, i),
      ToolResultMessage() => _toolResult(context, i),
      ImageMessage() => _image(context, i),
      DrawingMessage() => _drawing(context, i),
      IconMessage() => _icon(context, i),
    };
  }

  /// A driven-in drawing card (T-318): the SVG rendered inline by clide's own
  /// CustomPaint engine (D-103), display-only per D-78, with an optional
  /// label/description caption.
  Widget _drawing(BuildContext context, DrawingMessage m) {
    return ConversationCard(
      accent: tokens.globalTextMuted,
      label: ClideSettings.i18n.string(context, 'conversation.label.drawing', namespace: 'builtin.claude', placeholder: 'drawing'),
      body: _DrawingWithImages(
        doc: buildSvgDocument(m.svg),
        label: m.label,
        description: m.description,
        source: m.source,
        sourceLabel: m.source == null
            ? null
            : ClideSettings.i18n.string(context, 'conversation.draw.viewSource', namespace: 'builtin.claude', placeholder: 'view d2 source'),
      ),
    );
  }

  /// A driven-in Phosphor glyph card (T-313): each glyph at a hero size plus a
  /// real-UI-size strip, with optional label/description/color. Display-only
  /// per D-78 — selection happens in the interaction zone, not on the card.
  Widget _icon(BuildContext context, IconMessage m) {
    return ConversationCard(
      accent: tokens.globalTextMuted,
      label: ClideSettings.i18n.string(context, 'conversation.label.icon', namespace: 'builtin.claude', placeholder: 'icons'),
      body: IconGlyphCard(entries: m.entries, defaultColor: m.color),
    );
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
      label: ClideSettings.i18n.string(context, 'conversation.label.image', namespace: 'builtin.claude', placeholder: 'image'),
      copyText: m.path,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Annotation title above the image (T-316), when a --file payload set it.
          if (m.label != null && m.label!.isNotEmpty) ...[
            ClideText(m.label!, fontSize: clideFontMeta, fontWeight: FontWeight.w600, color: tokens.globalForeground),
            const SizedBox(height: 4),
          ],
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
                  child: Image(
                    image: ClideFileImage(m.path),
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, _, _) => _imagePlaceholder(context, m.path),
                  ),
                ),
              ),
            ),
          ),
          if (m.description != null && m.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            ClideText(m.description!, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ],
          if (caption != null && caption.isNotEmpty) ...[const SizedBox(height: 4), ClideText(caption, fontSize: clideFontMeta, color: tokens.globalTextMuted)],
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, String path) {
    ClideKernel.of(context).dialog.show<Object>(
      (ctx, dismiss) => ClideLightbox(
        onDismiss: dismiss,
        child: Image(image: ClideFileImage(path), fit: BoxFit.contain, errorBuilder: (_, _, _) => _imagePlaceholder(ctx, path)),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context, String path) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: tokens.panelBorder),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClideIcon(PhosphorIcons.byName('image'), size: 16, color: tokens.globalTextMuted),
        const SizedBox(width: 8),
        Flexible(
          child: ClideText(
            ClideSettings.i18n.interpolated(
              context,
              'conversation.imagePlaceholder',
              namespace: 'builtin.claude',
              placeholder: 'could not load $path',
              replacers: [I18nReplacer(from: '{path}', replace: path)],
            ),
            fontSize: clideFontMeta,
            color: tokens.globalTextMuted,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );

  /// A standalone tool use (T-305): every tool use is a collapser over a
  /// one-item list. The collapser carries the echoed last line, the count, and
  /// the aggregate status (spinner while in-flight, check / cross once resolved)
  /// — pushed up from the item; the inner card holds the call body + segments
  /// and its own per-item mark. An Agent/Task call also nests its visible
  /// sub-agent run in a second collapser below (T-264).
  Widget _toolUseCollapser(BuildContext context, AssistantToolUse t) {
    // A Workflow tool-use with a live run (T-416) renders the dedicated run
    // card — phases, agent rows, status — instead of the generic tool card. No
    // run yet (pre-progress, or on reload where the system events are gone)
    // falls through to the generic collapser below.
    if (t.name == 'Workflow' && workflows[t.toolUseId] != null) {
      return _workflowCard(context, t, workflows[t.toolUseId]!);
    }
    final outcome = toolUseOutcomes[t.toolUseId];
    final color = outcome == null ? tokens.globalFocus : (outcome ? tokens.statusSuccess : tokens.statusError);
    final collapser = ClideCollapserCard(
      label: _toolNameLabel(context, t.name),
      color: color,
      collapsedSummary: _toolUseSummary(t),
      counter: _stepsCounter(context, 1),
      status: _toolRunStatus(t),
      children: [_toolContentCard(context, t)],
    );

    final runItems = _isAgentTool(t.name) ? (runByToolUseId[t.toolUseId] ?? const <ConversationItem>[]) : const <ConversationItem>[];
    if (runItems.isEmpty) return collapser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        collapser,
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClideCollapserCard(
            label: ClideSettings.i18n.string(context, 'conversation.label.agentRun', namespace: 'builtin.claude', placeholder: 'agent run'),
            collapsedSummary: _summarizeActivity(context, runItems.last),
            counter: _stepsCounter(context, runItems.length),
            children: [
              for (final r in runItems)
                _ConversationTurn(
                  key: ValueKey('run.${r.uuid}'),
                  item: r,
                  tokens: tokens,
                  mono: mono,
                  toolUseOutcomes: toolUseOutcomes,
                  quietErrorToolUseIds: quietErrorToolUseIds,
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

  /// A dedicated card for a Workflow run (T-416): the harness's multi-agent
  /// orchestration. The collapser header carries the run's live status (spinner
  /// while running, check when done) and a `done/total agents` counter; the body
  /// lists each fanned-out agent — grouped under phase headers when the workflow
  /// declared phases — plus the run's usage and the orchestration script.
  Widget _workflowCard(BuildContext context, AssistantToolUse t, WorkflowRun run) {
    final title = run.name ?? ClideSettings.i18n.string(context, 'conversation.label.workflow', namespace: 'builtin.claude', placeholder: 'workflow');
    final color = run.done ? tokens.statusSuccess : tokens.globalFocus;
    final counter = run.agentCount == 0
        ? ClideSettings.i18n.string(context, 'conversation.counter.starting', namespace: 'builtin.claude', placeholder: 'starting')
        : ClideSettings.i18n.interpolated(
            context,
            'conversation.counter.agents',
            namespace: 'builtin.claude',
            placeholder: '${run.doneCount}/${run.agentCount} agents',
            replacers: [
              I18nReplacer(from: '{done}', replace: '${run.doneCount}'),
              I18nReplacer(from: '{total}', replace: '${run.agentCount}'),
            ],
          );
    final detail = run.done ? (run.summary ?? run.description) : run.description;
    final collapsedSummary = (detail == null || detail == title) ? title : '$title · $detail';
    return ClideCollapserCard(
      label: ClideSettings.i18n.string(context, 'conversation.label.workflow', namespace: 'builtin.claude', placeholder: 'workflow'),
      color: color,
      collapsedSummary: collapsedSummary,
      counter: counter,
      status: run.done ? ClideRunStatus.success : ClideRunStatus.running,
      children: [_workflowBody(context, t, run)],
    );
  }

  Widget _workflowBody(BuildContext context, AssistantToolUse t, WorkflowRun run) {
    final agents = run.orderedAgents;
    final phases = run.orderedPhases;
    final rows = <Widget>[];
    if (phases.isEmpty) {
      rows.addAll(agents.map(_workflowAgentRow));
    } else {
      for (final p in phases) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: ClideText(p.title.toUpperCase(), muted: true, fontSize: clideFontMeta - 1, fontWeight: FontWeight.w600),
          ),
        );
        rows.addAll(agents.where((a) => a.phaseIndex == p.index).map(_workflowAgentRow));
      }
      // Agents the deltas never tagged with a phase still render, after the
      // phased groups, so nothing fanned out is silently dropped.
      rows.addAll(agents.where((a) => a.phaseIndex == null).map(_workflowAgentRow));
    }
    if (rows.isEmpty) {
      rows.add(
        ClideText(
          ClideSettings.i18n.string(context, 'conversation.workflow.launching', namespace: 'builtin.claude', placeholder: 'Launching…'),
          muted: true,
          fontSize: clideFontMeta,
        ),
      );
    }

    final script = t.input['script'];
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: run.done ? tokens.statusSuccess : tokens.globalFocus,
      label: run.name ?? ClideSettings.i18n.string(context, 'conversation.label.workflow', namespace: 'builtin.claude', placeholder: 'workflow'),
      copyText: script is String ? script : const JsonEncoder.withIndent('  ').convert(t.input),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      extraSegments: [
        if (run.totalTokens != null && run.totalTokens! > 0)
          CardSegment(
            label: ClideSettings.i18n.string(context, 'conversation.segment.usage', namespace: 'builtin.claude', placeholder: 'usage'),
            child: ClideText('${run.totalTokens} tokens${run.durationMs != null ? ' · ${run.durationMs} ms' : ''}', muted: true, fontSize: clideFontMeta),
          ),
        if (script is String)
          CardSegment(
            label: ClideSettings.i18n.string(context, 'conversation.segment.script', namespace: 'builtin.claude', placeholder: 'script'),
            child: ClideCodeBlock(source: script, language: 'javascript'),
          ),
      ],
      margin: const EdgeInsets.only(bottom: kClideCardHeaderPadH),
    );
  }

  /// One agent row in a workflow card: a state glyph (spinner while running, a
  /// muted check once done), the agent's label, and its model (T-416).
  Widget _workflowAgentRow(WorkflowAgent a) {
    final done = a.state == WorkflowAgentState.done;
    final Widget glyph = done
        ? ClideIcon(PhosphorIcons.byName('check'), size: 12, color: tokens.statusSuccess)
        : ClideSpinner(size: 12, color: tokens.globalTextMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 16, child: Center(child: glyph)),
          const SizedBox(width: 6),
          Expanded(
            child: ClideText(a.label, fontSize: clideFontMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (a.model != null && a.model!.isNotEmpty) ...[
            const SizedBox(width: 8),
            ClideText(shortModelLabel(a.model!), muted: true, fontSize: clideFontMeta - 1),
          ],
        ],
      ),
    );
  }

  /// The inner content card for a tool use (T-305): the call body + folded
  /// CALL/PROMPT/RESULT segments + its own per-item status mark, with NO own
  /// collapse caret — the enclosing collapser owns collapse. Used both as a
  /// run/edit child and as the single child of a standalone tool's collapser.
  Widget _toolContentCard(BuildContext context, AssistantToolUse t) {
    // T-262: fold the paired result into this card. A successful result becomes
    // a "result" segment below the call + a green header check; a failed result
    // stamps a red header cross. No result yet (in-flight) → no mark, no segment.
    final result = resultByToolUseId[t.toolUseId];
    final succeeded = result != null && !result.isError;
    final status = result == null ? ConversationCardStatus.none : (result.isError ? ConversationCardStatus.error : ConversationCardStatus.success);

    // T-264: an Agent/Task call's run is shown in its own collapser, so the
    // returned-result segment would just duplicate the run's final output —
    // drop it (note E) when there's a captured run, keep it otherwise.
    final isAgent = _isAgentTool(t.name);
    final runItems = isAgent ? (runByToolUseId[t.toolUseId] ?? const <ConversationItem>[]) : const <ConversationItem>[];
    final hasRun = runItems.isNotEmpty;

    // T-263: an Agent/Task card folds its sub-agent prompt(s) in. Layered order
    // (note E): call input (body) → prompt → returned result.
    final segments = <CardSegment>[
      for (final p in promptsByToolUseId[t.toolUseId] ?? const <UserMessage>[])
        CardSegment(
          label: ClideSettings.i18n.string(context, 'conversation.segment.prompt', namespace: 'builtin.claude', placeholder: 'prompt'),
          child: ClideText(p.text, muted: true, fontSize: clideFontMeta),
        ),
      if (succeeded && !(isAgent && hasRun))
        CardSegment(
          label: ClideSettings.i18n.string(context, 'conversation.segment.result', namespace: 'builtin.claude', placeholder: 'result'),
          child: ClideCodeBlock(source: result.content, language: _resultLanguage(t)),
        ),
      // T-325: a Bash card that follows a file (`tail -f …`) gets a live,
      // scrolling tail of that file below the result — connected lazily, only
      // while the card is expanded (the collapser builds segments on expand).
      if (t.name == 'Bash' && t.input['command'] is String && bashHasTailIntent(t.input['command'] as String))
        CardSegment(
          label: ClideSettings.i18n.string(context, 'conversation.segment.liveTail', namespace: 'builtin.claude', placeholder: 'live tail'),
          child: _BashLiveTail(command: t.input['command'] as String),
        ),
    ];

    // A resolved permission-prompted call is tinted green if approved / red if
    // denied — a quiet record of what was permitted (D-78).
    final outcome = toolUseOutcomes[t.toolUseId];
    final accent = outcome == null ? tokens.globalFocus : (outcome ? tokens.statusSuccess : tokens.statusError);
    return ConversationCard(
      variant: ConversationCardVariant.bordered,
      accent: accent,
      borderColor: outcome == null ? null : accent,
      label: _toolNameLabel(context, t.name),
      copyText: const JsonEncoder.withIndent('  ').convert(t.input),
      status: status,
      body: toolInputBody(context, tokens, t.name, t.input, mono),
      extraSegments: segments,
      // Inside a collapser the surrounding padding is even on all sides
      // (T-305): a matching bottom margin is the canvas's bottom inset and the
      // inter-item gap in a multi-item run.
      margin: const EdgeInsets.only(bottom: kClideCardHeaderPadH),
    );
  }

  /// Aggregate run status for a tool's collapser tick: a spinner while the call
  /// is in-flight, settling to a check or cross once the result lands (T-305).
  ClideRunStatus _toolRunStatus(AssistantToolUse t) {
    final r = resultByToolUseId[t.toolUseId];
    if (r == null) return ClideRunStatus.running;
    return r.isError ? ClideRunStatus.error : ClideRunStatus.success;
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

  Widget _toolResult(BuildContext context, ToolResultMessage t) {
    final paired = toolUseById[t.toolUseId];
    final accent = t.isError ? tokens.statusError : tokens.globalTextMuted;
    final label = t.isError
        ? ClideSettings.i18n.string(context, 'conversation.label.error', namespace: 'builtin.claude', placeholder: 'error')
        : ClideSettings.i18n.string(context, 'conversation.label.result', namespace: 'builtin.claude', placeholder: 'result');

    // Error result: render the error message prominently (T-168). If we have
    // the paired tool_use, show the tool name as a sub-label so the user can
    // see what failed without expanding.
    //
    // Exception (T-340): an expected, user-initiated denial (Deny & simplify)
    // is noise as a loud red error — the user already knows what they did. Fold
    // it to a muted, collapsed card. Genuine failures keep the expanded-red look.
    if (t.isError) {
      final quiet = quietErrorToolUseIds.contains(t.toolUseId);
      final multiline = t.content.contains('\n');
      final errLabel = quiet ? ClideSettings.i18n.string(context, 'conversation.label.denied', namespace: 'builtin.claude', placeholder: 'denied') : label;
      return ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: quiet ? tokens.globalTextMuted : accent,
        borderColor: quiet ? tokens.panelBorder : tokens.statusError,
        label: paired != null ? '${_toolNameLabel(context, paired.name)} · $errLabel' : errLabel,
        copyText: t.content,
        collapsible: quiet || multiline,
        collapsedByDefault: quiet, // genuine errors stay expanded; a denial folds
        collapsedSummary: (quiet || multiline) ? _firstLine(t.content) : null,
        body: ClideText(t.content, fontSize: clideFontMeta, fontFamily: mono, color: quiet ? tokens.globalTextMuted : tokens.statusError),
      );
    }

    // Success result (T-168): for tools where the output is the main event
    // (Bash, Read, Grep, LS), show the output as a code block so it's readable.
    // For Write/Edit, the result is usually "OK" — keep it as plain text.
    final multiline = t.content.contains('\n');
    final isOutputTool = paired != null && const {'Bash', 'Read', 'Grep', 'LS'}.contains(paired.name);
    final resultLabel = paired != null ? '${_toolNameLabel(context, paired.name)} · $label' : label;
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
          : ClideText(t.content, fontSize: clideFontMeta, fontFamily: mono, color: tokens.globalForeground),
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
    required this.quietErrorToolUseIds,
    required this.toolUseById,
    required this.resultByToolUseId,
    required this.promptsByToolUseId,
    required this.runByToolUseId,
    this.workflows = const <String, WorkflowRun>{},
  });

  final List<ConversationItem> items;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;
  final Set<String> quietErrorToolUseIds;
  final Map<String, AssistantToolUse> toolUseById;
  final Map<String, ToolResultMessage> resultByToolUseId;
  final Map<String, List<UserMessage>> promptsByToolUseId;
  final Map<String, List<ConversationItem>> runByToolUseId;
  final Map<String, WorkflowRun> workflows;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    return ClideCollapserCard(
      label: ClideSettings.i18n.string(context, 'conversation.cluster.activity', namespace: 'builtin.claude', placeholder: 'Activity'),
      collapsedSummary: _summarizeActivity(context, items.last),
      counter: _stepsCounter(context, count),
      status: _runStatus(items, resultByToolUseId),
      children: [
        for (final item in items)
          _ConversationTurn(
            key: ValueKey('step.${item.uuid}'),
            item: item,
            tokens: tokens,
            mono: ClideSettings.fonts.monoOf(context),
            toolUseOutcomes: toolUseOutcomes,
            quietErrorToolUseIds: quietErrorToolUseIds,
            toolUseById: toolUseById,
            resultByToolUseId: resultByToolUseId,
            promptsByToolUseId: promptsByToolUseId,
            runByToolUseId: runByToolUseId,
            workflows: workflows,
          ),
      ],
    );
  }
}

/// Localized display label for a tool name (T-462). File/web/task operations
/// have natural translations; command/proper-name tools (Bash, Grep, Glob,
/// ScheduleWakeup, MCP tools, …) have no catalog key by design and fall back to
/// the raw name — so `warnIfMissing: false` keeps a miss from logging (T-493).
String _toolNameLabel(BuildContext context, String name) =>
    ClideSettings.i18n.string(context, 'tool.name.$name', namespace: 'builtin.claude', placeholder: name, warnIfMissing: false);

/// Localized "N steps" counter for a collapser header (T-462). Singular and
/// plural are distinct catalog keys; the English forms double as the fallback.
String _stepsCounter(BuildContext context, int n) => n == 1
    ? ClideSettings.i18n.string(context, 'conversation.counter.step', namespace: 'builtin.claude', placeholder: '1 step')
    : ClideSettings.i18n.interpolated(
        context,
        'conversation.counter.steps',
        namespace: 'builtin.claude',
        placeholder: '$n steps',
        replacers: [I18nReplacer(from: '{count}', replace: '$n')],
      );

/// Localized "N edits" counter for the edit-run collapser header (T-462).
String _editsCounter(BuildContext context, int n) => n == 1
    ? ClideSettings.i18n.string(context, 'conversation.counter.edit', namespace: 'builtin.claude', placeholder: '1 edit')
    : ClideSettings.i18n.interpolated(
        context,
        'conversation.counter.edits',
        namespace: 'builtin.claude',
        placeholder: '$n edits',
        replacers: [I18nReplacer(from: '{count}', replace: '$n')],
      );

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
    required this.quietErrorToolUseIds,
    required this.toolUseById,
    required this.resultByToolUseId,
    required this.promptsByToolUseId,
    required this.runByToolUseId,
  });

  final List<ConversationItem> edits;
  final SurfaceTokens tokens;
  final Map<String, bool> toolUseOutcomes;
  final Set<String> quietErrorToolUseIds;
  final Map<String, AssistantToolUse> toolUseById;
  final Map<String, ToolResultMessage> resultByToolUseId;
  final Map<String, List<UserMessage>> promptsByToolUseId;
  final Map<String, List<ConversationItem>> runByToolUseId;

  @override
  Widget build(BuildContext context) {
    final count = edits.length;
    return ClideCollapserCard(
      label: ClideSettings.i18n.string(context, 'conversation.cluster.edits', namespace: 'builtin.claude', placeholder: 'Edits'),
      collapsedSummary: _summarizeActivity(context, edits.last),
      counter: _editsCounter(context, count),
      status: _runStatus(edits, resultByToolUseId),
      children: [
        for (final item in edits)
          _ConversationTurn(
            key: ValueKey('edit.${item.uuid}'),
            item: item,
            tokens: tokens,
            mono: ClideSettings.fonts.monoOf(context),
            toolUseOutcomes: toolUseOutcomes,
            quietErrorToolUseIds: quietErrorToolUseIds,
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
String _summarizeActivity(BuildContext context, ConversationItem item) {
  String label(String key, String fallback) => ClideSettings.i18n.string(context, key, namespace: 'builtin.claude', placeholder: fallback);
  switch (item) {
    case AssistantToolUse(:final name, :final input):
      final raw = input['command'] ?? input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['url'];
      final detail = raw is String ? raw.split('\n').first.trim() : '';
      final clipped = detail.length > 72 ? '${detail.substring(0, 72)}…' : detail;
      final toolName = _toolNameLabel(context, name);
      return clipped.isEmpty ? toolName : '$toolName  $clipped';
    case ToolResultMessage(:final isError):
      final result = label('conversation.label.result', 'result');
      return isError ? '↳ $result · ${label('conversation.label.error', 'error')}' : '↳ $result';
    case AssistantThinkingMessage():
      return '${label('conversation.label.thinking', 'thinking')}…';
    case UserMessage(:final text):
      return text;
    case AssistantTextMessage(:final text):
      return text;
    case ImageMessage(:final path):
      return '${label('conversation.label.image', 'image')} $path';
    case DrawingMessage(label: final cardLabel):
      return '${label('conversation.label.drawing', 'drawing')}${cardLabel != null ? ' $cardLabel' : ''}';
    case IconMessage(:final entries):
      return '${label('conversation.label.icon', 'icons')} ${entries.map((e) => e.name).join(', ')}';
  }
}

/// Decode every annotated `<image>` href in [doc] into a `ui.Image` (T-319) —
/// the resolver the renderer + lightbox paint through. A missing/undecodable
/// file is skipped (its cell paints empty), never thrown. [load] (read bytes)
/// and [decode] are injectable so the path is testable off the real filesystem.
Future<Map<String, ui.Image>> loadDrawingImages(
  SvgDocument doc, {
  Future<Uint8List?> Function(String path)? load,
  Future<ui.Image> Function(Uint8List bytes)? decode,
}) async {
  final reader = load ?? _readFileBytes;
  final decoder = decode ?? decodeImageFromList;
  final out = <String, ui.Image>{};
  for (final href in doc.annotations.map((a) => a.href).whereType<String>().toSet()) {
    try {
      final bytes = await reader(href);
      if (bytes != null) out[href] = await decoder(bytes);
    } catch (_) {
      // Missing/undecodable — leave that cell empty.
    }
  }
  return out;
}

Future<Uint8List?> _readFileBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Wraps a [DrawingCard], loading any `<image>` hrefs the SVG references into
/// `ui.Image`s first (T-319) — the renderer + lightbox both paint through the
/// resolver. A drawing with no images (d2, raw svg) loads nothing and renders
/// immediately; a missing/unreadable file is skipped (that cell paints empty).
class _DrawingWithImages extends StatefulWidget {
  const _DrawingWithImages({required this.doc, this.label, this.description, this.source, this.sourceLabel});

  final SvgDocument doc;
  final String? label, description, source, sourceLabel;

  @override
  State<_DrawingWithImages> createState() => _DrawingWithImagesState();
}

class _DrawingWithImagesState extends State<_DrawingWithImages> {
  final Map<String, ui.Image> _images = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final imgs = await loadDrawingImages(widget.doc);
    if (imgs.isEmpty) return;
    if (!mounted) {
      for (final img in imgs.values) {
        img.dispose();
      }
      return;
    }
    setState(() => _images.addAll(imgs));
  }

  @override
  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _images.isEmpty ? null : (String href) => _images[href];
    return DrawingCard(
      document: widget.doc,
      images: resolver,
      label: widget.label,
      description: widget.description,
      source: widget.source,
      sourceLabel: widget.sourceLabel,
      // A data-lightbox element opens the whole drawing, zoomable (T-318); the
      // lightbox paints through the same image resolver (T-319).
      onLightbox: () => ClideKernel.of(context).dialog.show<Object>(
        (ctx, dismiss) => ClideLightbox(
          onDismiss: dismiss,
          child: SvgView(document: widget.doc, images: resolver),
        ),
      ),
    );
  }
}
