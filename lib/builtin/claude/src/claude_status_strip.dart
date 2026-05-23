/// A thin per-session status strip (T-145): current model, permission
/// mode, and context-window token count, shown above the conversation.
///
/// Context is a token *count*, not a percentage — the transcript carries
/// `message.usage` but not the model's context limit, and the model id
/// doesn't encode the 1M vs 200k tier, so a percentage would be guesswork.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeStatusStrip extends StatelessWidget {
  const ClaudeStatusStrip({super.key, required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final parts = [
      if (status.model != null) shortModelLabel(status.model!),
      if (status.permissionMode != null) permissionModeLabel(status.permissionMode!),
      if (status.contextTokens != null) '${formatTokenCount(status.contextTokens!)} ctx',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: ClideText(
        parts.join('  ·  '),
        fontSize: clideFontSmall,
        muted: true,
        fontFamily: clideMonoFamily,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// `claude-opus-4-7` → `opus 4.7`; unknown shapes pass through.
String shortModelLabel(String model) {
  final s = model.startsWith('claude-') ? model.substring('claude-'.length) : model;
  final parts = s.split('-');
  if (parts.length >= 2) return '${parts.first} ${parts.sublist(1).join('.')}';
  return s;
}

/// Friendly label for Claude's permission modes.
String permissionModeLabel(String mode) {
  switch (mode) {
    case 'acceptEdits':
      return 'accept-edits';
    case 'bypassPermissions':
      return 'bypass';
    case 'plan':
      return 'plan';
    case 'default':
      return 'default';
    default:
      return mode;
  }
}

/// Compact token count: `765k`, `1.2M`, or the raw number under 1k.
String formatTokenCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).round()}k';
  return '$n';
}
