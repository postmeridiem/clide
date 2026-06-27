/// Bootstrap for clide-hosted Claude sessions (Epic B / T-208, D-83).
///
/// D-83 names the clide-HOSTED stream-json session the primary dogfood
/// target: it is the process clide spawns, so clide controls its
/// environment and can hand it everything it needs to drive the IDE
/// without the user explaining anything. This module assembles that
/// hand-off, injected centrally in [ClaudeSessionOrchestrator.spawn] so
/// every hosted session (primary, secondary, fork, teammate) gets it:
///
///   * T-215 — `CLIDE_SOCK` / `CLIDE_WORKSPACE` env + `clide` on PATH, so
///     `clide …` resolves and points at this workspace's socket with zero
///     manual discovery.
///   * T-216 — a context note (`--append-system-prompt`) telling the agent
///     it is inside clide and how to drive it via `clide …` (the D-6
///     parity contract).
///   * T-217 — a `Bash(clide:*)` allow rule (`--allowedTools`) so the agent
///     is not prompted on every `clide …` call.
///
/// The pure helpers ([clideContextNote], [agentEnvDelta], [resolveClideCliDir])
/// hold the logic and are unit-tested directly; [agentBootstrap] is the thin
/// IO wrapper the orchestrator calls. Flutter-free by design.
library;

import 'dart:io';

import 'package:clide/src/env/shell_env.dart' show resolvedToolPath;
import 'package:clide/src/ipc/paths.dart' show workspaceSocketPath;

// Web fence (T-438, D-100): `Abi.current()` (dart:ffi) is desktop-only; the web
// build gets a default dir name with no FFI introspection.
import 'native_abi_stub.dart' if (dart.library.ffi) 'native_abi_io.dart';

/// The `--allowedTools` rule that pre-approves `clide …` Bash calls for a
/// hosted session (T-217), so the agent isn't prompted on every IDE call.
/// Claude Code's settings/flag syntax for a command-scoped Bash rule is
/// `Bash(<prefix>:*)` — see `permissions.allow` in `claude_config.dart`.
const String clideBashAllowRule = 'Bash(clide:*)';

/// Spawn args that carry the [clideBashAllowRule] into a session.
const List<String> clideAllowedToolsArgs = ['--allowedTools', clideBashAllowRule];

/// The agent context note injected via `--append-system-prompt` (T-216).
///
/// Tells a hosted session it is inside clide and how to drive the IDE
/// through the `clide` CLI. Lists only subsystems that dispatch today;
/// the orient-snapshot (`clide status`) and live pane/editor reflection
/// arrive with Epic C (T-218..T-221) and are deliberately left out so the
/// note never points the agent at a command that returns nothing yet.
String clideContextNote(String workspaceRoot) =>
    'You are running inside clide, an IDE that is hosting this session. clide exposes its IDE '
    'surface as a `clide` command on your PATH; drive it with `clide <subsystem> <verb>`. '
    'Subsystems that respond today: `files` (workspace tree — `clide files root`, `files list`), '
    '`editor` (`clide editor open <path>`, `editor active`), `git` (`clide git status`), '
    '`search` (`clide search grep <query>`), `pql` (planning/query), and `panel`/`pane` (layout). '
    'Each command prints JSON to stdout; exit codes are 0=ok, 1=handled error, 3=unknown command. '
    'CLIDE_WORKSPACE holds the workspace root ($workspaceRoot) and CLIDE_SOCK the IPC socket. '
    'Parity contract (D-6): every action the user takes in the UI has a `clide` verb, and `clide` '
    'is how you observe and drive the same workspace the user sees — prefer it for IDE actions so '
    'your work and the user\'s stay in one shared workspace.';

/// Build the environment DELTA to overlay on a hosted session's inherited
/// environment (T-215). `Process.start` keeps the parent environment by
/// default, so this returns only the keys to add/override:
///
///   * `CLIDE_SOCK` — the per-workspace socket ([workspaceSocketPath], D-70).
///   * `CLIDE_WORKSPACE` — the workspace root.
///   * `PATH` — prepended with [clideCliDir] when it is non-null (i.e. `clide`
///     is not already resolvable), otherwise left untouched.
Map<String, String> agentEnvDelta({required String workspaceRoot, required String socketPath, required String? currentPath, required String? clideCliDir}) {
  final delta = <String, String>{'CLIDE_SOCK': socketPath, 'CLIDE_WORKSPACE': workspaceRoot};
  if (clideCliDir != null && clideCliDir.isNotEmpty) {
    delta['PATH'] = (currentPath == null || currentPath.isEmpty) ? clideCliDir : '$clideCliDir:$currentPath';
  }
  return delta;
}

/// Resolve the `CLAUDE_CONFIG_DIR` a session in [cwd] should run under (T-484,
/// epic T-476): the bound account's dir when the workspace is bound, else the
/// parent's `CLAUDE_CONFIG_DIR` when the launcher already set one, else null
/// (Claude defaults to `~/.claude`).
///
/// Pure: the AccountRegistry is injected as a plain [boundConfigDir] lookup
/// (workspace → bound config dir, or null) so this stays Flutter-free — the
/// registry itself lives behind a ChangeNotifier the orchestrator owns.
String? claudeConfigDirForWorkspace({required String cwd, required String? Function(String cwd) boundConfigDir, required Map<String, String> env}) {
  final bound = boundConfigDir(cwd);
  if (bound != null && bound.isNotEmpty) return bound;
  final inherited = env['CLAUDE_CONFIG_DIR'];
  return (inherited != null && inherited.isNotEmpty) ? inherited : null;
}

/// Locate the directory to prepend to a hosted agent's PATH so `clide`
/// resolves (T-215). Returns null when `clide` is ALREADY on [currentPath]
/// (the installed case — T-211 drops it in `~/.local/bin`, normally already
/// on PATH) or when no candidate holds an executable `clide` (degrade
/// gracefully — the session still spawns, the agent just can't call `clide`).
///
/// [candidateDirs] is an ordered fallback list; [isExecutableFile] probes
/// `<dir>/clide`. Both are injected so the resolver is pure and testable.
String? resolveClideCliDir({required String? currentPath, required List<String> candidateDirs, required bool Function(String path) isExecutableFile}) {
  if (currentPath != null) {
    for (final dir in currentPath.split(':')) {
      if (dir.isNotEmpty && isExecutableFile('$dir/clide')) return null;
    }
  }
  for (final dir in candidateDirs) {
    if (dir.isNotEmpty && isExecutableFile('$dir/clide')) return dir;
  }
  return null;
}

/// The result of [agentBootstrap]: the env delta to overlay and the extra
/// spawn args (context note + allow rule) to prepend to a session's argv.
class AgentBootstrap {
  const AgentBootstrap({required this.envDelta, required this.extraArgs});
  final Map<String, String> envDelta;
  final List<String> extraArgs;
}

/// Assemble the full bootstrap for a session spawned in [workspaceRoot]
/// (the IO wrapper over the pure helpers). [base] is the session's existing
/// env (usually null → inherit clide's). The returned [AgentBootstrap.extraArgs]
/// carries the context note; team callers append their own preamble and the
/// orchestrator merges both into one `--append-system-prompt`.
AgentBootstrap agentBootstrap(String workspaceRoot, {Map<String, String>? base, String? Function(String cwd)? boundConfigDir}) {
  final home = Platform.environment['HOME'];
  // The login-shell-resolved PATH (T-439) so a hosted claude — and the tools it
  // shells out to — find user-installed components on a desktop launch, not just
  // the sparse GUI PATH. agentEnvDelta still prepends the clide-CLI dir.
  final currentPath = resolvedToolPath();
  final candidates = <String>[
    if (home != null && home.isNotEmpty) '$home/.local/bin',
    '$workspaceRoot/native/${currentNativeDirName()}',
    File(Platform.resolvedExecutable).parent.path,
  ];
  final cliDir = resolveClideCliDir(currentPath: currentPath, candidateDirs: candidates, isExecutableFile: _isExecutableFile);
  final delta = agentEnvDelta(workspaceRoot: workspaceRoot, socketPath: workspaceSocketPath(workspaceRoot), currentPath: currentPath, clideCliDir: cliDir);
  // Per-repo Claude account (T-484): a bound workspace runs claude under that
  // account's CLAUDE_CONFIG_DIR. Spread BEFORE base so an explicit per-call
  // SpawnSpec.env override still wins (precedence: override > binding > parent
  // env > unset); omitted entirely when there's nothing to set.
  final configDir = claudeConfigDirForWorkspace(cwd: workspaceRoot, boundConfigDir: boundConfigDir ?? (_) => null, env: Platform.environment);
  return AgentBootstrap(envDelta: {'CLAUDE_CONFIG_DIR': ?configDir, ...?base, ...delta}, extraArgs: ['--allowedTools', clideBashAllowRule]);
}

bool _isExecutableFile(String path) {
  final f = File(path);
  if (!f.existsSync()) return false;
  // On POSIX an executable bit is what matters; statSync mode's owner-exec
  // bit (0100) is a sufficient, dependency-free check.
  return (f.statSync().mode & 0x40) != 0;
}
