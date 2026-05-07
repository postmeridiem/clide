import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../src/pty/env.dart';

class ToolCheck extends ChangeNotifier {
  bool pqlOk = false;
  bool tmuxOk = false;
  bool gitOk = false;
  bool checked = false;

  bool get allOk => pqlOk && tmuxOk && gitOk;

  List<String> get errors => [
        if (!pqlOk) 'pql not found',
        if (!tmuxOk) 'tmux not found',
        if (!gitOk) 'git not found',
      ];

  /// Workspace root, set by the app at boot. Falls back to cwd.
  static String? workspaceRoot;

  Future<void> check() async {
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
