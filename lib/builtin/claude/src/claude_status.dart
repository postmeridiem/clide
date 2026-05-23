/// Formatting for the per-session status line (T-145): model, permission
/// mode, and context-window token count, joined for the status-bar slot.
///
/// Context is a token *count*, not a percentage — the transcript carries
/// `message.usage` but not the model's context limit, and the model id
/// doesn't encode the 1M vs 200k tier, so a percentage would be guesswork.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart';

/// Build the status-bar line, e.g. `opus 4.7 · default · 21k ctx`.
/// Empty string when there's nothing to show.
String formatStatusLine(SessionStatus status) {
  final parts = [
    if (status.model != null) shortModelLabel(status.model!),
    if (status.permissionMode != null) permissionModeLabel(status.permissionMode!),
    if (status.contextTokens != null) '${formatTokenCount(status.contextTokens!)} ctx',
  ];
  return parts.join('  ·  ');
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

/// Configured-skills count for the status line (`12 skills`), from
/// ClaudeConfig — the *environment* side alongside the live session fields
/// (T-154). Null when there are none to show.
String? formatSkillsLabel(int count) => count > 0 ? '$count skill${count == 1 ? '' : 's'}' : null;

/// Compact token count: `765k`, `1.2M`, or the raw number under 1k.
String formatTokenCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).round()}k';
  return '$n';
}
