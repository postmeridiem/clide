import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../src/pty/env.dart';

class ToolCheck extends ChangeNotifier {
  bool ptycOk = false;
  bool pqlOk = false;
  bool tmuxOk = false;
  bool gitOk = false;
  bool checked = false;

  bool get allOk => ptycOk && pqlOk && tmuxOk && gitOk;

  List<String> get errors => [
        if (!ptycOk) 'ptyc not found',
        if (!pqlOk) 'pql not found',
        if (!tmuxOk) 'tmux not found',
        if (!gitOk) 'git not found',
      ];

  /// Workspace root, set by the app at boot. Falls back to cwd.
  static String? workspaceRoot;

  Future<void> check() async {
    final root = workspaceRoot ?? Directory.current.path;
    ptycOk = File('$root/native/linux-x64/ptyc').existsSync() ||
        File('$root/native/macos-arm64/ptyc').existsSync() ||
        File('$root/native/macos-x64/ptyc').existsSync() ||
        File('$root/ptyc/bin/ptyc').existsSync() ||
        _existsOnPath('ptyc');
    pqlOk = _existsOnPath('pql');
    tmuxOk = _existsOnPath('tmux');
    gitOk = _existsOnPath('git');
    checked = true;
    notifyListeners();
  }

  /// Check if [name] exists as an executable in any PATH directory.
  /// Uses direct file-existence checks — works inside a macOS sandbox
  /// without needing to exec `which`.
  static bool _existsOnPath(String name) {
    for (final dir in expandedPath.split(':')) {
      if (dir.isEmpty) continue;
      if (File('$dir/$name').existsSync()) return true;
    }
    return false;
  }
}
