/// Git operations — staging, committing, stashing, log, pull, push.
///
/// Each function shells out to `git` and returns either a typed result
/// or throws [GitException] on failure. All operations are workspace-
/// rooted (take a [Directory] argument).
library;

import 'dart:io';

class GitException implements Exception {
  const GitException(this.message, {this.stderr = ''});
  final String message;
  final String stderr;

  @override
  String toString() => 'GitException: $message';
}

class GitLogEntry {
  const GitLogEntry({
    required this.hash,
    required this.shortHash,
    required this.subject,
    required this.author,
    required this.date,
    this.body = '',
  });

  final String hash;
  final String shortHash;
  final String subject;
  final String author;
  final String date;
  final String body;

  Map<String, Object?> toJson() => {
        'hash': hash,
        'shortHash': shortHash,
        'subject': subject,
        'author': author,
        'date': date,
        if (body.isNotEmpty) 'body': body,
      };
}

/// Stage files. Empty [paths] means stage all (`git add -A`).
Future<void> gitStage(Directory workDir, List<String> paths) async {
  final args = ['add'];
  if (paths.isEmpty) {
    args.add('-A');
  } else {
    args.add('--');
    args.addAll(paths);
  }
  final r = await Process.run('git', args, workingDirectory: workDir.path);
  if (r.exitCode != 0) {
    throw GitException('git add failed', stderr: r.stderr as String);
  }
}

/// Unstage files. Empty [paths] means unstage all.
Future<void> gitUnstage(Directory workDir, List<String> paths) async {
  final args = ['reset', 'HEAD'];
  if (paths.isNotEmpty) {
    args.add('--');
    args.addAll(paths);
  }
  final r = await Process.run('git', args, workingDirectory: workDir.path);
  if (r.exitCode != 0) {
    throw GitException('git reset failed', stderr: r.stderr as String);
  }
}

/// Stage a single hunk via `git apply --cached`.
Future<void> gitStageHunk(Directory workDir, String patch) async {
  await _applyPatch(workDir, patch, cached: true);
}

/// Unstage a single hunk via `git apply --cached --reverse`.
Future<void> gitUnstageHunk(Directory workDir, String patch) async {
  await _applyPatch(workDir, patch, cached: true, reverse: true);
}

/// Discard unstaged changes for [paths]. Uses `git checkout -- <paths>`.
Future<void> gitDiscard(Directory workDir, List<String> paths) async {
  if (paths.isEmpty) return;
  final r = await Process.run(
    'git',
    ['checkout', '--', ...paths],
    workingDirectory: workDir.path,
  );
  if (r.exitCode != 0) {
    throw GitException('git checkout failed', stderr: r.stderr as String);
  }
}

/// Commit staged changes.
Future<String> gitCommit(
  Directory workDir,
  String message, {
  bool amend = false,
}) async {
  final args = ['commit', '-m', message];
  if (amend) args.add('--amend');
  final r = await Process.run('git', args, workingDirectory: workDir.path);
  if (r.exitCode != 0) {
    throw GitException('git commit failed', stderr: r.stderr as String);
  }
  // Return the new commit hash.
  final hashResult = await Process.run(
    'git',
    ['rev-parse', 'HEAD'],
    workingDirectory: workDir.path,
  );
  return (hashResult.stdout as String).trim();
}

/// Stash working changes.
Future<void> gitStash(
  Directory workDir, {
  String? message,
  bool includeUntracked = false,
}) async {
  final args = ['stash', 'push'];
  if (message != null) {
    args.addAll(['-m', message]);
  }
  if (includeUntracked) args.add('--include-untracked');
  final r = await Process.run('git', args, workingDirectory: workDir.path);
  if (r.exitCode != 0) {
    throw GitException('git stash failed', stderr: r.stderr as String);
  }
}

/// Pop the top stash entry.
Future<void> gitStashPop(Directory workDir) async {
  final r = await Process.run(
    'git',
    ['stash', 'pop'],
    workingDirectory: workDir.path,
  );
  if (r.exitCode != 0) {
    throw GitException('git stash pop failed', stderr: r.stderr as String);
  }
}

/// Git log. Returns the most recent [count] entries.
Future<List<GitLogEntry>> gitLog(
  Directory workDir, {
  int count = 20,
}) async {
  final r = await Process.run(
    'git',
    [
      'log',
      '--format=%H%x00%h%x00%s%x00%an%x00%aI%x00%b%x01',
      '-n',
      '$count',
    ],
    workingDirectory: workDir.path,
  );
  if (r.exitCode != 0) return const [];
  return _parseLog(r.stdout as String);
}

/// Pull from remote.
Future<String> gitPull(Directory workDir) async {
  final r = await Process.run(
    'git',
    ['pull'],
    workingDirectory: workDir.path,
  );
  if (r.exitCode != 0) {
    throw GitException('git pull failed', stderr: r.stderr as String);
  }
  return (r.stdout as String).trim();
}

/// Push to remote.
Future<String> gitPush(
  Directory workDir, {
  String? remote,
  String? branch,
  bool setUpstream = false,
}) async {
  final args = ['push'];
  if (setUpstream) args.add('-u');
  if (remote != null) args.add(remote);
  if (branch != null) args.add(branch);
  final r = await Process.run('git', args, workingDirectory: workDir.path);
  if (r.exitCode != 0) {
    throw GitException('git push failed', stderr: r.stderr as String);
  }
  return ((r.stdout as String) + (r.stderr as String)).trim();
}

/// Get the current branch name.
Future<String?> gitCurrentBranch(Directory workDir) async {
  final r = await Process.run(
    'git',
    ['symbolic-ref', '--short', 'HEAD'],
    workingDirectory: workDir.path,
  );
  if (r.exitCode != 0) return null;
  return (r.stdout as String).trim();
}

// ---------------------------------------------------------------------------

List<GitLogEntry> _parseLog(String output) {
  if (output.trim().isEmpty) return const [];
  final records = output.split('\x01');
  final entries = <GitLogEntry>[];
  for (final record in records) {
    final trimmed = record.trim();
    if (trimmed.isEmpty) continue;
    final fields = trimmed.split('\x00');
    if (fields.length < 5) continue;
    entries.add(GitLogEntry(
      hash: fields[0],
      shortHash: fields[1],
      subject: fields[2],
      author: fields[3],
      date: fields[4],
      body: fields.length > 5 ? fields[5].trim() : '',
    ));
  }
  return entries;
}

Future<void> _applyPatch(
  Directory workDir,
  String patch, {
  bool cached = false,
  bool reverse = false,
}) async {
  final args = ['apply'];
  if (cached) args.add('--cached');
  if (reverse) args.add('--reverse');
  args.add('--unidiff-zero');
  args.add('-');

  final proc = await Process.start(
    'git',
    args,
    workingDirectory: workDir.path,
  );
  proc.stdin.write(patch);
  await proc.stdin.close();
  final exitCode = await proc.exitCode;
  if (exitCode != 0) {
    final stderr = await proc.stderr
        .transform(const SystemEncoding().decoder)
        .join();
    throw GitException(
      'git apply failed',
      stderr: stderr,
    );
  }
}
