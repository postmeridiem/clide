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

/// Tools whose result is a diff the user wants to keep first-class at L1/L2.
bool isDiffTool(String name) => const {'Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'Update'}.contains(name);

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
    // User prose and Claude prose are always first-class.
    case UserMessage():
    case AssistantTextMessage():
      return false;
    // Thinking folds at L2+, first-class at L1.
    case AssistantThinkingMessage():
      return level != FoldLevel.tools;
    case AssistantToolUse(:final name):
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
