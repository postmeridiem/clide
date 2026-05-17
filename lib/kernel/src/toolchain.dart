/// Centralized binary resolution for external tools.
///
/// Resolution runs in a background isolate via [Toolchain.resolvePaths]
/// to avoid blocking the merged UI/platform thread on macOS. The result
/// is applied on the main thread via [Toolchain.applyResolved].
///
/// The Flutter-free data types ([ResolvedPaths], [ToolchainView]) and
/// the isolate-side resolver ([resolveToolchainPaths]) live in
/// `toolchain_paths.dart` and are re-exported here for convenience.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'toolchain_paths.dart';

export 'toolchain_paths.dart';

class Toolchain extends ChangeNotifier implements ToolchainView {
  String? _git;
  String? _pql;
  String? _tmux;
  String? _shell;
  Map<String, String>? _gitEnv;
  bool _resolved = false;

  @override
  String get git => _git ?? 'git';
  @override
  String get pql => _pql ?? 'pql';
  @override
  String get tmux => _tmux ?? 'tmux';
  @override
  String get shell => _shell ?? '/bin/bash';

  /// Extra environment variables for git (e.g. GIT_EXEC_PATH for dugite).
  @override
  Map<String, String>? get gitEnv => _gitEnv;

  @override
  bool get resolved => _resolved;
  @override
  bool get allOk => _resolved && missing.isEmpty;

  @override
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
    _shell = p.shell;
    _gitEnv = p.gitEnv;
    _resolved = true;
    notifyListeners();
  }

  /// Pure function — runs in a background isolate. All file I/O happens
  /// here, off the main thread. Delegates to the Flutter-free
  /// [resolveToolchainPaths]. Takes no workspace argument: see T-98.
  static ResolvedPaths resolvePaths() => resolveToolchainPaths();
}
