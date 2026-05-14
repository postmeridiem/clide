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

/// Serializable result of tool resolution (crosses isolate boundary).
class ResolvedPaths {
  const ResolvedPaths({
    this.git,
    this.pql,
    this.tmux,
    this.shell,
    this.gitEnv,
  });

  final String? git;
  final String? pql;
  final String? tmux;
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
  String get tmux;
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
  String get tmux => _paths.tmux ?? 'tmux';
  @override
  String get shell => _paths.shell ?? '/bin/bash';
  @override
  Map<String, String>? get gitEnv => _paths.gitEnv;
  @override
  bool get resolved => true;
  @override
  bool get allOk => missing.isEmpty;
  @override
  List<String> get missing => [
        if (_paths.git == null) 'git',
        if (_paths.pql == null) 'pql',
        if (_paths.tmux == null) 'tmux',
      ];
}

/// Top-level function for compute/isolate use. Takes a single String
/// argument (the workspace root) and returns a plain-data result.
ResolvedPaths resolveToolchainPaths(String workspaceRoot) {
  final dugite = '$workspaceRoot/native/dugite/bin';

  String? git;
  Map<String, String>? gitEnv;
  final dugiteGit = _firstExisting(['$dugite/git']);
  if (dugiteGit != null) {
    git = dugiteGit;
    final dugiteRoot = File(dugiteGit).parent.parent.path;
    gitEnv = {
      'GIT_EXEC_PATH': '$dugiteRoot/libexec/git-core',
      'GIT_TEMPLATE_DIR': '$dugiteRoot/share/git-core/templates',
    };
  } else {
    git = _findOnPath('git');
  }

  return ResolvedPaths(
    git: git,
    pql: _findOnPath('pql'),
    tmux: _findOnPath('tmux'),
    shell: _findOnPath(Platform.environment['SHELL']?.split('/').last ?? 'bash'),
    gitEnv: gitEnv,
  );
}

String? _findOnPath(String name) {
  for (final dir in _expandedPath().split(':')) {
    if (dir.isEmpty) continue;
    final f = File('$dir/$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

String? _firstExisting(List<String> candidates) {
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// Build expanded PATH inline — must be self-contained for isolate use.
String _expandedPath() {
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
