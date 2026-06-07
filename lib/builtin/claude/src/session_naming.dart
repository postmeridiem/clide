/// Claude session-id derivation for clide panes (D-77/T-146).
///
/// Session continuity is via `--resume <session-id>` (D-77); tmux session
/// names are no longer used. This module provides:
///
/// - [primarySessionId] — a stable UUID derived from the repo path, so the
///   primary pane resumes the same transcript across clide restarts.
/// - [freshSessionId] — a fresh random UUID for secondary panes, which always
///   start clean.
/// - [claudeLaunchArgs] — selects `--resume` vs `--session-id` depending on
///   whether the transcript already exists on disk (T-161).
library;

import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math';

// ---------------------------------------------------------------------------
// Internal seed derivation (private — tmux slug names are no longer public)
// ---------------------------------------------------------------------------

// Slug cap kept for backward-compat: the same path still produces the same
// deterministic UUID across upgrades because the seed string is unchanged.
const _maxSlugLen = 80;

/// Derive a stable, short seed from [repoRoot] to feed into the deterministic
/// UUID. This is the old tmux-session-name slug, kept internal and unchanged
/// so existing transcripts survive the tmux→--resume migration (the UUID is
/// derived from this seed, so the UUID must not change).
String _primarySessionSeed(String repoRoot) {
  return 'clide-claude-${_slugify(repoRoot)}';
}

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
/// deterministically derived from the repo path, so the same workspace
/// re-binds the same `<uuid>.jsonl` across restarts (`--resume`, D-77).
String primarySessionId(String repoRoot) => _deterministicUuid(_primarySessionSeed(repoRoot));

/// The session-selection args for launching [sessionId]: `--resume` an
/// existing session, or `--session-id` to create a new one. `--session-id`
/// REFUSES an id that already exists ("Session ID … is already in use") — so
/// resuming a pane whose transcript already exists must use `--resume`
/// (T-161). Appended after the stream-json flags by [ClaudeStreamJsonProcess].
List<String> claudeLaunchArgs(String sessionId, {required bool resume}) => resume ? ['--resume', sessionId] : ['--session-id', sessionId];

/// The session-selection args for forking a session (T-172, D-77).
///
/// `--resume <sourceSessionId> --fork-session` resumes [sourceSessionId] but
/// creates a NEW claude session id so the branch diverges without touching the
/// original. No `--session-id` is passed — the fork gets its own id from the
/// `init` event.
List<String> forkSessionArgs(String sourceSessionId) => ['--resume', sourceSessionId, '--fork-session'];

// ---------------------------------------------------------------------------
// Transcript locations on disk (T-161 / T-268)
// ---------------------------------------------------------------------------

/// The directory claude stores [repoRoot]'s transcripts in:
/// `~/.claude/projects/<munged-repo-root>`, where the munge replaces `/` with
/// `-`. Matches claude's own project-dir naming and is the single source of
/// truth for the path that [ClaudePane] both probes (resume vs create) and
/// lists (`/resume` picker).
String claudeProjectDir(String repoRoot) {
  final home = Platform.environment['HOME'] ?? '';
  return '$home/.claude/projects/${repoRoot.replaceAll('/', '-')}';
}

/// The transcript JSONL path for [sessionId] under [repoRoot]. Its existence is
/// what decides `--resume` vs `--session-id` (T-161).
String claudeTranscriptPath(String repoRoot, String sessionId) => '${claudeProjectDir(repoRoot)}/$sessionId.jsonl';

/// Erase [sessionId]'s transcript under [projectDir] so a subsequent
/// `claude --session-id <sessionId>` re-creates it empty — the in-place
/// `/clear` path for the primary pane (T-268). Removes both the `<id>.jsonl`
/// and the sidecar `<id>/` directory claude keeps beside it. Best-effort:
/// missing entries are not an error. The caller MUST have killed the session's
/// process first, so claude is not mid-write.
Future<void> clearSessionTranscript(String projectDir, String sessionId) async {
  final file = File('$projectDir/$sessionId.jsonl');
  if (await file.exists()) await file.delete();
  final dir = Directory('$projectDir/$sessionId');
  if (await dir.exists()) await dir.delete(recursive: true);
}

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
