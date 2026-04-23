import 'dart:io';

import 'package:flutter/foundation.dart';

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

  Future<void> check() async {
    final cwd = Directory.current.path;
    ptycOk = File('$cwd/native/linux-x64/ptyc').existsSync() ||
        File('$cwd/ptyc/bin/ptyc').existsSync() ||
        await _which('ptyc');
    pqlOk = await _which('pql');
    tmuxOk = await _which('tmux');
    gitOk = await _which('git');
    checked = true;
    notifyListeners();
  }

  static Future<bool> _which(String name) async {
    try {
      final r = await Process.run('which', [name]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
