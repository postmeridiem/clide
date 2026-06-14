/// Tests for the WorkflowRun model (T-416): folding stream-json `system`
/// task_* events — the exact shapes captured by the spike — into a snapshot.
library;

import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isWorkflowSystemEvent', () {
    test('accepts task_* system events that name a tool_use_id', () {
      for (final s in kWorkflowSystemSubtypes) {
        expect(isWorkflowSystemEvent({'type': 'system', 'subtype': s, 'tool_use_id': 'toolu_1'}), isTrue, reason: s);
      }
    });

    test('rejects unrelated system subtypes and non-system events', () {
      expect(isWorkflowSystemEvent({'type': 'system', 'subtype': 'init', 'tool_use_id': 'x'}), isFalse);
      expect(isWorkflowSystemEvent({'type': 'system', 'subtype': 'thinking_tokens'}), isFalse);
      expect(isWorkflowSystemEvent({'type': 'assistant', 'subtype': 'task_progress', 'tool_use_id': 'x'}), isFalse);
      expect(isWorkflowSystemEvent({'type': 'system', 'subtype': 'task_progress'}), isFalse); // no tool_use_id
    });
  });

  group('foldEvent — phase-less run', () {
    test('task_started seeds name/description/taskId', () {
      const run = WorkflowRun(toolUseId: 'toolu_1');
      final r = run.foldEvent({
        'type': 'system',
        'subtype': 'task_started',
        'task_id': 'wy01fihjt',
        'tool_use_id': 'toolu_1',
        'description': 'Two agents return one word each',
        'workflow_name': 'parallel-words',
        'prompt': 'export const meta = ...',
      });
      expect(r.taskId, 'wy01fihjt');
      expect(r.name, 'parallel-words');
      expect(r.description, 'Two agents return one word each');
      expect(r.running, isTrue);
      expect(r.agentCount, 0);
    });

    test('task_progress merges workflow_agent deltas by index', () {
      var run = const WorkflowRun(toolUseId: 'toolu_1');
      // First delta: two agents start, then get their agentIds + real model.
      run = run.foldEvent({
        'type': 'system',
        'subtype': 'task_progress',
        'tool_use_id': 'toolu_1',
        'summary': 'Two agents return one word each',
        'usage': {'total_tokens': 0, 'tool_uses': 0, 'duration_ms': 28},
        'workflow_progress': [
          {'type': 'workflow_agent', 'index': 1, 'label': 'alpha', 'model': 'haiku', 'state': 'start'},
          {'type': 'workflow_agent', 'index': 2, 'label': 'beta', 'model': 'haiku', 'state': 'start'},
          {'type': 'workflow_agent', 'index': 1, 'agentId': 'ae51341336dd3a4a0', 'model': 'claude-haiku-4-5-20251001', 'state': 'start'},
        ],
      });
      expect(run.agentCount, 2);
      expect(run.agents[1]!.label, 'alpha'); // kept from earlier delta
      expect(run.agents[1]!.agentId, 'ae51341336dd3a4a0'); // filled by later delta
      expect(run.agents[1]!.model, 'claude-haiku-4-5-20251001'); // upgraded
      expect(run.summary, 'Two agents return one word each');

      // Second delta: agent 2 advances to done.
      run = run.foldEvent({
        'type': 'system',
        'subtype': 'task_progress',
        'tool_use_id': 'toolu_1',
        'workflow_progress': [
          {'type': 'workflow_agent', 'index': 2, 'agentId': 'a210f9290a5f5d089', 'state': 'done'},
        ],
      });
      expect(run.agents[2]!.state, WorkflowAgentState.done);
      expect(run.agents[1]!.state, WorkflowAgentState.start); // untouched
      expect(run.doneCount, 1);
    });

    test('task_updated and task_notification mark the run done', () {
      var run = const WorkflowRun(toolUseId: 'toolu_1');
      run = run.foldEvent({
        'type': 'system',
        'subtype': 'task_updated',
        'tool_use_id': 'toolu_1',
        'patch': {'status': 'completed', 'end_time': 1},
      });
      expect(run.done, isTrue);

      var run2 = const WorkflowRun(toolUseId: 'toolu_1');
      run2 = run2.foldEvent({
        'type': 'system',
        'subtype': 'task_notification',
        'tool_use_id': 'toolu_1',
        'status': 'completed',
        'summary': 'Dynamic workflow completed',
        'usage': {'total_tokens': 19306, 'tool_uses': 0, 'duration_ms': 1009},
      });
      expect(run2.done, isTrue);
      expect(run2.summary, 'Dynamic workflow completed');
      expect(run2.totalTokens, 19306);
      expect(run2.durationMs, 1009);
    });
  });

  group('foldEvent — phased run', () {
    test('workflow_phase entries register phases; agents carry phase tags', () {
      var run = const WorkflowRun(toolUseId: 'toolu_1');
      run = run.foldEvent({
        'type': 'system',
        'subtype': 'task_progress',
        'tool_use_id': 'toolu_1',
        'workflow_progress': [
          {'type': 'workflow_phase', 'index': 1, 'title': 'Scan'},
          {'type': 'workflow_phase', 'index': 2, 'title': 'Fix'},
          {'type': 'workflow_agent', 'index': 1, 'label': 'scan it', 'phaseIndex': 1, 'phaseTitle': 'Scan', 'model': 'haiku', 'state': 'start'},
        ],
      });
      expect(run.orderedPhases.map((p) => p.title), ['Scan', 'Fix']);
      expect(run.agents[1]!.phaseIndex, 1);
      expect(run.agents[1]!.phaseTitle, 'Scan');
    });
  });

  test('orderedAgents sorts by fan-out index', () {
    var run = const WorkflowRun(toolUseId: 'toolu_1');
    run = run.foldEvent({
      'type': 'system',
      'subtype': 'task_progress',
      'tool_use_id': 'toolu_1',
      'workflow_progress': [
        {'type': 'workflow_agent', 'index': 3, 'label': 'c', 'state': 'start'},
        {'type': 'workflow_agent', 'index': 1, 'label': 'a', 'state': 'start'},
        {'type': 'workflow_agent', 'index': 2, 'label': 'b', 'state': 'start'},
      ],
    });
    expect(run.orderedAgents.map((a) => a.label), ['a', 'b', 'c']);
  });
}
