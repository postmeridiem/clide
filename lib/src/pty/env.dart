/// Default environment for PTY-spawned children and subprocess PATH
/// expansion for macOS GUI apps.
///
/// `xterm.dart` on the UI side + most shells + tmux + Claude CLI all
/// understand the 24-bit-colour triplet `TERM=xterm-256color` +
/// `COLORTERM=truecolor`. Without `COLORTERM` most apps fall back to
/// the 256-colour palette and the terminal looks washed out even though
/// the renderer can do true colour.
library;

import 'dart:io';

/// On macOS, GUI apps inherit a minimal PATH that omits Homebrew,
/// ~/.local/bin, and similar directories. This getter returns the
/// platform PATH with those well-known directories merged in.
/// On Linux/Windows it returns the PATH unchanged.
String get expandedPath {
  _cachedPath ??= _buildExpandedPath();
  return _cachedPath!;
}

String? _cachedPath;

String _buildExpandedPath() {
  final base = Platform.environment['PATH'] ?? '';
  if (!Platform.isMacOS) return base;
  final home = Platform.environment['HOME'] ?? '';
  final extras = <String>[
    if (home.isNotEmpty) '$home/.local/bin',
    '/opt/homebrew/bin',
    '/opt/homebrew/sbin',
    '/usr/local/bin',
  ];
  final existing = base.split(':').toSet();
  final missing = extras.where((p) => !existing.contains(p));
  if (missing.isEmpty) return base;
  return [...missing, ...existing].join(':');
}

/// Base env clide's daemon builds for every PTY child. Callers merge
/// with the user's environment before passing to `ptyc` — a child that
/// needs user env like `HOME` / `USER` / `SHELL` still gets them; the
/// keys here override the ones the child cares about.
const Map<String, String> clidePtyEnvDefaults = {
  'TERM': 'xterm-256color',
  'COLORTERM': 'truecolor',
  // Encourages 24-bit emission from tooling that checks this:
  'CLICOLOR_FORCE': '1',
  // tmux inherits these when clide spawns tmux; safe to propagate.
  'LANG': 'en_US.UTF-8',
  'LC_ALL': 'en_US.UTF-8',
};

/// Merge [base] onto the process environment; clide defaults override
/// user env where they overlap. Explicit [overrides] win over both.
Map<String, String> mergePtyEnv({
  required Map<String, String> processEnv,
  Map<String, String>? overrides,
}) {
  return {
    ...processEnv,
    ...clidePtyEnvDefaults,
    if (overrides != null) ...overrides,
  };
}
