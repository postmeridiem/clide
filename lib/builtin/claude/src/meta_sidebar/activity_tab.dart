/// The Activity tab: usage stats (stats-cache.json) + the primary
/// session's live runtime row. Split out of claude_meta_sidebar.dart
/// (T-395).
library;

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show formatTokenCount, permissionModeLabel, shortModelLabel;
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';

class ActivityTabView extends StatelessWidget {
  const ActivityTabView({super.key, required this.stats, required this.primaryStatus, required this.config});

  final ClaudeStats stats;
  final SessionStatus? primaryStatus;
  final ClaudeConfig? config;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final latest = stats.latest;
    final sections = <MetaSection>[
      if (latest != null)
        MetaSection('TODAY', [
          MetaRow('messages', '${latest.messageCount}'),
          MetaRow('sessions', '${latest.sessionCount}'),
          MetaRow('tool calls', '${latest.toolCallCount}'),
        ]),
      if (latest != null) MetaSection('LIFETIME', [MetaRow('messages', '${stats.lifetimeMessages}'), MetaRow('sessions', '${stats.lifetimeSessions}')]),
      ..._runtimeSection(tokens),
    ];
    if (sections.isEmpty) {
      return metaPlaceholder('No activity recorded yet.');
    }
    return buildMetaTable(tokens, sections);
  }

  List<MetaSection> _runtimeSection(SurfaceTokens tokens) {
    final st = primaryStatus;
    final skills = config?.skills.length;
    final rows = <MetaRow>[
      if (st?.model != null) MetaRow('model', shortModelLabel(st!.model!), valueColor: tokens.globalFocus),
      if (st?.contextTokens != null) MetaRow('context', '${formatTokenCount(st!.contextTokens!)} ctx'),
      if (st?.permissionMode != null) MetaRow('mode', permissionModeLabel(st!.permissionMode!)),
      if (skills != null) MetaRow('skills', '$skills'),
    ];
    return rows.isEmpty ? const [] : [MetaSection('RUNTIME · primary', rows)];
  }
}
