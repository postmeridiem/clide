/// Centralized binary resolution for external tools.
///
/// Resolution runs in a background isolate via [resolvePaths] to avoid
/// blocking the merged UI/platform thread on macOS. The result is
/// applied on the main thread via [applyResolved].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Serializable result of tool resolution (crosses isolate boundary).
class ResolvedPaths {
  const ResolvedPaths({
    this.git,
    this.pql,
    this.tmux,
    this.ptyc,
    this.shell,
    this.gitEnv,
  });

  final String? git;
  final String? pql;
  final String? tmux;
  final String? ptyc;
  final String? shell;
  final Map<String, String>? gitEnv;
}

class Toolchain extends ChangeNotifier {
  String? _git;
  String? _pql;
  String? _tmux;
  String? _ptyc;
  String? _shell;
  Map<String, String>? _gitEnv;
  bool _resolved = false;

  String get git => _git ?? 'git';
  String get pql => _pql ?? 'pql';
  String get tmux => _tmux ?? 'tmux';
  String get ptyc => _ptyc ?? 'ptyc';
  String get shell => _shell ?? '/bin/bash';

  /// Extra environment variables for git (e.g. GIT_EXEC_PATH for dugite).
  Map<String, String>? get gitEnv => _gitEnv;

  bool get resolved => _resolved;
  bool get allOk => _resolved && missing.isEmpty;

  List<String> get missing => [
        if (_git == null) 'git',
        if (_pql == null) 'pql',
        if (_tmux == null) 'tmux',
      ];

  /// Returns a Future that completes when resolution finishes.
  Future<void> waitForResolution() {
    if (_resolved) return Future.value();
    final c = Completer<void>();
    void listener() {
      if (_resolved) {
        removeListener(listener);
        if (!c.isCompleted) c.complete();
      }
    }

    addListener(listener);
    return c.future;
  }

  /// Apply paths resolved in a background isolate.
  void applyResolved(ResolvedPaths p) {
    _git = p.git;
    _pql = p.pql;
    _tmux = p.tmux;
    _ptyc = p.ptyc;
    _shell = p.shell;
    _gitEnv = p.gitEnv;
    _resolved = true;
    notifyListeners();
  }

  /// Pure function — runs in a background isolate. All file I/O happens
  /// here, off the main thread.
  static ResolvedPaths resolvePaths({required String workspaceRoot}) {
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

    final pql = _findOnPath('pql');
    final tmux = _findOnPath('tmux');
    final shell = _findOnPath(Platform.environment['SHELL']?.split('/').last ?? 'bash');

    final ptyc = _firstExisting([
          '$workspaceRoot/ptyc/bin/ptyc',
          '$workspaceRoot/native/linux-x64/ptyc',
          '$workspaceRoot/native/macos-arm64/ptyc',
          '$workspaceRoot/native/macos-x64/ptyc',
          if (Platform.environment['HOME'] case final home?) '$home/.local/bin/ptyc',
        ]) ??
        _findOnPath('ptyc');

    return ResolvedPaths(
      git: git,
      pql: pql,
      tmux: tmux,
      ptyc: ptyc,
      shell: shell,
      gitEnv: gitEnv,
    );
  }

  static String? _findOnPath(String name) {
    for (final dir in _expandedPath().split(':')) {
      if (dir.isEmpty) continue;
      final f = File('$dir/$name');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// Build expanded PATH inline — must be self-contained for isolate use.
  static String _expandedPath() {
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

  static String? _firstExisting(List<String> candidates) {
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }
}

/// Top-level function for compute/isolate use. Takes a single String
/// argument (the workspace root) and returns a plain-data result.
ResolvedPaths resolveToolchainPaths(String workspaceRoot) {
  final dugite = '$workspaceRoot/native/dugite/bin';

  String? git;
  Map<String, String>? gitEnv;
  final dugiteGit = _firstExistingStandalone(['$dugite/git']);
  if (dugiteGit != null) {
    git = dugiteGit;
    final dugiteRoot = File(dugiteGit).parent.parent.path;
    gitEnv = {
      'GIT_EXEC_PATH': '$dugiteRoot/libexec/git-core',
      'GIT_TEMPLATE_DIR': '$dugiteRoot/share/git-core/templates',
    };
  } else {
    git = _findOnPathStandalone('git');
  }

  return ResolvedPaths(
    git: git,
    pql: _findOnPathStandalone('pql'),
    tmux: _findOnPathStandalone('tmux'),
    ptyc: _firstExistingStandalone([
          '$workspaceRoot/ptyc/bin/ptyc',
          '$workspaceRoot/native/linux-x64/ptyc',
          '$workspaceRoot/native/macos-arm64/ptyc',
          '$workspaceRoot/native/macos-x64/ptyc',
          if (Platform.environment['HOME'] case final home?) '$home/.local/bin/ptyc',
        ]) ??
        _findOnPathStandalone('ptyc'),
    shell: _findOnPathStandalone(Platform.environment['SHELL']?.split('/').last ?? 'bash'),
    gitEnv: gitEnv,
  );
}

String? _findOnPathStandalone(String name) {
  for (final dir in _expandedPathStandalone().split(':')) {
    if (dir.isEmpty) continue;
    final f = File('$dir/$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

String? _firstExistingStandalone(List<String> candidates) {
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

String _expandedPathStandalone() {
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
