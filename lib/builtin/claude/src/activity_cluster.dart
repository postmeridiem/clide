/// Pure grouping pass for the Claude pane's "activity card" (T-230).
///
/// Folds runs of consecutive "meta" items (tool calls + their results, and —
/// at higher levels — thinking) into one collapsible cluster, so a heavy
/// agent turn doesn't bury the messages that matter (user + Claude prose).
///
/// This file is pure (no Flutter): it turns a flat [ConversationItem] list
/// into a list of [RenderGroup]s — each either a first-class [StickyItem] or
/// a foldable [FoldedCluster]. The widget layer renders sticky items as
/// before and clusters as one [activity card]. Kept separate + unit-tested
/// because the fold rules are the load-bearing part.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart';

/// How aggressively meta items fold. Default is [tools] (L1).
enum FoldLevel {
  /// L0 — never fold; every item renders first-class (the pre-T-230 layout).
  none,

  /// L1 — fold tool calls + their (non-error, non-diff) results only. Diffs
  /// (Edit/Write results) and thinking stay first-class.
  tools,

  /// L2 — also fold thinking. Diffs still stay first-class.
  thinking,

  /// L3 — fold everything except user messages and Claude prose (incl. diffs
  /// and thinking).
  everything,
}

/// Settings key for the persisted activity-card fold level (T-235). App-scoped:
/// a personal viewing preference, not per-repo.
const String kActivityFoldLevelKey = 'app.claude.activityFoldLevel';

/// Parse a stored fold-level name back to a [FoldLevel], defaulting to L1
/// ([FoldLevel.tools]) for null/unknown values.
FoldLevel foldLevelFromName(String? name) => FoldLevel.values.firstWhere((l) => l.name == name, orElse: () => FoldLevel.tools);

/// The next fold level in the cycle none → tools → thinking → everything → none
/// (T-235), for the toggle command.
FoldLevel nextFoldLevel(FoldLevel level) => FoldLevel.values[(level.index + 1) % FoldLevel.values.length];

/// A unit the conversation view renders: either a single first-class item or
/// a folded run of meta items.
sealed class RenderGroup {
  const RenderGroup();
}

/// A first-class item — rendered exactly as before, and it seals the current
/// cluster (a sticky item breaks the run).
final class StickyItem extends RenderGroup {
  const StickyItem(this.item);
  final ConversationItem item;
}

/// A folded run of consecutive foldable items, rendered as one activity card.
/// Never empty.
final class FoldedCluster extends RenderGroup {
  const FoldedCluster(this.items);
  final List<ConversationItem> items;
}

/// A run of 2+ consecutive edits to the SAME file, bundled into one collapsed
/// "# edits" card (T-296). Holds the edit tool-use items (their success results
/// fold into each child card as usual). Always length >= 2.
final class EditRun extends RenderGroup {
  const EditRun(this.edits, this.filePath);
  final List<ConversationItem> edits;
  final String filePath;
}

/// Tools whose result is a diff the user wants to keep first-class at L1/L2.
bool isDiffTool(String name) => const {'Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'Update'}.contains(name);

/// Tool names that spawn a sub-agent (sidechain): Claude Code emits `Task`,
/// the Agent SDK surface uses `Agent`. An agent spawn is ALWAYS its own
/// first-class collapsing card — it breaks the Activity cluster so a fan-out
/// of N agents reads as N cards, never one merged "Activity / N steps" card
/// (T-342). Each card carries its own folded prompt (T-263) + nested run
/// (T-264); the fold mechanics are unchanged, only the grouping boundary.
bool isAgentTool(String name) => name == 'Task' || name == 'Agent';

/// The file an edit tool-use targets, or null if [it] isn't a same-file edit
/// (used to group consecutive edits, T-296).
String? editFilePath(ConversationItem it) {
  if (it is! AssistantToolUse || !isDiffTool(it.name)) return null;
  final p = it.input['file_path'] ?? it.input['path'] ?? it.input['notebook_path'];
  return p is String && p.isNotEmpty ? p : null;
}

/// Coalesce maximal runs of consecutive same-file edit [StickyItem]s into one
/// [EditRun] (T-296). A different file, or any non-edit group, breaks the run;
/// a lone edit stays a [StickyItem]. Run this after [groupConversation], on its
/// output, so it composes with the existing meta-folding (a folded Read cluster
/// between two edit runs splits them — matching the worked example).
List<RenderGroup> coalesceEditRuns(List<RenderGroup> groups) {
  final out = <RenderGroup>[];
  var run = <ConversationItem>[];
  String? runPath;

  void flush() {
    if (run.isEmpty) return;
    out.add(run.length >= 2 ? EditRun(List.unmodifiable(run), runPath!) : StickyItem(run.single));
    run = [];
    runPath = null;
  }

  for (final g in groups) {
    final path = g is StickyItem ? editFilePath(g.item) : null;
    if (path != null) {
      if (runPath != null && path != runPath) flush(); // different file → new run
      runPath = path;
      run.add((g as StickyItem).item);
    } else {
      flush();
      out.add(g);
    }
  }
  flush();
  return out;
}

/// Group [items] into render units per [level]. Pairs tool results to their
/// originating tool-use (by `toolUseId`) so a result can be classified by its
/// tool name (diffs stay first-class at L1/L2).
List<RenderGroup> groupConversation(List<ConversationItem> items, FoldLevel level) {
  // tool_use_id → tool name, so a ToolResultMessage can be classified.
  final toolName = <String, String>{
    for (final it in items)
      if (it is AssistantToolUse) it.toolUseId: it.name,
  };

  final out = <RenderGroup>[];
  var cluster = <ConversationItem>[];

  void flush() {
    if (cluster.isNotEmpty) {
      out.add(FoldedCluster(List.unmodifiable(cluster)));
      cluster = [];
    }
  }

  for (final item in items) {
    if (_isFoldable(item, level, toolName)) {
      cluster.add(item);
    } else {
      flush();
      out.add(StickyItem(item));
    }
  }
  flush();
  return out;
}

bool _isFoldable(ConversationItem item, FoldLevel level, Map<String, String> toolName) {
  if (level == FoldLevel.none) return false;
  switch (item) {
    // User prose, Claude prose, and driven-in image cards are always
    // first-class — an image is the point of the turn, never folded away.
    case UserMessage():
    case AssistantTextMessage():
    case ImageMessage():
      return false;
    // Thinking folds at L2+, first-class at L1.
    case AssistantThinkingMessage():
      return level != FoldLevel.tools;
    case AssistantToolUse(:final name):
      // An Agent/Task spawn is always its own first-class card (T-342) — it
      // breaks the cluster at every level, including L3, so parallel agents
      // never merge into one Activity card.
      if (isAgentTool(name)) return false;
      // A Workflow run is a first-class orchestration card too (T-416): it owns
      // the live agent fan-out, so it never folds into a generic Activity card.
      if (name == 'Workflow') return false;
      // The Edit/Write call stays first-class with its diff at L1/L2.
      if (level == FoldLevel.everything) return true;
      return !isDiffTool(name);
    case ToolResultMessage(:final isError, :final toolUseId):
      // A failed result surfaces — it's first-class and breaks the cluster.
      if (isError) return false;
      if (level == FoldLevel.everything) return true;
      // A diff result (paired with an Edit/Write call) stays first-class.
      return !isDiffTool(toolName[toolUseId] ?? '');
  }
}
