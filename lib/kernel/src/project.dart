import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/settings.dart';
import 'package:clide/kernel/src/toolchain.dart';
import 'package:flutter/foundation.dart';

class RecentProject {
  const RecentProject({
    required this.path,
    required this.name,
    this.branch,
    required this.lastOpened,
    this.startupSticky = false,
  });

  final String path;
  final String name;
  final String? branch;
  final DateTime lastOpened;

  /// When set, this project is preferred on startup over the picker.
  /// If exactly one recent has this flag, [ProjectManager.openStickyOrNothing]
  /// opens it directly; otherwise the welcome screen takes over (T-115).
  final bool startupSticky;

  RecentProject copyWith({bool? startupSticky, DateTime? lastOpened, String? branch}) => RecentProject(
        path: path,
        name: name,
        branch: branch ?? this.branch,
        lastOpened: lastOpened ?? this.lastOpened,
        startupSticky: startupSticky ?? this.startupSticky,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'branch': branch,
        'lastOpened': lastOpened.toIso8601String(),
        if (startupSticky) 'startupSticky': true,
      };

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        branch: json['branch'] as String?,
        lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ?? DateTime.now(),
        startupSticky: json['startupSticky'] as bool? ?? false,
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
    required DaemonBus events,
    required SettingsStore settings,
    required Toolchain toolchain,
    Future<void> Function(String path)? onProjectOpen,
    Future<String?> Function(String path)? onValidateProject,
  })  : _log = log,
        _events = events,
        _settings = settings,
        _toolchain = toolchain,
        _onProjectOpen = onProjectOpen,
        _onValidateProject = onValidateProject;

  final Logger _log;
  final DaemonBus _events;
  final SettingsStore _settings;
  final Toolchain _toolchain;
  final Future<void> Function(String path)? _onProjectOpen;
  final Future<String?> Function(String path)? _onValidateProject;

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
    final root = await resolveProject(path);
    if (root == null) {
      _log.warn('project', 'not a git repo: $path');
      return false;
    }
    _current = Directory(root);

    // Tell the backend isolate to (re)initialize services for this workspace.
    if (_onProjectOpen != null) {
      await _onProjectOpen(root);
    }

    await _settings.setProjectDir(_current);
    await _settings.set<String>('app.lastProject', root);

    final branch = await _currentBranch(root);
    final name = root.split('/').last;
    // Preserve the sticky-startup flag across reopens — otherwise the
    // user would have to re-toggle it every time they touched the
    // project (T-115).
    final wasSticky = isStickyStartup(root);
    _recents.removeWhere((r) => r.path == root);
    _recents.insert(
      0,
      RecentProject(path: root, name: name, branch: branch, lastOpened: DateTime.now(), startupSticky: wasSticky),
    );
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

  /// Path of the lone sticky-startup project, or null if zero or
  /// multiple recents have the flag. Zero ⇒ show the picker; multiple
  /// ⇒ ambiguous, also show the picker (T-115).
  String? get stickyProjectPath {
    final sticky = _recents.where((r) => r.startupSticky).toList();
    return sticky.length == 1 ? sticky.first.path : null;
  }

  /// Open the single sticky-startup project, if any. Returns false on
  /// "no unambiguous sticky" so the caller (main.dart) can fall through
  /// to the welcome screen.
  Future<bool> openStickyOrNothing() async {
    final path = stickyProjectPath;
    if (path == null) return false;
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    return open(path);
  }

  /// Toggle the per-project sticky-startup flag and persist. No-op if
  /// the path isn't in recents (open the project first to land it
  /// there).
  Future<void> setStickyStartup(String path, bool value) async {
    final idx = _recents.indexWhere((r) => r.path == path);
    if (idx < 0) return;
    if (_recents[idx].startupSticky == value) return;
    _recents[idx] = _recents[idx].copyWith(startupSticky: value);
    await _settings.set<String>('app.recentProjects', jsonEncode(_recents.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  bool isStickyStartup(String path) {
    final idx = _recents.indexWhere((r) => r.path == path);
    return idx >= 0 && _recents[idx].startupSticky;
  }

  Future<void> close() async {
    if (_current == null) return;
    _current = null;
    await _settings.setProjectDir(null);
    _events.emit(const ProjectClosed());
    notifyListeners();
  }

  Future<String?> resolveProject(String path) async {
    // Prefer backend validation (runs in the backend isolate, safe from
    // the merged UI thread). Falls back to direct Process.run for tests
    // and the CLI binary.
    if (_onValidateProject != null) {
      return _onValidateProject(path);
    }
    try {
      final r = await Process.run(_toolchain.git, ['rev-parse', '--show-toplevel'], workingDirectory: path, environment: _toolchain.gitEnv);
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
      final r = await Process.run(_toolchain.git, ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: root, environment: _toolchain.gitEnv);
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}
