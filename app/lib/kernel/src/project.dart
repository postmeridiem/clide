import 'dart:io';

import 'package:clide_app/kernel/src/events/bus.dart';
import 'package:clide_app/kernel/src/events/types.dart';
import 'package:clide_app/kernel/src/log.dart';
import 'package:clide_app/kernel/src/settings.dart';
import 'package:flutter/foundation.dart';

class ProjectManager extends ChangeNotifier {
  ProjectManager({
    required Logger log,
    required EventBus events,
    required SettingsStore settings,
  })  : _log = log,
        _events = events,
        _settings = settings;

  final Logger _log;
  final EventBus _events;
  final SettingsStore _settings;

  Directory? _current;
  Directory? get current => _current;
  bool get isOpen => _current != null;

  /// Open a project by path. Runs `git rev-parse --show-toplevel` to
  /// find the workspace root. Returns true on success.
  Future<bool> open(String path) async {
    final root = await resolveWorkspace(path);
    if (root == null) {
      _log.warn('project', 'not a git repo: $path');
      return false;
    }
    _current = Directory(root);
    await _settings.setProjectDir(_current);
    _events.emit(ProjectOpened(path: root));
    notifyListeners();
    return true;
  }

  Future<void> close() async {
    if (_current == null) return;
    _current = null;
    await _settings.setProjectDir(null);
    _events.emit(const ProjectClosed());
    notifyListeners();
  }

  /// Walks up from [path] via `git rev-parse --show-toplevel`. Returns
  /// null if the path is outside a git repo or git isn't available.
  Future<String?> resolveWorkspace(String path) async {
    try {
      final r = await Process.run(
        'git',
        ['rev-parse', '--show-toplevel'],
        workingDirectory: path,
        runInShell: false,
      );
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (e) {
      _log.debug('project', 'git rev-parse failed: $e');
      return null;
    }
  }
}
