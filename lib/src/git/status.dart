/// Git status data model and parser.
///
/// Shells out to `git status --porcelain=v1 -z` and parses the
/// NUL-delimited output into typed [GitFileStatus] entries grouped
/// by state (staged, unstaged, untracked, conflicted).
library;

import 'dart:io';

import 'operations.dart' show gitBin;

enum GitFileState {
  added,
  modified,
  deleted,
  renamed,
  copied,
  untracked,
  ignored,
}

enum GitConflictType {
  bothModified,
  bothAdded,
  addedByUs,
  addedByThem,
  deletedByUs,
  deletedByThem,
  bothDeleted,
}

class GitFileStatus {
  const GitFileStatus({
    required this.path,
    required this.indexState,
    required this.workTreeState,
    this.origPath,
    this.conflictType,
  });

  final String path;
  final GitFileState? indexState;
  final GitFileState? workTreeState;
  final String? origPath;
  final GitConflictType? conflictType;

  bool get isStaged =>
      indexState != null &&
      indexState != GitFileState.untracked &&
      indexState != GitFileState.ignored &&
      !isConflicted;
  bool get isUnstaged =>
      workTreeState != null &&
      workTreeState != GitFileState.untracked &&
      !isConflicted;
  bool get isUntracked => workTreeState == GitFileState.untracked;
  bool get isConflicted => conflictType != null;

  Map<String, Object?> toJson() => {
        'path': path,
        if (indexState != null) 'indexState': indexState!.name,
        if (workTreeState != null) 'workTreeState': workTreeState!.name,
        if (origPath != null) 'origPath': origPath,
        if (conflictType != null) 'conflictType': conflictType!.name,
        'staged': isStaged,
        'unstaged': isUnstaged,
        'untracked': isUntracked,
        'conflicted': isConflicted,
      };
}

class GitStatus {
  const GitStatus({
    required this.branch,
    required this.entries,
    this.upstream,
    this.ahead = 0,
    this.behind = 0,
  });

  final String? branch;
  final String? upstream;
  final int ahead;
  final int behind;
  final List<GitFileStatus> entries;

  List<GitFileStatus> get staged =>
      entries.where((e) => e.isStaged).toList();
  List<GitFileStatus> get unstaged =>
      entries.where((e) => e.isUnstaged).toList();
  List<GitFileStatus> get untracked =>
      entries.where((e) => e.isUntracked).toList();
  List<GitFileStatus> get conflicted =>
      entries.where((e) => e.isConflicted).toList();

  bool get isClean => entries.isEmpty;
  bool get hasConflicts => entries.any((e) => e.isConflicted);

  Map<String, Object?> toJson() => {
        'branch': branch,
        if (upstream != null) 'upstream': upstream,
        'ahead': ahead,
        'behind': behind,
        'clean': isClean,
        'hasConflicts': hasConflicts,
        'staged': [for (final e in staged) e.toJson()],
        'unstaged': [for (final e in unstaged) e.toJson()],
        'untracked': [for (final e in untracked) e.toJson()],
        'conflicted': [for (final e in conflicted) e.toJson()],
      };
}

/// Run `git status` and parse the result.
Future<GitStatus> gitStatus(Directory workDir) async {
  final ProcessResult branchResult;
  try {
    branchResult = await Process.run(
      gitBin,
      ['status', '--porcelain=v2', '--branch', '-z'],
      workingDirectory: workDir.path,
    );
  } on ProcessException {
    return const GitStatus(branch: null, entries: []);
  }

  String? branch;
  String? upstream;
  int ahead = 0;
  int behind = 0;

  if (branchResult.exitCode == 0) {
    final output = branchResult.stdout as String;
    for (final line in output.split('\x00')) {
      if (line.startsWith('# branch.head ')) {
        branch = line.substring('# branch.head '.length);
      } else if (line.startsWith('# branch.upstream ')) {
        upstream = line.substring('# branch.upstream '.length);
      } else if (line.startsWith('# branch.ab ')) {
        final parts = line.substring('# branch.ab '.length).split(' ');
        if (parts.length >= 2) {
          ahead = int.tryParse(parts[0].replaceFirst('+', '')) ?? 0;
          behind = int.tryParse(parts[1].replaceFirst('-', '')) ?? 0;
        }
      }
    }
  }

  final ProcessResult result;
  try {
    result = await Process.run(
      gitBin,
      ['status', '--porcelain=v1', '-z'],
      workingDirectory: workDir.path,
    );
  } on ProcessException {
    return GitStatus(branch: branch, entries: const [], upstream: upstream, ahead: ahead, behind: behind);
  }

  if (result.exitCode != 0) {
    return GitStatus(
      branch: branch,
      upstream: upstream,
      ahead: ahead,
      behind: behind,
      entries: const [],
    );
  }

  final entries = parsePorcelainV1(result.stdout as String);
  return GitStatus(
    branch: branch,
    upstream: upstream,
    ahead: ahead,
    behind: behind,
    entries: entries,
  );
}

List<GitFileStatus> parsePorcelainV1(String output) {
  if (output.isEmpty) return const [];
  final entries = <GitFileStatus>[];
  final parts = output.split('\x00');
  var i = 0;
  while (i < parts.length) {
    final part = parts[i];
    if (part.isEmpty) {
      i++;
      continue;
    }
    if (part.length < 4) {
      i++;
      continue;
    }
    final x = part[0]; // index state
    final y = part[1]; // work-tree state
    final path = part.substring(3);

    // Renames/copies have the original path as the next NUL-delimited
    // field (porcelain v1 with -z).
    String? origPath;
    if (x == 'R' || x == 'C') {
      i++;
      if (i < parts.length) origPath = parts[i];
    }

    final conflict = _conflictType(x, y);
    entries.add(GitFileStatus(
      path: path,
      indexState: conflict != null ? null : _parseState(x),
      workTreeState: conflict != null ? null : _parseState(y),
      origPath: origPath,
      conflictType: conflict,
    ));
    i++;
  }
  return entries;
}

GitConflictType? _conflictType(String x, String y) {
  if (x == 'D' && y == 'D') return GitConflictType.bothDeleted;
  if (x == 'A' && y == 'U') return GitConflictType.addedByUs;
  if (x == 'U' && y == 'D') return GitConflictType.deletedByThem;
  if (x == 'U' && y == 'A') return GitConflictType.addedByThem;
  if (x == 'D' && y == 'U') return GitConflictType.deletedByUs;
  if (x == 'A' && y == 'A') return GitConflictType.bothAdded;
  if (x == 'U' && y == 'U') return GitConflictType.bothModified;
  return null;
}

GitFileState? _parseState(String code) {
  return switch (code) {
    'M' => GitFileState.modified,
    'A' => GitFileState.added,
    'D' => GitFileState.deleted,
    'R' => GitFileState.renamed,
    'C' => GitFileState.copied,
    '?' => GitFileState.untracked,
    '!' => GitFileState.ignored,
    _ => null,
  };
}
