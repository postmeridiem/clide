/// Directory listing with ignore-file filtering.
///
/// A thin wrapper over `Directory.list()` that applies an [IgnoreSet]
/// to each candidate entry. Used by the `files.ls` IPC handler and
/// by the file-tree UI for non-watched one-shot reads.
library;

import 'dart:io';

import 'ignore.dart';

class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isSymlink,
    this.sizeBytes,
    this.modifiedMs,
  });

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
Future<List<FileEntry>> listDir({
  required Directory root,
  required String dir,
  required IgnoreSet ignore,
}) async {
  final resolved = dir.isEmpty ? root : Directory('${root.absolute.path}${Platform.pathSeparator}${dir.replaceAll('/', Platform.pathSeparator)}');
  if (!await resolved.exists()) return const [];

  final entries = <FileEntry>[];
  await for (final e in resolved.list(followLinks: false)) {
    final name = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.where((s) => s.isNotEmpty).last : '';
    final rel = dir.isEmpty ? name : '$dir/$name';
    final stat = await e.stat();
    final isDir = stat.type == FileSystemEntityType.directory;
    if (ignore.isIgnored(rel, isDirectory: isDir)) continue;
    entries.add(FileEntry(
      name: name,
      path: rel,
      isDirectory: isDir,
      isSymlink: stat.type == FileSystemEntityType.link,
      sizeBytes: isDir ? null : stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    ));
  }

  entries.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return entries;
}
