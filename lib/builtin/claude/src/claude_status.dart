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

/// The permission-mode cycle, matching Claude Code's own Shift+Tab (T-597):
/// Manual → Accept edits → Plan → [Bypass, when the session allows it] →
/// [Auto, when available] → back to Manual. The optional modes slot in after
/// Plan with bypass first and auto last, as in the CLI.
List<String> permissionModeCycle({required bool autoAvailable, required bool bypassAllowed}) => [
  'default',
  'acceptEdits',
  'plan',
  if (bypassAllowed) 'bypassPermissions',
  if (autoAvailable) 'auto',
];

/// The mode after [current] in [permissionModeCycle] (wraps). A current mode
/// outside the cycle — auto that just became unavailable, `dontAsk` — goes to
/// Manual, as the CLI's first press from auto does.
String nextPermissionMode(String current, {required bool autoAvailable, required bool bypassAllowed}) {
  final cycle = permissionModeCycle(autoAvailable: autoAvailable, bypassAllowed: bypassAllowed);
  final i = cycle.indexOf(current);
  return i < 0 ? 'default' : cycle[(i + 1) % cycle.length];
}

/// Status-line segments split around the permission-mode badge so the UI can
/// render the mode as an interactive control between them (T-226). `leading`
/// is the model; `trailing` joins context / cost / rate-limit. Either may be
/// null when there's nothing to show.
({String? leading, String? trailing}) statusSegmentsAroundMode(SessionStatus s) {
  final trailing = [
    if (s.contextTokens != null) _contextLabel(s),
    if (s.cost != null) '\$${s.cost!.toStringAsFixed(2)}',
    if (s.rateLimitInfo != null) s.rateLimitInfo!,
  ].join('  ·  ');
  return (leading: s.model != null ? shortModelLabel(s.model!) : null, trailing: trailing.isEmpty ? null : trailing);
}

/// Label for Claude's permission modes — the names the desktop app, the IDE
/// extensions and the CLI's own status bar use (T-597): `default` is Manual.
String permissionModeLabel(String mode) {
  switch (mode) {
    case 'default':
    case 'manual':
      return 'Manual';
    case 'acceptEdits':
      return 'Accept edits';
    case 'plan':
      return 'Plan';
    case 'auto':
      return 'Auto';
    case 'dontAsk':
      return "Don't ask";
    case 'bypassPermissions':
      return 'Bypass permissions';
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

/// Parsed `/usage` output (T-415). The CLI answers a forwarded `/usage`
/// headless and free (probed 2.1.175, num_turns 0) with plain text:
///
///   Current session: 15% used · resets Jun 12, 3:39pm (Europe/Amsterdam)
///   Current week (all models): 53% used · resets Jun 15, 6:59pm (…)
///   Current week (Sonnet only): 0% used
class ClaudeUsage {
  const ClaudeUsage({this.session, this.week, this.weekSonnet});

  /// The value text per line (e.g. `15% used · resets Jun 12, 3:39pm`),
  /// timezone parenthetical stripped. Null when the line wasn't present.
  final String? session;
  final String? week;
  final String? weekSonnet;

  bool get isEmpty => session == null && week == null && weekSonnet == null;
}

/// Parse `/usage` response text into a [ClaudeUsage], or null when [text]
/// isn't usage output. Tolerant of label drift: any `Current …: …% used`
/// line is matched by its key phrase.
ClaudeUsage? parseUsageText(String text) {
  if (!text.contains('% used')) return null;
  String? valueOf(String keyPhrase) {
    for (final line in text.split('\n')) {
      if (!line.contains(keyPhrase)) continue;
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      // Strip the trailing timezone parenthetical — noise at sidebar width.
      return line.substring(colon + 1).replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    }
    return null;
  }

  final usage = ClaudeUsage(session: valueOf('Current session'), week: valueOf('(all models)'), weekSonnet: valueOf('(Sonnet only)'));
  return usage.isEmpty ? null : usage;
}
