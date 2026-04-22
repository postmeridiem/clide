import 'dart:io';

/// Resolve the daemon unix-socket path.
///
/// Precedence (highest first):
///   1. `CLIDE_SOCKET_PATH` — explicit override. Used by tests that
///      run multiple daemons in parallel and by power users who want
///      their own layout.
///   2. `$XDG_RUNTIME_DIR/clide-<user>.sock` — Linux default; the
///      per-user tmpfs lives exactly for this kind of short-lived
///      socket and is auto-cleaned on logout.
///   3. `/tmp/clide-<user>.sock` — fallback for environments without
///      `XDG_RUNTIME_DIR`.
String defaultSocketPath() {
  final override = Platform.environment['CLIDE_SOCKET_PATH'];
  if (override != null && override.isNotEmpty) return override;
  final xdg = Platform.environment['XDG_RUNTIME_DIR'];
  final user = Platform.environment['USER'] ?? 'anon';
  final base = (xdg != null && xdg.isNotEmpty) ? xdg : '/tmp';
  return '$base/clide-$user.sock';
}
