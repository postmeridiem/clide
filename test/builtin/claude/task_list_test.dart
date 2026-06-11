/// Parser for Claude's TodoWrite task list (T-308): latest-wins, status
/// mapping, content/activeForm fallback, and graceful handling of non-TodoWrite
/// or malformed input.
library;

import 'package:clide/builtin/claude/src/task_list.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime.utc(2026);

AssistantToolUse _todo(Object todos, {String id = 'x'}) =>
    AssistantToolUse(uuid: id, timestamp: _t, isSidechain: false, toolUseId: id, name: 'TodoWrite', input: {'todos': todos});

void main() {
  test('parses todos with their status', () {
    final tasks = taskListFrom([
      _todo([
        {'content': 'a', 'status': 'pending'},
        {'content': 'b', 'status': 'in_progress'},
        {'content': 'c', 'status': 'completed'},
      ]),
    ]);
    expect(tasks, const [
      TaskItem(text: 'a', status: TaskStatus.pending),
      TaskItem(text: 'b', status: TaskStatus.inProgress),
      TaskItem(text: 'c', status: TaskStatus.completed),
    ]);
  });

  test('the latest TodoWrite wins — a snapshot, not an append log', () {
    final tasks = taskListFrom([
      _todo([
        {'content': 'old', 'status': 'pending'},
      ], id: '1'),
      _todo([
        {'content': 'new', 'status': 'in_progress'},
      ], id: '2'),
    ]);
    expect(tasks, const [TaskItem(text: 'new', status: TaskStatus.inProgress)]);
  });

  test('content falls back to activeForm then empty; unknown status → pending', () {
    final tasks = taskListFrom([
      _todo([
        {'activeForm': 'doing it', 'status': 'in_progress'},
        {'status': 'weird'},
      ]),
    ]);
    expect(tasks[0].text, 'doing it');
    expect(tasks[1].text, '');
    expect(tasks[1].status, TaskStatus.pending);
  });

  test('no TodoWrite → empty', () {
    expect(taskListFrom(const []), isEmpty);
    expect(
      taskListFrom([
        AssistantToolUse(uuid: 'b', timestamp: _t, isSidechain: false, toolUseId: 'b', name: 'Bash', input: const {'command': 'ls'}),
      ]),
      isEmpty,
    );
  });

  test('malformed todos (not a list) → empty', () {
    expect(taskListFrom([_todo('nope')]), isEmpty);
  });
}
