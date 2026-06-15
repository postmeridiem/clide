/// Flutter-free toolchain data + resolution.
///
/// Split out of `toolchain.dart` so that pure-Dart consumers (the IPC
/// subsystems exported through `package:clide/clide.dart`, e.g.
/// [GitClient] and [PqlClient]) don't transitively pull in
/// `package:flutter/foundation.dart`. The live, listenable `Toolchain`
/// stays in `toolchain.dart`; everything here is plain Dart and runs
/// fine under `dart test`.
library;

import 'dart:io';

import 'package:clide/src/env/shell_env.dart';

// The canonical PATH-expansion logic now lives in shell_env (T-439, the single
// source of truth shared with git/pql/PTY/claude). Re-exported so existing
// importers/tests keep resolving it from here.
export 'package:clide/src/env/shell_env.dart' show expandToolPath;

/// Serializable result of tool resolution (crosses isolate boundary).
class ResolvedPaths {
  const ResolvedPaths({this.git, this.pql, this.shell, this.gitEnv});

  final String? git;
  final String? pql;
  final String? shell;
  final Map<String, String>? gitEnv;
}

/// Read-only view of resolved tool paths. The concrete `Toolchain`
/// (in `toolchain.dart`) implements this on top of `ChangeNotifier`;
/// pure-Dart clients depend on the interface so they stay Flutter-free.
abstract class ToolchainView {
  /// A fixed, already-resolved view over [paths]. Flutter-free — handy
  /// for tests and isolate-side code that has a [ResolvedPaths] but no
  /// need for the listenable `Toolchain`.
  const factory ToolchainView.resolved(ResolvedPaths paths) = _StaticToolchain;

  String get git;
  String get pql;
  String get shell;
  Map<String, String>? get gitEnv;
  bool get resolved;
  bool get allOk;
  List<String> get missing;
}

class _StaticToolchain implements ToolchainView {
  const _StaticToolchain(this._paths);

  final ResolvedPaths _paths;

  @override
  String get git => _paths.git ?? 'git';
  @override
  String get pql => _paths.pql ?? 'pql';
  @override
  String get shell => _paths.shell ?? (Platform.isWindows ? 'powershell.exe' : '/bin/bash');
  @override
  Map<String, String>? get gitEnv => _paths.gitEnv;
  @override
  bool get resolved => true;
  @override
  bool get allOk => missing.isEmpty;
  @override
  List<String> get missing => [if (_paths.git == null) 'git', if (_paths.pql == null) 'pql'];
}

/// Top-level function for compute/isolate use. Returns a plain-data
/// result with all tool paths resolved against trusted locations only.
///
/// Critically does NOT take a workspace path: per T-98, resolving the
/// dugite-bundled git against the open workspace was a code-execution
/// vector (a malicious repo could plant `native/dugite/bin/git`).
/// Dugite is resolved against the install directory + an explicit env
/// override; everything else comes from PATH.
ResolvedPaths resolveToolchainPaths() {
  String? git;
  Map<String, String>? gitEnv;
  final dugiteGit = _resolveDugiteGit();
  if (dugiteGit != null) {
    git = dugiteGit;
    final dugiteRoot = File(dugiteGit).parent.parent.path;
    gitEnv = {'GIT_EXEC_PATH': '$dugiteRoot/libexec/git-core', 'GIT_TEMPLATE_DIR': '$dugiteRoot/share/git-core/templates'};
  } else {
    git = _findOnPath('git');
  }

  return ResolvedPaths(git: git, pql: _findOnPath('pql'), shell: _resolveShell(), gitEnv: gitEnv);
}

/// The user's interactive shell. POSIX honours `$SHELL`; Windows has
/// no such convention — prefer PowerShell 7 (`pwsh`), fall back to
/// Windows PowerShell (present on every supported Windows).
String? _resolveShell() {
  if (Platform.isWindows) {
    return _findOnPath('pwsh') ?? _findOnPath('powershell');
  }
  return _findOnPath(Platform.environment['SHELL']?.split('/').last ?? 'bash');
}

/// Locate the dugite-bundled git binary in trusted install locations
/// only. **Never inspects workspace-relative paths** — see T-98.
///
/// Search order:
///   1. `CLIDE_DUGITE_DIR` env var (dev override; points at a dugite
///      root that contains `bin/git`).
///   2. `<exe-parent>/dugite/bin/git` — production bundle layout.
///   3. `<exe-parent>/lib/dugite/bin/git` — alternate bundle layout
///      (mirrors Linux's INSTALL_BUNDLE_LIB_DIR convention).
///
/// Returns null if no dugite is found; caller falls back to PATH git.
String? _resolveDugiteGit() {
  // dugite-native's Windows layout differs (cmd\git.exe, mingw64
  // libexec) and isn't wired up yet — PATH git serves Windows until
  // the bundle work lands.
  if (Platform.isWindows) return null;
  final candidates = <String>[];
  final envDir = Platform.environment['CLIDE_DUGITE_DIR'];
  if (envDir != null && envDir.isNotEmpty) {
    candidates.add('$envDir/bin/git');
  }
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  candidates.add('$exeDir/dugite/bin/git');
  candidates.add('$exeDir/lib/dugite/bin/git');
  return _firstExisting(candidates);
}

String? _findOnPath(String name) {
  final sep = Platform.isWindows ? ';' : ':';
  for (final dir in _expandedPath().split(sep)) {
    if (dir.isEmpty) continue;
    if (Platform.isWindows) {
      // PATHEXT-style probe — a bare `pql` on PATH is really pql.exe.
      for (final ext in const ['.exe', '.bat', '.cmd', '.com', '']) {
        final f = File('$dir\\$name$ext');
        if (f.existsSync()) return f.path;
      }
    } else {
      final f = File('$dir/$name');
      if (f.existsSync()) return f.path;
    }
  }
  return null;
}

String? _firstExisting(List<String> candidates) {
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// The full tool search PATH — the login-shell PATH (probed once at startup)
/// unioned with the well-known user/local bin dirs, shared with every other
/// spawn site via [shell_env] (T-439). In an isolate that never primed the
/// probe it degrades to the process PATH + the well-known dirs (T-347).
String _expandedPath() => resolvedToolPath();
