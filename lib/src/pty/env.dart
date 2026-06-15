/// Default environment for PTY-spawned children and subprocess PATH
/// expansion for macOS GUI apps.
///
/// `xterm.dart` on the UI side + most shells + tmux + Claude CLI all
/// understand the 24-bit-colour triplet `TERM=xterm-256color` +
/// `COLORTERM=truecolor`. Without `COLORTERM` most apps fall back to
/// the 256-colour palette and the terminal looks washed out even though
/// the renderer can do true colour.
library;

import 'package:clide/src/env/shell_env.dart' show resolvedToolPath;

/// The full tool search PATH for PTY children and PATH-resolved subprocess
/// lookup — delegates to the shared resolver ([resolvedToolPath], T-439) so
/// every spawn site agrees: the login-shell PATH (probed once at startup)
/// unioned with the well-known user/local bin dirs. Previously this was a
/// macOS-only merge, so a Linux desktop launch left tools unresolvable.
String get expandedPath => resolvedToolPath();

/// Base env clide builds for every PTY child. Callers merge with the
/// user's environment — a child that needs user env like `HOME` /
/// `USER` / `SHELL` still gets them; the keys here override the ones
/// the child cares about.
const Map<String, String> clidePtyEnvDefaults = {
  'TERM': 'xterm-256color',
  'COLORTERM': 'truecolor',
  // Encourages 24-bit emission from tooling that checks this:
  'CLICOLOR_FORCE': '1',
  // UTF-8 locale for the child and anything it spawns; safe to propagate.
  'LANG': 'en_US.UTF-8',
  'LC_ALL': 'en_US.UTF-8',
};

/// Merge [base] onto the process environment; clide defaults override
/// user env where they overlap. Explicit [overrides] win over both.
Map<String, String> mergePtyEnv({required Map<String, String> processEnv, Map<String, String>? overrides}) {
  return {...processEnv, ...clidePtyEnvDefaults, ...?overrides};
}
