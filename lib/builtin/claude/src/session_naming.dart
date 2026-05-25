/// Derive deterministic tmux session names for Claude panes (D-041).
///
/// The primary session name encodes the repo path in a human-readable
/// form: `clide-claude-<path-slug>`. For example:
///   ~/projects/clide     → clide-claude-projects-clide
///   /var/mnt/data/myapp  → clide-claude-var-mnt-data-myapp
///
/// Secondary sessions append `-N`.
///
/// Also derives the Claude `--session-id` for each pane (T-146): a pane's
/// transcript is named `<session-id>.jsonl`, so binding each pane to a
/// distinct UUID is how concurrent sessions in one workspace stay
/// independent. The primary's id is deterministic from its (stable)
/// session name so it resumes across restarts; secondaries get a fresh
/// random id each spawn so a clean session is always one click away.
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

/// Stable session name for the primary Claude pane of [repoRoot].
String primarySessionName(String repoRoot) {
  return 'clide-claude-${_slugify(repoRoot)}';
}

/// Nth secondary session name. [n] starts at 1.
String secondarySessionName(String repoRoot, int n) {
  return '${primarySessionName(repoRoot)}-$n';
}

// tmux session names max out at 256 chars; keep ours well under.
const _maxSlugLen = 80;

String _slugify(String path) {
  final home = Platform.environment['HOME'] ?? '';
  var p = path;
  if (home.isNotEmpty && p.startsWith(home)) {
    p = p.substring(home.length);
  }
  p = p.replaceAll('/', '-').replaceAll('.', '');
  while (p.startsWith('-')) {
    p = p.substring(1);
  }
  while (p.endsWith('-')) {
    p = p.substring(0, p.length - 1);
  }
  if (p.isEmpty) p = 'root';
  if (p.length > _maxSlugLen) return _hash(path);
  return p;
}

String _hash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

// ---------------------------------------------------------------------------
// Claude session-id (UUID) derivation — T-146
// ---------------------------------------------------------------------------

/// Stable session id for the primary pane of [repoRoot]: a UUID
/// deterministically derived from the primary session name, so the same
/// workspace re-binds the same `<uuid>.jsonl` across restarts (resume).
String primarySessionId(String repoRoot) => _deterministicUuid(primarySessionName(repoRoot));

/// The session-selection args for launching [sessionId]: `--resume` an
/// existing session, or `--session-id` to create a new one. `--session-id`
/// REFUSES an id that already exists ("Session ID … is already in use") — so
/// resuming a pane whose transcript already exists must use `--resume`
/// (T-161). Appended after the stream-json flags by [ClaudeStreamJsonProcess].
List<String> claudeLaunchArgs(String sessionId, {required bool resume}) => resume ? ['--resume', sessionId] : ['--session-id', sessionId];

/// A fresh random session id for a secondary pane — secondaries are
/// always clean sessions, never resumed.
String freshSessionId() {
  final r = Random.secure();
  return _formatUuid(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Deterministic, valid-format UUID derived from [seed] (same seed →
/// same id). Expands an FNV-1a stream into 16 bytes.
String _deterministicUuid(String seed) {
  final bytes = <int>[];
  var h = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (var i = 0; i < 16; i++) {
    for (final c in utf8.encode('$seed:$i')) {
      h ^= c;
      h = (h * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    bytes.add(h & 0xff);
  }
  return _formatUuid(bytes);
}

/// Format 16 [bytes] as a canonical v4 UUID string (sets the version and
/// variant nibbles so it passes `--session-id`'s UUID validation).
String _formatUuid(List<int> bytes) {
  final b = List<int>.of(bytes);
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
