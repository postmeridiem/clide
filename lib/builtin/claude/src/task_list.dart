/// Claude's working task list, modelled from the conversation for the docked
/// task view (T-308).
///
/// Claude tracks tasks with the `TodoWrite` tool, which **replaces the whole
/// list** on each call — so the current state is simply the todos of the most
/// recent `TodoWrite`. This is a latest-wins snapshot, not an append log; older
/// `TodoWrite` calls are superseded.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart';

enum TaskStatus { pending, inProgress, completed }

class TaskItem {
  const TaskItem({required this.text, required this.status});

  final String text;
  final TaskStatus status;

  @override
  bool operator ==(Object other) => other is TaskItem && other.text == text && other.status == status;

  @override
  int get hashCode => Object.hash(text, status);
}

/// The current task list — the todos of the most recent `TodoWrite` tool call,
/// or empty if Claude hasn't written one this session.
List<TaskItem> taskListFrom(List<ConversationItem> items) {
  for (var i = items.length - 1; i >= 0; i--) {
    final it = items[i];
    if (it is! AssistantToolUse || it.name != 'TodoWrite') continue;
    final raw = it.input['todos'];
    if (raw is! List) return const [];
    return [
      for (final t in raw)
        if (t is Map)
          TaskItem(
            // `content` is the canonical label; `activeForm` is the present-tense
            // variant TodoWrite also carries — fall back to it, then to empty.
            text: (t['content'] ?? t['activeForm'] ?? '').toString(),
            status: _statusFrom(t['status']),
          ),
    ];
  }
  return const [];
}

TaskStatus _statusFrom(Object? raw) => switch (raw) {
  'in_progress' => TaskStatus.inProgress,
  'completed' => TaskStatus.completed,
  _ => TaskStatus.pending,
};
