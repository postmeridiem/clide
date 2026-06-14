/// Live state of a Claude Code Workflow run (T-416).
///
/// A Workflow is the harness's multi-agent orchestration tool. The model calls
/// it as an ordinary `tool_use` (`name: "Workflow"`, `input: {script}`); the
/// tool returns immediately ("launched in background") and the run's real
/// progress arrives out-of-band on stream-json `type: "system"` events keyed by
/// the launching tool-use id. This file is the pure, Flutter-free model that
/// folds those events into a snapshot the conversation/sidebar surfaces render.
///
/// Wire shape (captured by the T-416 spike, claude 2.1.175):
///   - `task_started`    — task_id, tool_use_id, description, workflow_name,
///                          prompt (script source)
///   - `task_progress`   — usage{total_tokens,tool_uses,duration_ms}, summary,
///                          and `workflow_progress[]`, a DELTA list mixing
///                          `{type:"workflow_phase", index, title}` and
///                          `{type:"workflow_agent", index, label, phaseIndex?,
///                          phaseTitle?, model, state(start|progress|done),
///                          agentId?}` — partial, merged by index.
///   - `task_updated`    — patch{status, end_time}
///   - `task_notification` — terminal status:"completed", summary, usage
///
/// Limit: these events are ephemeral (not persisted to the resumed transcript
/// JSONL), so live progress shows during the session; on reload only the tool
/// card + its "launched in background" result survive.
library;

/// Lifecycle of a single workflow agent, from its `state` field.
enum WorkflowAgentState { start, progress, done, unknown }

WorkflowAgentState parseWorkflowAgentState(Object? raw) => switch (raw) {
  'start' || 'queued' || 'running' => WorkflowAgentState.start,
  'progress' => WorkflowAgentState.progress,
  'done' || 'complete' || 'completed' => WorkflowAgentState.done,
  _ => WorkflowAgentState.unknown,
};

/// One phase declared by `meta.phases` / a `phase()` call.
class WorkflowPhase {
  const WorkflowPhase({required this.index, required this.title});

  final int index;
  final String title;
}

/// One agent fanned out by the workflow. Fields accrete across `task_progress`
/// deltas — a later delta fills in `agentId` / upgrades `model` / advances
/// `state`, so [mergeDelta] overlays non-null fields onto the prior snapshot.
class WorkflowAgent {
  const WorkflowAgent({
    required this.index,
    required this.label,
    this.model,
    this.state = WorkflowAgentState.start,
    this.agentId,
    this.phaseIndex,
    this.phaseTitle,
  });

  final int index;
  final String label;
  final String? model;
  final WorkflowAgentState state;
  final String? agentId;
  final int? phaseIndex;
  final String? phaseTitle;

  /// Fold a raw `workflow_agent` delta entry onto this snapshot, keeping prior
  /// values where the delta omits a field.
  WorkflowAgent mergeDelta(Map<String, dynamic> e) => WorkflowAgent(
    index: index,
    label: (e['label'] as String?)?.isNotEmpty == true ? e['label'] as String : label,
    model: (e['model'] as String?) ?? model,
    state: e.containsKey('state') ? parseWorkflowAgentState(e['state']) : state,
    agentId: (e['agentId'] as String?) ?? agentId,
    phaseIndex: (e['phaseIndex'] as num?)?.toInt() ?? phaseIndex,
    phaseTitle: (e['phaseTitle'] as String?) ?? phaseTitle,
  );

  static WorkflowAgent fromDelta(Map<String, dynamic> e) => WorkflowAgent(
    index: (e['index'] as num).toInt(),
    label: (e['label'] as String?) ?? '',
    model: e['model'] as String?,
    state: parseWorkflowAgentState(e['state']),
    agentId: e['agentId'] as String?,
    phaseIndex: (e['phaseIndex'] as num?)?.toInt(),
    phaseTitle: e['phaseTitle'] as String?,
  );
}

/// An immutable snapshot of one workflow run. [foldEvent] returns a new snapshot
/// with a single `system` task event applied (the session keeps one per
/// launching tool-use id and replaces it as events arrive).
class WorkflowRun {
  const WorkflowRun({
    required this.toolUseId,
    this.taskId,
    this.name,
    this.description,
    this.summary,
    this.done = false,
    this.totalTokens,
    this.toolUses,
    this.durationMs,
    this.phases = const {},
    this.agents = const {},
  });

  /// The launching `Workflow` tool-use id — the join key to the conversation
  /// card and across all of this run's system events.
  final String toolUseId;

  /// The harness task id (e.g. `wy01fihjt`), assigned at `task_started`.
  final String? taskId;

  /// `workflow_name` from `meta.name`.
  final String? name;
  final String? description;
  final String? summary;

  /// True once a `task_updated{status:completed}` or `task_notification`
  /// terminal event lands.
  final bool done;

  final int? totalTokens;
  final int? toolUses;
  final int? durationMs;

  /// Phase index → phase. Empty for a phase-less workflow.
  final Map<int, WorkflowPhase> phases;

  /// Agent index → agent snapshot.
  final Map<int, WorkflowAgent> agents;

  bool get running => !done;
  int get agentCount => agents.length;
  int get doneCount => agents.values.where((a) => a.state == WorkflowAgentState.done).length;

  /// Agents in index order — the order the script fanned them out.
  List<WorkflowAgent> get orderedAgents {
    final list = agents.values.toList()..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  /// Phases in index order.
  List<WorkflowPhase> get orderedPhases {
    final list = phases.values.toList()..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  WorkflowRun _copyWith({
    String? taskId,
    String? name,
    String? description,
    String? summary,
    bool? done,
    int? totalTokens,
    int? toolUses,
    int? durationMs,
    Map<int, WorkflowPhase>? phases,
    Map<int, WorkflowAgent>? agents,
  }) => WorkflowRun(
    toolUseId: toolUseId,
    taskId: taskId ?? this.taskId,
    name: name ?? this.name,
    description: description ?? this.description,
    summary: summary ?? this.summary,
    done: done ?? this.done,
    totalTokens: totalTokens ?? this.totalTokens,
    toolUses: toolUses ?? this.toolUses,
    durationMs: durationMs ?? this.durationMs,
    phases: phases ?? this.phases,
    agents: agents ?? this.agents,
  );

  /// Apply one `system` task event ([ev]) and return the updated snapshot.
  /// [ev] must already be the decoded envelope; unknown subtypes return `this`.
  WorkflowRun foldEvent(Map<String, dynamic> ev) {
    switch (ev['subtype']) {
      case 'task_started':
        return _copyWith(taskId: ev['task_id'] as String?, name: ev['workflow_name'] as String?, description: ev['description'] as String?);
      case 'task_progress':
        return _foldProgress(ev);
      case 'task_updated':
        final patch = ev['patch'];
        final status = patch is Map ? patch['status'] as String? : null;
        return _copyWith(done: status == 'completed' || status == 'failed' ? true : null);
      case 'task_notification':
        final status = ev['status'] as String?;
        return _copyWith(done: status == 'completed' || status == 'failed' ? true : null, summary: ev['summary'] as String?)._foldUsage(ev['usage']);
      default:
        return this;
    }
  }

  WorkflowRun _foldProgress(Map<String, dynamic> ev) {
    final phases = Map<int, WorkflowPhase>.from(this.phases);
    final agents = Map<int, WorkflowAgent>.from(this.agents);
    final progress = ev['workflow_progress'];
    if (progress is List) {
      for (final raw in progress) {
        if (raw is! Map) continue;
        final e = raw.cast<String, dynamic>();
        final idx = (e['index'] as num?)?.toInt();
        if (idx == null) continue;
        switch (e['type']) {
          case 'workflow_phase':
            phases[idx] = WorkflowPhase(index: idx, title: (e['title'] as String?) ?? 'phase $idx');
          case 'workflow_agent':
            final prior = agents[idx];
            agents[idx] = prior != null ? prior.mergeDelta(e) : WorkflowAgent.fromDelta(e);
        }
      }
    }
    return _copyWith(summary: ev['summary'] as String?, phases: phases, agents: agents)._foldUsage(ev['usage']);
  }

  WorkflowRun _foldUsage(Object? usage) {
    if (usage is! Map) return this;
    return _copyWith(
      totalTokens: (usage['total_tokens'] as num?)?.toInt(),
      toolUses: (usage['tool_uses'] as num?)?.toInt(),
      durationMs: (usage['duration_ms'] as num?)?.toInt(),
    );
  }
}

/// The `system` subtypes that carry workflow run progress (T-416). Other system
/// subtypes (`init`, `hook_*`, `thinking_tokens`) are unrelated and left alone.
const Set<String> kWorkflowSystemSubtypes = {'task_started', 'task_progress', 'task_updated', 'task_notification'};

/// True when [ev] is a `system` event carrying workflow run progress that names
/// a launching tool-use id we can key on.
bool isWorkflowSystemEvent(Map<String, dynamic> ev) =>
    ev['type'] == 'system' && kWorkflowSystemSubtypes.contains(ev['subtype']) && (ev['tool_use_id'] as String?)?.isNotEmpty == true;
