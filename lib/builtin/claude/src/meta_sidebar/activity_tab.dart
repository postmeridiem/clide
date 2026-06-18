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
      ..._workflowSection(context, tokens),
      if (u != null)
        MetaSection(ClideSettings.i18n.string(context, 'activity.section.usage', namespace: 'builtin.claude', placeholder: 'USAGE'), [
          if (u.session != null)
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.session', namespace: 'builtin.claude', placeholder: 'session'), u.session!),
          if (u.week != null)
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.weekAll', namespace: 'builtin.claude', placeholder: 'week (all)'), u.week!),
          if (u.weekSonnet != null)
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.weekSonnet', namespace: 'builtin.claude', placeholder: 'week (sonnet)'), u.weekSonnet!),
        ]),
      if (latest != null)
        MetaSection(ClideSettings.i18n.string(context, 'activity.section.today', namespace: 'builtin.claude', placeholder: 'TODAY'), [
          MetaRow(ClideSettings.i18n.string(context, 'activity.row.messages', namespace: 'builtin.claude', placeholder: 'messages'), '${latest.messageCount}'),
          MetaRow(ClideSettings.i18n.string(context, 'activity.row.sessions', namespace: 'builtin.claude', placeholder: 'sessions'), '${latest.sessionCount}'),
          MetaRow(
            ClideSettings.i18n.string(context, 'activity.row.toolCalls', namespace: 'builtin.claude', placeholder: 'tool calls'),
            '${latest.toolCallCount}',
          ),
        ]),
      if (latest != null)
        MetaSection(ClideSettings.i18n.string(context, 'activity.section.lifetime', namespace: 'builtin.claude', placeholder: 'LIFETIME'), [
          MetaRow(
            ClideSettings.i18n.string(context, 'activity.row.messages', namespace: 'builtin.claude', placeholder: 'messages'),
            '${stats.lifetimeMessages}',
          ),
          MetaRow(
            ClideSettings.i18n.string(context, 'activity.row.sessions', namespace: 'builtin.claude', placeholder: 'sessions'),
            '${stats.lifetimeSessions}',
          ),
        ]),
      ..._runtimeSection(context, tokens),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // SESSION control strip (T-415): drives the primary session through
        // the builtin.claude/command bus — identical to typing the command.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClideText(
            ClideSettings.i18n.string(context, 'activity.section.session', namespace: 'builtin.claude', placeholder: 'SESSION'),
            fontSize: clideFontSmall,
            color: tokens.sidebarSectionHeader,
          ),
        ),
        Row(
          children: [
            _control(
              context,
              tokens,
              ClideSettings.i18n.string(context, 'activity.control.clear', namespace: 'builtin.claude', placeholder: 'clear'),
              'trash',
              '/clear',
            ),
            _control(
              context,
              tokens,
              ClideSettings.i18n.string(context, 'activity.control.compact', namespace: 'builtin.claude', placeholder: 'compact'),
              'arrows-in-simple',
              '/compact',
            ),
            _control(
              context,
              tokens,
              ClideSettings.i18n.string(context, 'activity.control.fork', namespace: 'builtin.claude', placeholder: 'fork'),
              'git-branch',
              '/fork',
            ),
            _control(
              context,
              tokens,
              ClideSettings.i18n.string(context, 'activity.control.resume', namespace: 'builtin.claude', placeholder: 'resume'),
              'clock-counter-clockwise',
              '/resume',
            ),
            const Spacer(),
            _control(
              context,
              tokens,
              ClideSettings.i18n.string(context, 'activity.control.refreshUsage', namespace: 'builtin.claude', placeholder: 'refresh usage'),
              'arrow-clockwise',
              '/usage',
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (sections.isEmpty)
          metaPlaceholder(ClideSettings.i18n.string(context, 'activity.empty', namespace: 'builtin.claude', placeholder: 'No activity recorded yet.'))
        else
          ...metaTableChildren(tokens, sections),
      ],
    );
  }

  Widget _control(BuildContext context, SurfaceTokens tokens, String label, String glyph, String command) {
    return Semantics(
      button: true,
      label: ClideSettings.i18n.interpolated(
        context,
        'activity.control.semantics',
        namespace: 'builtin.claude',
        placeholder: '$label session',
        replacers: [I18nReplacer(from: '{label}', replace: label)],
      ),
      excludeSemantics: true,
      onTap: () => _command(context, command),
      child: ClideTappable(
        tooltip: ClideSettings.i18n.interpolated(
          context,
          'activity.control.tooltip',
          namespace: 'builtin.claude',
          placeholder: '$label  ·  $command',
          replacers: [
            I18nReplacer(from: '{label}', replace: label),
            I18nReplacer(from: '{command}', replace: command),
          ],
        ),
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
  List<MetaSection> _workflowSection(BuildContext context, SurfaceTokens tokens) {
    final runs = workflows.values.toList();
    if (runs.isEmpty) return const [];
    final done = ClideSettings.i18n.string(context, 'activity.workflow.done', namespace: 'builtin.claude', placeholder: 'done');
    final starting = ClideSettings.i18n.string(context, 'activity.workflow.starting', namespace: 'builtin.claude', placeholder: 'starting');
    final fallback = ClideSettings.i18n.string(context, 'activity.workflow.fallback', namespace: 'builtin.claude', placeholder: 'workflow');
    return [
      MetaSection(ClideSettings.i18n.string(context, 'activity.section.workflows', namespace: 'builtin.claude', placeholder: 'WORKFLOWS'), [
        for (final r in runs)
          MetaRow(
            r.name ?? r.taskId ?? fallback,
            r.agentCount == 0 ? (r.done ? done : starting) : '${r.doneCount}/${r.agentCount} agents${r.done ? ' ✓' : ''}',
            valueColor: r.done ? tokens.statusSuccess : tokens.globalFocus,
          ),
      ]),
    ];
  }

  List<MetaSection> _runtimeSection(BuildContext context, SurfaceTokens tokens) {
    final st = primaryStatus;
    final skills = config?.skills.length;
    final rows = <MetaRow>[
      if (st?.model != null)
        MetaRow(
          ClideSettings.i18n.string(context, 'activity.row.model', namespace: 'builtin.claude', placeholder: 'model'),
          shortModelLabel(st!.model!),
          valueColor: tokens.globalFocus,
        ),
      if (st?.effort != null)
        MetaRow(ClideSettings.i18n.string(context, 'activity.row.effort', namespace: 'builtin.claude', placeholder: 'effort'), st!.effort!),
      if (st?.contextTokens != null)
        MetaRow(
          ClideSettings.i18n.string(context, 'activity.row.context', namespace: 'builtin.claude', placeholder: 'context'),
          '${formatTokenCount(st!.contextTokens!)} ctx',
        ),
      if (st?.permissionMode != null)
        MetaRow(
          ClideSettings.i18n.string(context, 'activity.row.mode', namespace: 'builtin.claude', placeholder: 'mode'),
          permissionModeLabel(st!.permissionMode!),
        ),
      if (skills != null) MetaRow(ClideSettings.i18n.string(context, 'activity.row.skills', namespace: 'builtin.claude', placeholder: 'skills'), '$skills'),
    ];
    return rows.isEmpty
        ? const []
        : [MetaSection(ClideSettings.i18n.string(context, 'activity.section.runtime', namespace: 'builtin.claude', placeholder: 'RUNTIME · primary'), rows)];
  }
}
