/// The single source of truth for the PATH clide hands to every tool it
/// spawns — git, pql, the toolchain probe, PTY children, hosted claude (T-439).
///
/// A desktop/dock-launched GUI process inherits a minimal PATH (roughly
/// `/usr/bin:/bin`): it never sources `~/.bashrc` / `~/.zprofile` /
/// `/etc/profile.d` / brew shellenv, so `~/.local/bin`, Homebrew, and any
/// user-customized dirs (nvm/pyenv/cargo/asdf/…) are absent and tool resolution
/// fails even though a terminal launch would find them. Two layers, in order:
///
///   1. [primeLoginShellPath] probes the user's actual login shell once at
///      startup (`$SHELL -l -c …`) — the real PATH, not a guess — and caches it.
///   2. [expandToolPath] additionally unions in the well-known user/local bin
///      dirs, so resolution still works when the probe is unavailable (Windows,
///      timeout, spawn failure) or the shell's profile omits a dir we know.
///
/// Flutter-free (used by `GitClient` / `PqlClient` under `dart test`).
library;

import 'dart:io';

String? _loginShellPath;
bool _primed = false;

/// Probe the user's login shell for its `PATH`, once, and cache it. Desktop-only
/// — the caller guards on `!kIsWeb`. Idempotent. Graceful: on Windows (no
/// login-shell convention), a missing `$SHELL`, a non-zero exit, a timeout, or a
/// spawn failure, the cache stays null and [currentSearchPath] falls back to the
/// process `PATH` (still hardcoded-merged by [expandToolPath]).
///
/// [run] is injectable for tests; [timeout] bounds the probe so a misbehaving
/// profile can never hang startup.
Future<void> primeLoginShellPath({
  Future<ProcessResult> Function(String executable, List<String> arguments)? run,
  String? shell,
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (_primed) return;
  _primed = true;
  if (Platform.isWindows) return; // PowerShell has no `-l -c` PATH convention.
  final sh = shell ?? Platform.environment['SHELL'];
  if (sh == null || sh.isEmpty) return;
  final runner = run ?? (e, a) => Process.run(e, a);
  try {
    // `-l -c`: a login shell (sources the profile files that set the real PATH)
    // but non-interactive (no prompt, no hang). Frame the value in sentinels so
    // any MOTD / profile chatter on stdout is stripped.
    final res = await runner(sh, ['-l', '-c', r'printf "__CLIDE_PATH__%s__CLIDE_PATH__" "$PATH"']).timeout(timeout);
    if (res.exitCode != 0) return;
    final out = res.stdout is String ? res.stdout as String : '';
    final m = RegExp(r'__CLIDE_PATH__(.*?)__CLIDE_PATH__', dotAll: true).firstMatch(out);
    final path = m?.group(1)?.trim();
    if (path != null && path.isNotEmpty) _loginShellPath = path;
  } catch (_) {
    // timeout / spawn failure → leave the cache null and fall back.
  }
}

/// The base search PATH: the login-shell PATH if [primeLoginShellPath] resolved
/// one, else the process `PATH`. Not yet merged with the well-known dirs — use
/// [resolvedToolPath] for the full search path.
String currentSearchPath() => _loginShellPath ?? Platform.environment['PATH'] ?? '';

/// The full PATH clide should hand to spawned tools: the login-shell/process
/// PATH unioned with the well-known user/local bin dirs. The single resolver
/// every spawn site calls.
String resolvedToolPath() => expandToolPath(currentSearchPath(), isMac: Platform.isMacOS, isLinux: Platform.isLinux, home: Platform.environment['HOME']);

/// Pure PATH-expansion: prepend the well-known user/local bin dirs that a
/// desktop launch drops, de-duplicated, so they take precedence over a stale
/// system copy (T-347). Homebrew dirs are macOS-only. On platforms that aren't
/// macOS/Linux the base passes through unchanged. Extracted so it's testable
/// without touching the process environment.
String expandToolPath(String base, {required bool isMac, required bool isLinux, String? home}) {
  if (!isMac && !isLinux) return base;
  final h = home ?? '';
  final extras = <String>[if (h.isNotEmpty) '$h/.local/bin', if (isMac) '/opt/homebrew/bin', if (isMac) '/opt/homebrew/sbin', '/usr/local/bin'];
  final existing = base.split(':').toSet();
  final missing = extras.where((p) => !existing.contains(p));
  if (missing.isEmpty) return base;
  return [...missing, ...existing].join(':');
}

/// The raw login-shell PATH the probe captured, or null when it is
/// unavailable (probe failed / not yet primed / Windows). `env path capture`
/// (D-106) diffs this against the process PATH to suggest preset entries.
String? loginShellPathOrNull() => _loginShellPath;

/// Test seam: force the cached login-shell PATH (and mark primed).
void debugSetLoginShellPath(String? value) {
  _loginShellPath = value;
  _primed = true;
}

/// Test seam: clear the cache so [primeLoginShellPath] probes again.
void debugResetLoginShellPath() {
  _loginShellPath = null;
  _primed = false;
}
