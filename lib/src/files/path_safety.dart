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

/// Resolve [relative] for a **write** under [root].
///
/// Split from [resolveUnderRootFollowingSymlinks] because the read
/// resolver's "target doesn't exist → return the path-layer result"
/// shortcut is safe for reads and a hole for writes. A read of a missing
/// file just fails; a *write* to a missing file under a symlinked parent
/// (`<root>/link -> /etc`, target `link/passwd`) would create a file
/// outside the workspace, since nothing ever resolves the parent.
///
/// So: when the target exists, confine the resolved real path as usual.
/// When it doesn't, confine its **parent** — which must already exist.
/// Directories are not created implicitly; writing into a missing
/// directory is a [PathOutsideRoot]-free [FileSystemException] the caller
/// surfaces normally.
String resolveForWriteUnderRoot(Directory root, String relative) {
  final sep = Platform.pathSeparator;
  final pathResolved = resolveUnderRoot(root, relative);
  final realRoot = Directory(root.absolute.path).resolveSymbolicLinksSync();
  bool contained(String p) => p == realRoot || p.startsWith('$realRoot$sep');

  if (FileSystemEntity.typeSync(pathResolved, followLinks: false) != FileSystemEntityType.notFound) {
    final realPath = File(pathResolved).resolveSymbolicLinksSync();
    if (!contained(realPath)) throw PathOutsideRoot(relative, realPath, realRoot);
    return realPath;
  }

  final parent = File(pathResolved).parent;
  if (!parent.existsSync()) return pathResolved; // let the write report the missing dir
  final realParent = parent.resolveSymbolicLinksSync();
  if (!contained(realParent)) throw PathOutsideRoot(relative, realParent, realRoot);
  return '$realParent$sep${pathResolved.substring(pathResolved.lastIndexOf(sep) + 1)}';
}

/// Like [resolveUnderRoot], but an **absolute** [path] is also accepted
/// when it falls under any of [extraReadRoots] — trusted read-only roots
/// such as the Claude config dirs (`~/.claude`, `<repo>/.claude`) that
/// clide surfaces but which may live outside the workspace (D-80).
/// Relative paths always resolve under the primary [root]. Throws
/// [PathOutsideRoot] when the path is contained by none of the roots.
///
/// This widens *reads* only; writes stay confined to the workspace via
/// the single-root variant.
String resolveUnderRoots(Directory root, List<Directory> extraReadRoots, String path) {
  if (!path.startsWith(Platform.pathSeparator)) {
    return resolveUnderRoot(root, path); // relative → workspace-relative
  }
  final norm = _normalize(path);
  for (final r in [root, ...extraReadRoots]) {
    final rp = _normalize(r.absolute.path);
    if (norm == rp || norm.startsWith('$rp${Platform.pathSeparator}')) return norm;
  }
  throw PathOutsideRoot(path, norm, _normalize(root.absolute.path));
}

/// Symlink-following multi-root resolver — the [resolveUnderRoots]
/// analogue of [resolveUnderRootFollowingSymlinks]. Re-verifies the real
/// (symlink-resolved) path is contained by one of the allowed roots.
String resolveUnderRootsFollowingSymlinks(Directory root, List<Directory> extraReadRoots, String path) {
  final pathResolved = resolveUnderRoots(root, extraReadRoots, path);
  if (FileSystemEntity.typeSync(pathResolved, followLinks: false) == FileSystemEntityType.notFound) {
    return pathResolved;
  }
  final realPath = File(pathResolved).resolveSymbolicLinksSync();
  for (final r in [root, ...extraReadRoots]) {
    final String realRoot;
    try {
      realRoot = Directory(r.absolute.path).resolveSymbolicLinksSync();
    } catch (_) {
      continue; // a non-existent allowed root can't contain anything
    }
    if (realPath == realRoot || realPath.startsWith('$realRoot${Platform.pathSeparator}')) {
      return realPath;
    }
  }
  throw PathOutsideRoot(path, realPath, _normalize(root.absolute.path));
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
