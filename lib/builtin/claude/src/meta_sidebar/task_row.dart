/// One row in the Team tab's TASKS section: status marker + title +
/// owner + reassign control (T-171). Split out of
/// claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/builtin/claude/src/meta_sidebar/icon_button.dart';
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamBroker, TeamTask;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task, required this.members, required this.broker});

  final TeamTask task;
  final List<TeamMemberJoined> members;
  final TeamBroker? broker;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final marker = switch (task.status) {
      'done' => '✓',
      'claimed' => '◈',
      _ => '○',
    };
    final markerColor = switch (task.status) {
      'done' => tokens.globalTextMuted,
      'claimed' => tokens.globalFocus,
      _ => tokens.globalForeground,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ClideText(marker, fontSize: clideFontSmall, color: markerColor),
          const SizedBox(width: 6),
          Expanded(
            child: ClideText(
              task.title,
              fontSize: clideFontSmall,
              color: task.status == 'done' ? tokens.globalTextMuted : tokens.globalForeground,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.owner != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ClideText(task.owner!, fontSize: clideFontSmall, color: tokens.globalFocus),
            ),
          // Reassign: cycle to the next roster member.
          if (broker != null && broker!.members.length > 1)
            MetaIconButton(
              painter: PhosphorIcons.byName('arrow-clockwise'),
              tooltip: ClideSettings.i18n.string(context, 'taskRow.reassign', namespace: 'builtin.claude', placeholder: 'Reassign task'),
              color: tokens.globalTextMuted,
              onTap: () => _reassign(context),
            ),
        ],
      ),
    );
  }

  void _reassign(BuildContext context) {
    final b = broker;
    if (b == null || members.isEmpty) return;
    final brokerMembers = b.members;
    if (brokerMembers.isEmpty) return;
    // Cycle to the next member after the current owner.
    final currentIndex = brokerMembers.indexWhere((m) => m.name == task.owner);
    final nextIndex = (currentIndex + 1) % brokerMembers.length;
    b.reassignTask(task.id, brokerMembers[nextIndex].id);
  }
}
