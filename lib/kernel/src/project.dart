import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:flutter/foundation.dart';

class RecentProject {
  const RecentProject({required this.path, required this.name, this.branch, required this.lastOpened});

  final String path;
  final String name;
  final String? branch;
  final DateTime lastOpened;

  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'branch': branch, 'lastOpened': lastOpened.toIso8601String()};

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        branch: json['branch'] as String?,
        lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ?? DateTime.now(),
      );

  String get relativePath {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && path.startsWith(home)) return '~${path.substring(home.length)}';
    return path;
  }

  String get timeAgo {
    final diff = DateTime.now().difference(lastOpened);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }
}

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

  List<RecentProject> _recents = [];
  List<RecentProject> get recents => List.unmodifiable(_recents);

  Future<void> loadRecents() async {
    final raw = _settings.get<String>('app.recentProjects');
    if (raw == null || raw.isEmpty) {
      _recents = [];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _recents = list.map(RecentProject.fromJson).toList();
    } catch (_) {
      _recents = [];
    }
  }

  Future<bool> open(String path) async {
    final root = await resolveWorkspace(path);
    if (root == null) {
      _log.warn('project', 'not a git repo: $path');
      return false;
    }
    _current = Directory(root);
    await _settings.setProjectDir(_current);
    await _settings.set<String>('app.lastProject', root);

    final branch = await _currentBranch(root);
    final name = root.split('/').last;
    _recents.removeWhere((r) => r.path == root);
    _recents.insert(0, RecentProject(path: root, name: name, branch: branch, lastOpened: DateTime.now()));
    if (_recents.length > 10) _recents = _recents.sublist(0, 10);
    await _settings.set<String>('app.recentProjects', jsonEncode(_recents.map((r) => r.toJson()).toList()));

    _events.emit(ProjectOpened(path: root));
    notifyListeners();
    return true;
  }

  Future<bool> openLast() async {
    final last = _settings.get<String>('app.lastProject');
    if (last == null || last.isEmpty) return false;
    final dir = Directory(last);
    if (!await dir.exists()) return false;
    return open(last);
  }

  Future<void> close() async {
    if (_current == null) return;
    _current = null;
    await _settings.setProjectDir(null);
    _events.emit(const ProjectClosed());
    notifyListeners();
  }

  Future<String?> resolveWorkspace(String path) async {
    try {
      final r = await Process.run('git', ['rev-parse', '--show-toplevel'], workingDirectory: path, runInShell: false);
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (e) {
      _log.debug('project', 'git rev-parse failed: $e');
      return null;
    }
  }

  Future<String?> _currentBranch(String root) async {
    try {
      final r = await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: root, runInShell: false);
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}
