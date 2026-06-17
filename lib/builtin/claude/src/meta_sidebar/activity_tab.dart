/// The Activity tab: session controls, usage, stats (stats-cache.json), and
/// the primary session's live runtime row. Split out of
/// claude_meta_sidebar.dart (T-395); session controls + the usage block are
/// the power-panel additions (T-415).
library;

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show ClaudeUsage, formatTokenCount, permissionModeLabel, shortModelLabel;
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ActivityTabView extends StatelessWidget {
  const ActivityTabView({
    super.key,
    required this.stats,
    required this.primaryStatus,
    required this.config,
    this.usage,
    this.workflows = const <String, WorkflowRun>{},
  });

  final ClaudeStats stats;
  final SessionStatus? primaryStatus;
  final ClaudeConfig? config;

  /// Parsed `/usage` output for the usage block, refreshed via the refresh
  /// control (T-415). Null until the first refresh.
  final ClaudeUsage? usage;

  /// Live Workflow runs in the primary session, keyed by launching tool-use id
  /// (T-416). Rendered as an aggregate WORKFLOWS section — one row per run with
  /// its done/total agent count and running/done state.
  final Map<String, WorkflowRun> workflows;

  /// Publish a slash command for the primary pane to execute — the session
  /// controls are the same code path as typing the command (D-6).
  void _command(BuildContext context, String text) {
    ClideKernel.of(context).messages.publish('builtin.claude', 'command', {'text': text});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final latest = stats.latest;
    final u = usage;
    final sections = <MetaSection>[
      ..._workflowSection(tokens),
      if (u != null)
        MetaSection('USAGE', [
          if (u.session != null) MetaRow('session', u.session!),
          if (u.week != null) MetaRow('week (all)', u.week!),
          if (u.weekSonnet != null) MetaRow('week (sonnet)', u.weekSonnet!),
        ]),
      if (latest != null)
        MetaSection('TODAY', [
          MetaRow('messages', '${latest.messageCount}'),
          MetaRow('sessions', '${latest.sessionCount}'),
          MetaRow('tool calls', '${latest.toolCallCount}'),
        ]),
      if (latest != null) MetaSection('LIFETIME', [MetaRow('messages', '${stats.lifetimeMessages}'), MetaRow('sessions', '${stats.lifetimeSessions}')]),
      ..._runtimeSection(tokens),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // SESSION control strip (T-415): drives the primary session through
        // the builtin.claude/command bus — identical to typing the command.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClideText('SESSION', fontSize: clideFontSmall, color: tokens.sidebarSectionHeader),
        ),
        Row(
          children: [
            _control(context, tokens, 'clear', 'trash', '/clear'),
            _control(context, tokens, 'compact', 'arrows-in-simple', '/compact'),
            _control(context, tokens, 'fork', 'git-branch', '/fork'),
            _control(context, tokens, 'resume', 'clock-counter-clockwise', '/resume'),
            const Spacer(),
            _control(context, tokens, 'refresh usage', 'arrow-clockwise', '/usage'),
          ],
        ),
        const SizedBox(height: 6),
        if (sections.isEmpty) metaPlaceholder('No activity recorded yet.') else ...metaTableChildren(tokens, sections),
      ],
    );
  }

  Widget _control(BuildContext context, SurfaceTokens tokens, String label, String glyph, String command) {
    return Semantics(
      button: true,
      label: '$label session',
      excludeSemantics: true,
      onTap: () => _command(context, command),
      child: ClideTappable(
        tooltip: '$label  ·  $command',
        onTap: () => _command(context, command),
        builder: (ctx, hovered, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: ClideIcon(PhosphorIcons.byName(glyph), size: 15, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
        ),
      ),
    );
  }

  /// An aggregate WORKFLOWS section while one or more workflow runs exist this
  /// session (T-416): a row per run — its name and `done/total agents`, tinted
  /// focus while running and success once complete.
  List<MetaSection> _workflowSection(SurfaceTokens tokens) {
    final runs = workflows.values.toList();
    if (runs.isEmpty) return const [];
    return [
      MetaSection('WORKFLOWS', [
        for (final r in runs)
          MetaRow(
            r.name ?? r.taskId ?? 'workflow',
            r.agentCount == 0 ? (r.done ? 'done' : 'starting') : '${r.doneCount}/${r.agentCount} agents${r.done ? ' ✓' : ''}',
            valueColor: r.done ? tokens.statusSuccess : tokens.globalFocus,
          ),
      ]),
    ];
  }

  List<MetaSection> _runtimeSection(SurfaceTokens tokens) {
    final st = primaryStatus;
    final skills = config?.skills.length;
    final rows = <MetaRow>[
      if (st?.model != null) MetaRow('model', shortModelLabel(st!.model!), valueColor: tokens.globalFocus),
      if (st?.effort != null) MetaRow('effort', st!.effort!),
      if (st?.contextTokens != null) MetaRow('context', '${formatTokenCount(st!.contextTokens!)} ctx'),
      if (st?.permissionMode != null) MetaRow('mode', permissionModeLabel(st!.permissionMode!)),
      if (skills != null) MetaRow('skills', '$skills'),
    ];
    return rows.isEmpty ? const [] : [MetaSection('RUNTIME · primary', rows)];
  }
}
