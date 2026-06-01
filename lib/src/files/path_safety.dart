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
///
/// Path-layer check only — does NOT follow symlinks. Callers that
/// read or list the filesystem should use [resolveUnderRootFollowingSymlinks]
/// instead, which adds a second containment check against the real
/// path. The two-step split exists so pure path math can be tested
/// without touching disk (T-102).
String resolveUnderRoot(Directory root, String relative) {
  final rootPath = _normalize(root.absolute.path);
  // An absolute input is normalized as-is rather than joined onto the
  // root — otherwise a path already under the root gets doubled
  // (`/repo` + `/repo/x` → `/repo/repo/x`) and resolves to nothing.
  // Containment is still enforced below, so an absolute path *outside*
  // the root is rejected exactly as a `..` traversal is.
  final joined = relative.startsWith(Platform.pathSeparator) ? _normalize(relative) : _normalize('$rootPath${Platform.pathSeparator}$relative');

  // Containment check: joined must equal rootPath, or start with
  // rootPath + separator. Equality covers `relative == ''` (the
  // root itself); the separator check prevents `/repo` matching
  // `/repository`.
  if (joined != rootPath && !joined.startsWith('$rootPath${Platform.pathSeparator}')) {
    throw PathOutsideRoot(relative, joined, rootPath);
  }
  return joined;
}

/// Like [resolveUnderRoot] but also resolves any symlinks at the
/// target and re-verifies containment against the real path. Use this
/// for any operation that will read/list/write the filesystem — the
/// path-layer check alone does not defend against a symlink under the
/// workspace whose target lives outside (T-102, e.g. `config ->
/// /etc/shadow`).
///
/// Returns the **resolved real path** (with symlinks followed) when
/// the target exists. When the target does not exist, returns the
/// path-layer result so callers surface a clean "not found" error from
/// their filesystem op (rather than this layer throwing first).
///
/// Symlinks in the workspace root path itself are tolerated: both
/// sides of the containment check are resolved.
String resolveUnderRootFollowingSymlinks(Directory root, String relative) {
  final pathResolved = resolveUnderRoot(root, relative);
  if (FileSystemEntity.typeSync(pathResolved, followLinks: false) == FileSystemEntityType.notFound) {
    return pathResolved;
  }
  final realRoot = Directory(root.absolute.path).resolveSymbolicLinksSync();
  final realPath = File(pathResolved).resolveSymbolicLinksSync();
  if (realPath != realRoot && !realPath.startsWith('$realRoot${Platform.pathSeparator}')) {
    throw PathOutsideRoot(relative, realPath, realRoot);
  }
  return realPath;
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
