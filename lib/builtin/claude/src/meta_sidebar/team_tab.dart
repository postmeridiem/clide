/// The Team tab: the roster cockpit (T-171) — per-member rows with
/// controls, the TASKS section, and the MESSAGES chat feed (T-180).
/// Stateless and props-driven; the parent owns the member list, inject
/// state, and orchestrator wiring. Split out of claude_meta_sidebar.dart
/// (T-395).
///
/// The account `/usage` budget is deliberately NOT shown here: it is
/// per-account (every team session shares one `~/.claude` login), so it can't
/// be split per member — it lives once on the Activity tab, next to the
/// refresh control that fetches it (T-158).
library;

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

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    if (members.isEmpty) {
      return metaPlaceholder(ClideSettings.i18n.string(context, 'team.empty', namespace: 'builtin.claude', placeholder: 'No team active.'));
    }
    final children = <Widget>[
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
