/// Recursive file watcher with ignore-file filtering.
///
/// Wraps `Directory.watch(recursive: true)` on Linux (inotify) and
/// macOS (FSEvents). Events emit with [IgnoreSet] filtering applied so
/// the tree view doesn't flicker on changes inside `.dart_tool/` /
/// `node_modules/` / etc.
library;

import 'dart:async';
import 'dart:io';

import 'ignore.dart';

/// Kind of filesystem change. Mirrors Dart's `FileSystemEvent` but in
/// a form that survives serialisation over IPC.
enum FileChangeKind {
  created,
  deleted,
  modified,
  renamed;

  String get wire => name;

  static FileChangeKind fromEvent(FileSystemEvent e) {
    switch (e.type) {
      case FileSystemEvent.create:
        return FileChangeKind.created;
      case FileSystemEvent.delete:
        return FileChangeKind.deleted;
      case FileSystemEvent.modify:
        return FileChangeKind.modified;
      case FileSystemEvent.move:
        return FileChangeKind.renamed;
      default:
        return FileChangeKind.modified;
    }
  }
}

class FileChange {
  const FileChange({
    required this.kind,
    required this.path,
    required this.isDirectory,
  });

  final FileChangeKind kind;

  /// Repo-relative path, forward-slashed.
  final String path;
  final bool isDirectory;

  Map<String, Object?> toJson() => {
        'kind': kind.wire,
        'path': path,
        'isDirectory': isDirectory,
      };
}

class FileWatcher {
  FileWatcher({required this.root, required this.ignore});

  final Directory root;
  final IgnoreSet ignore;

  StreamSubscription<FileSystemEvent>? _sub;
  final _controller = StreamController<FileChange>.broadcast();

  Stream<FileChange> get stream => _controller.stream;

  Future<void> start() async {
    if (_sub != null) return;
    _sub = root.watch(recursive: true).listen(
      _onEvent,
      onError: (Object e, StackTrace _) => _controller.addError(e),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }

  void _onEvent(FileSystemEvent e) {
    final rel = _toRelative(e.path);
    if (rel == null) return;
    final isDir = e.isDirectory;
    if (ignore.isIgnored(rel, isDirectory: isDir)) return;
    _controller.add(FileChange(
      kind: FileChangeKind.fromEvent(e),
      path: rel,
      isDirectory: isDir,
    ));
  }

  String? _toRelative(String abs) {
    final rootPath = root.absolute.path;
    if (!abs.startsWith(rootPath)) return null;
    var rel = abs.substring(rootPath.length);
    if (rel.startsWith(Platform.pathSeparator)) {
      rel = rel.substring(1);
    }
    return rel.replaceAll(Platform.pathSeparator, '/');
  }
}
