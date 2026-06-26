/// The Team tab: the roster cockpit (T-171) — per-member rows with
/// controls, the TASKS section, and the MESSAGES chat feed (T-180).
/// Stateless and props-driven; the parent owns the member list, inject
/// state, and orchestrator wiring. Split out of claude_meta_sidebar.dart
/// (T-395).
///
/// Also carries the shared account budget (T-158): the `/usage` figures are
/// per-ACCOUNT — every team session shares one `~/.claude` login, so this is a
/// single shared budget shown once and labelled as such, NOT a per-member split.
library;

import 'package:clide/builtin/claude/src/claude_status.dart' show ClaudeUsage;
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/roster_row.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/task_row.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamTask;
import 'package:clide/builtin/claude/src/team_chat_sidebar.dart' show TeamChatSidebar;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class TeamTabView extends StatelessWidget {
  const TeamTabView({
    super.key,
    required this.members,
    required this.memberStatus,
    required this.orchestrator,
    required this.tasks,
    required this.injectingAgentId,
    required this.injectController,
    required this.onToggleInject,
    required this.onInjectSubmit,
    required this.onClose,
    required this.onSetPermissionMode,
    required this.onFork,
    required this.onOpenChatPane,
    this.usage,
  });

  final List<TeamMemberJoined> members;
  final Map<String, SessionStatus> memberStatus;
  final ClaudeSessionOrchestrator? orchestrator;
  final List<TeamTask> tasks;
  final String? injectingAgentId;
  final TextEditingController injectController;
  final void Function(String memberName) onToggleInject;
  final void Function(String memberName, String text) onInjectSubmit;
  final void Function(String memberName) onClose;
  final void Function(String memberName, String mode) onSetPermissionMode;
  final void Function(String memberName) onFork;
  final VoidCallback onOpenChatPane;

  /// Parsed `/usage` budget for the account this team shares (T-158). Null until
  /// the first `/usage` refresh (driven from the Activity tab control).
  final ClaudeUsage? usage;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final children = <Widget>[
      ..._accountSection(context, tokens),
      if (members.isEmpty)
        metaPlaceholder(ClideSettings.i18n.string(context, 'team.empty', namespace: 'builtin.claude', placeholder: 'No team active.'))
      else
        for (final m in members)
          AgentRosterRow(
            key: ValueKey(m.agentId),
            member: m,
            status: memberStatus[m.agentId],
            orchestrator: orchestrator,
            injectingAgentId: injectingAgentId,
            injectController: injectController,
            onToggleInject: onToggleInject,
            onInjectSubmit: onInjectSubmit,
            onClose: onClose,
            onSetPermissionMode: onSetPermissionMode,
            onFork: onFork,
          ),
    ];

    if (tasks.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(_taskSection(context, tokens));
    }

    // MESSAGES section (T-180): live broker chat feed + quick-post composer.
    final chatModel = orchestrator?.chatModel;
    final broker = orchestrator?.broker;
    if (chatModel != null && broker != null) {
      children.add(const SizedBox(height: 12));
      children.add(TeamChatSidebar(model: chatModel, broker: broker, onPopOut: onOpenChatPane));
    }

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }

  /// The shared account-budget card (T-158): one ACCOUNT section with the three
  /// `/usage` figures and a caption that it is account-wide, not per-member.
  /// Empty when no `/usage` result has arrived yet.
  List<Widget> _accountSection(BuildContext context, SurfaceTokens tokens) {
    final u = usage;
    if (u == null || (u.session == null && u.week == null && u.weekSonnet == null)) return const [];
    return [
      metaSectionHeader(context, tokens, ClideSettings.i18n.string(context, 'team.section.usage', namespace: 'builtin.claude', placeholder: 'ACCOUNT')),
      metaCard(tokens, [
        if (u.session != null)
          metaCardRow(
            tokens,
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.session', namespace: 'builtin.claude', placeholder: 'session'), u.session!),
          ),
        if (u.week != null)
          metaCardRow(
            tokens,
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.weekAll', namespace: 'builtin.claude', placeholder: 'week (all)'), u.week!),
          ),
        if (u.weekSonnet != null)
          metaCardRow(
            tokens,
            MetaRow(ClideSettings.i18n.string(context, 'activity.row.weekSonnet', namespace: 'builtin.claude', placeholder: 'week (sonnet)'), u.weekSonnet!),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 2, top: 4),
        child: ClideText(
          ClideSettings.i18n.string(context, 'team.usage.shared', namespace: 'builtin.claude', placeholder: 'Shared across the team'),
          muted: true,
          fontSize: clideFontCaption,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _taskSection(BuildContext context, SurfaceTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        metaSectionHeader(context, tokens, ClideSettings.i18n.string(context, 'team.section.tasks', namespace: 'builtin.claude', placeholder: 'TASKS')),
        for (final t in tasks) TaskRow(task: t, members: members, broker: orchestrator?.broker),
      ],
    );
  }
}
