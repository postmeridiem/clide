/// Directory listing with ignore-file filtering.
///
/// A thin wrapper over `Directory.list()` that applies an [IgnoreSet]
/// to each candidate entry. Used by the `files.ls` IPC handler and
/// by the file-tree UI for non-watched one-shot reads.
library;

import 'dart:io';

import 'ignore.dart';

class FileEntry {
  const FileEntry({required this.name, required this.path, required this.isDirectory, required this.isSymlink, this.sizeBytes, this.modifiedMs});

  /// Display name (basename).
  final String name;

  /// Repo-relative path, forward-slashed.
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int? sizeBytes;
  final int? modifiedMs;

  Map<String, Object?> toJson() => {
    'name': name,
    'path': path,
    'isDirectory': isDirectory,
    'isSymlink': isSymlink,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (modifiedMs != null) 'modifiedMs': modifiedMs,
  };
}

/// List the immediate children of [dir] (repo-relative path) under
/// [root]. Filters against [ignore]. Returns entries sorted
/// directory-first, then by name.
Future<List<FileEntry>> listDir({required Directory root, required String dir, required IgnoreSet ignore}) async {
  final resolved = dir.isEmpty ? root : Directory('${root.absolute.path}${Platform.pathSeparator}${dir.replaceAll('/', Platform.pathSeparator)}');
  if (!await resolved.exists()) return const [];

  final entries = <FileEntry>[];
  await for (final e in resolved.list(followLinks: false)) {
    final name = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.where((s) => s.isNotEmpty).last : '';
    final rel = dir.isEmpty ? name : '$dir/$name';
    // With followLinks: false the lister yields Link entities for symlinks —
    // that's the symlink signal. stat() follows the link (target type/size,
    // notFound for broken links), so its type can never be `link` and must
    // not be used for detection (T-365).
    final isLink = e is Link;
    final stat = await e.stat();
    final isDir = stat.type == FileSystemEntityType.directory;
    if (ignore.isIgnored(rel, isDirectory: isDir)) continue;
    entries.add(
      FileEntry(
        name: name,
        path: rel,
        isDirectory: isDir,
        isSymlink: isLink,
        sizeBytes: isDir ? null : stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
      ),
    );
  }

  entries.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return entries;
}

/// Result of [walkFiles]: the flat file list plus whether the walk
/// stopped early at [WalkResult.cap].
class WalkResult {
  const WalkResult({required this.files, required this.truncated});

  /// Every non-ignored file under the root, repo-relative, sorted by path.
  final List<FileEntry> files;

  /// True when the [maxFiles] cap was reached and the walk stopped early.
  final bool truncated;
}

/// Recursively walk [root], returning every non-ignored *file*
/// (directories are descended into but not emitted), pruned by
/// [ignore]. Reuses [listDir] per directory, so ignore filtering and
/// per-directory sorting are inherited. Symlinks are never descended —
/// a symlinked directory would be an escape hatch out of the workspace
/// and a cycle risk (T-365); symlinks to files are emitted as entries.
///
/// Capped at [maxFiles] to bound work on pathological trees; when the
/// cap is hit the walk stops early and [WalkResult.truncated] is set so
/// callers can surface "results truncated". The returned list is sorted
/// by repo-relative path for a deterministic contract.
Future<WalkResult> walkFiles({required Directory root, required IgnoreSet ignore, int maxFiles = 50000}) async {
  final out = <FileEntry>[];
  // DFS over repo-relative directory paths; '' is the root itself.
  final stack = <String>[''];
  var truncated = false;
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    final entries = await listDir(root: root, dir: dir, ignore: ignore);
    for (final e in entries) {
      if (e.isDirectory) {
        if (!e.isSymlink) stack.add(e.path);
      } else {
        out.add(e);
        if (out.length >= maxFiles) {
          truncated = true;
          break;
        }
      }
    }
    if (truncated) break;
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return WalkResult(files: out, truncated: truncated);
}
