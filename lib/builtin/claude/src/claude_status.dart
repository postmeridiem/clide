/// Formatting for the per-session status line (T-145): model, permission
/// mode, and context-window token count, joined for the status-bar slot.
///
/// Context is a token *count*, not a percentage — the transcript carries
/// `message.usage` but not the model's context limit, and the model id
/// doesn't encode the 1M vs 200k tier, so a percentage would be guesswork.
library;

import 'package:clide/builtin/claude/src/transcript_reader.dart';

/// Build the status-bar line, e.g. `opus 4.7 · default · 21k ctx · $0.12`.
/// Includes rate-limit info when active. Empty string when there's nothing to show.
String formatStatusLine(SessionStatus status) {
  final parts = [
    if (status.model != null) shortModelLabel(status.model!),
    if (status.permissionMode != null) permissionModeLabel(status.permissionMode!),
    if (status.contextTokens != null) _contextLabel(status),
    if (status.cost != null) '\$${status.cost!.toStringAsFixed(2)}',
    if (status.rateLimitInfo != null) status.rateLimitInfo!,
  ];
  return parts.join('  ·  ');
}

/// Context token count, optionally shown as a fraction when the window
/// size is known: `21k / 1M ctx` vs `21k ctx`.
String _contextLabel(SessionStatus status) {
  final tokens = formatTokenCount(status.contextTokens!);
  if (status.contextWindow != null) {
    final window = formatTokenCount(status.contextWindow!);
    return '$tokens / $window ctx';
  }
  return '$tokens ctx';
}

/// `claude-opus-4-7` → `opus 4.7`; unknown shapes pass through.
String shortModelLabel(String model) {
  final s = model.startsWith('claude-') ? model.substring('claude-'.length) : model;
  final parts = s.split('-');
  if (parts.length >= 2) return '${parts.first} ${parts.sublist(1).join('.')}';
  return s;
}

/// The safe permission-mode cycle: default → acceptEdits → plan → default
/// (T-226/T-181). `bypassPermissions` is intentionally excluded — it's
/// reachable only via an explicit confirmed path (the footgun guard).
const List<String> kSafePermissionCycle = ['default', 'acceptEdits', 'plan'];

/// The next mode in [kSafePermissionCycle] after [current] (wraps). An
/// unknown or `bypassPermissions` current restarts the cycle at `default`.
String nextSafePermissionMode(String current) {
  final i = kSafePermissionCycle.indexOf(current);
  return kSafePermissionCycle[(i + 1) % kSafePermissionCycle.length];
}

/// Status-line segments split around the permission-mode badge so the UI can
/// render the mode as an interactive control between them (T-226). [leading]
/// is the model; [trailing] joins context / cost / rate-limit. Either may be
/// null when there's nothing to show.
({String? leading, String? trailing}) statusSegmentsAroundMode(SessionStatus s) {
  final trailing = [
    if (s.contextTokens != null) _contextLabel(s),
    if (s.cost != null) '\$${s.cost!.toStringAsFixed(2)}',
    if (s.rateLimitInfo != null) s.rateLimitInfo!,
  ].join('  ·  ');
  return (
    leading: s.model != null ? shortModelLabel(s.model!) : null,
    trailing: trailing.isEmpty ? null : trailing,
  );
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
