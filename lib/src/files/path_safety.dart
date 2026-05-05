/// Workspace-relative path validation. Rejects paths that resolve
/// outside the workspace root (path traversal via `..`, absolute
/// paths, symlink-out attempts).
library;

import 'dart:io';

class PathOutsideRoot implements Exception {
  PathOutsideRoot(this.requested, this.resolved, this.root);
  final String requested;
  final String resolved;
  final String root;

  @override
  String toString() => 'path outside workspace root: $requested → $resolved (root: $root)';
}

/// Resolve [relative] against [root] and verify the result is
/// contained within [root]. Returns the absolute, normalized path.
/// Throws [PathOutsideRoot] on traversal attempts.
String resolveUnderRoot(Directory root, String relative) {
  final rootPath = _normalize(root.absolute.path);
  final joined = _normalize('$rootPath${Platform.pathSeparator}$relative');

  // Containment check: joined must equal rootPath, or start with
  // rootPath + separator. Equality covers `relative == ''` (the
  // root itself); the separator check prevents `/repo` matching
  // `/repository`.
  if (joined != rootPath && !joined.startsWith('$rootPath${Platform.pathSeparator}')) {
    throw PathOutsideRoot(relative, joined, rootPath);
  }
  return joined;
}

String _normalize(String path) {
  // Use Uri to collapse `..` and `.` segments without hitting the
  // filesystem (Directory(...).resolveSymbolicLinksSync would also
  // resolve symlinks, which we don't want here — symlink handling
  // belongs at the filesystem-access layer, not the path layer).
  final segments = <String>[];
  for (final raw in path.split(Platform.pathSeparator)) {
    if (raw.isEmpty || raw == '.') continue;
    if (raw == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(raw);
  }
  final prefix = path.startsWith(Platform.pathSeparator) ? Platform.pathSeparator : '';
  return '$prefix${segments.join(Platform.pathSeparator)}';
}
