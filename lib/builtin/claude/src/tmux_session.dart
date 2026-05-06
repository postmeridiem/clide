/// tmux server interactions for Claude panes (D-41 lifecycle).
///
/// `pane.close` only kills the ptyc-spawned tmux *client*; tmux is
/// client/server, so the server-side session keeps running after the
/// client disconnects. To honour D-41 ("closing a secondary kills that
/// tmux session" + "secondary numbering resets between clide runs"),
/// we need explicit `tmux kill-session` calls — that's what lives here.
library;

import 'dart:io';

/// Override-able runner so tests don't shell out for real.
typedef TmuxRunner = Future<ProcessResult> Function(List<String> args);

TmuxRunner tmuxRunner = _defaultRunner;

Future<ProcessResult> _defaultRunner(List<String> args) =>
    Process.run('tmux', args);

const _socket = ['-L', 'clide'];

/// Kill the named tmux session on the clide socket. No-op if the
/// session does not exist (kill-session exits non-zero — we ignore it).
Future<void> killSession(String name) async {
  await tmuxRunner([..._socket, 'kill-session', '-t', name]);
}

/// Return the names of all sessions currently alive on the clide
/// socket. Empty list if the server is not running.
Future<List<String>> listClideSessions() async {
  final r = await tmuxRunner([..._socket, 'list-sessions', '-F', '#{session_name}']);
  if (r.exitCode != 0) return const [];
  return (r.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Kill every secondary clide-claude session whose name begins with
/// [primaryName] and ends with `-<digits>`. Leaves the primary itself
/// alive (D-41).
Future<void> reapSecondaries(String primaryName) async {
  final pattern = RegExp('^${RegExp.escape(primaryName)}-\\d+\$');
  for (final s in await listClideSessions()) {
    if (pattern.hasMatch(s)) {
      await killSession(s);
    }
  }
}

/// Kill every clide-claude session for [primaryName], including the
/// primary itself. Used by the explicit `claude.kill-all-sessions`
/// command when the user wants a hard reset.
Future<void> killAllForRepo(String primaryName) async {
  for (final s in await listClideSessions()) {
    if (s == primaryName || s.startsWith('$primaryName-')) {
      await killSession(s);
    }
  }
}
