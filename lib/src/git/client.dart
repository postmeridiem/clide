/// Typed git client backed by [Toolchain].
///
/// Every subprocess call goes through [_run] which uses the resolved
/// absolute binary path from the toolchain. Parsing is delegated to
/// the existing pure-function parsers in status.dart and diff.dart.
library;

import 'dart:io';

import '../../kernel/src/toolchain.dart';
import 'diff.dart' show GitDiff, parseDiffOutput;
import 'operations.dart' show GitException, GitLogEntry;
import 'status.dart';

class GitClient {
  GitClient({required this.toolchain, required this.workDir});

  final Toolchain toolchain;
  final Directory workDir;

  // -- queries --------------------------------------------------------------

  Future<GitStatus> status() async {
    ProcessResult branchResult;
    try {
      branchResult = await _run(['status', '--porcelain=v2', '--branch', '-z']);
    } on GitException {
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

    ProcessResult result;
    try {
      result = await _run(['status', '--porcelain=v1', '-z']);
    } on GitException {
      return GitStatus(branch: branch, entries: const [], upstream: upstream, ahead: ahead, behind: behind);
    }

    if (result.exitCode != 0) {
      return GitStatus(branch: branch, upstream: upstream, ahead: ahead, behind: behind, entries: const []);
    }

    return GitStatus(
      branch: branch,
      upstream: upstream,
      ahead: ahead,
      behind: behind,
      entries: parsePorcelainV1(result.stdout as String),
    );
  }

  Future<List<GitDiff>> diff({bool staged = false, List<String> paths = const []}) async {
    final args = ['diff', '--unified=3'];
    if (staged) args.add('--cached');
    if (paths.isNotEmpty) {
      args.add('--');
      args.addAll(paths);
    }
    final r = await _run(args);
    if (r.exitCode != 0) return const [];
    return parseDiffOutput(r.stdout as String);
  }

  Future<List<GitLogEntry>> log({int count = 20}) async {
    final r = await _run([
      'log',
      '--format=%H%x00%h%x00%s%x00%an%x00%aI%x00%b%x01',
      '-n',
      '$count',
    ]);
    if (r.exitCode != 0) return const [];
    return parseLog(r.stdout as String);
  }

  Future<String?> currentBranch() async {
    final r = await _run(['symbolic-ref', '--short', 'HEAD']);
    if (r.exitCode != 0) return null;
    return (r.stdout as String).trim();
  }

  Future<List<({String name, bool current})>> branches() async {
    final r = await _run(['branch', '--format=%(refname:short)|%(HEAD)']);
    if (r.exitCode != 0) return const [];
    final out = <({String name, bool current})>[];
    for (final line in (r.stdout as String).split('\n')) {
      if (line.trim().isEmpty) continue;
      final sep = line.lastIndexOf('|');
      if (sep < 0) continue;
      out.add((name: line.substring(0, sep), current: line.substring(sep + 1).trim() == '*'));
    }
    return out;
  }

  /// Resolve a path to its git repo root. Returns null if not a git repo.
  Future<String?> repoRoot(String path) async {
    try {
      final r = await Process.run(
        toolchain.git,
        ['rev-parse', '--show-toplevel'],
        workingDirectory: path,
      );
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  // -- mutations ------------------------------------------------------------

  Future<void> stage(List<String> paths) async {
    final args = ['add'];
    if (paths.isEmpty) {
      args.add('-A');
    } else {
      args.add('--');
      args.addAll(paths);
    }
    final r = await _run(args);
    if (r.exitCode != 0) throw GitException('git add failed', stderr: r.stderr as String);
  }

  Future<void> unstage(List<String> paths) async {
    final args = ['reset', 'HEAD'];
    if (paths.isNotEmpty) {
      args.add('--');
      args.addAll(paths);
    }
    final r = await _run(args);
    if (r.exitCode != 0) throw GitException('git reset failed', stderr: r.stderr as String);
  }

  Future<void> stageHunk(String patch) => _applyPatch(patch, cached: true);

  Future<void> unstageHunk(String patch) => _applyPatch(patch, cached: true, reverse: true);

  Future<void> discard(List<String> paths) async {
    if (paths.isEmpty) return;
    final r = await _run(['checkout', '--', ...paths]);
    if (r.exitCode != 0) throw GitException('git checkout failed', stderr: r.stderr as String);
  }

  Future<String> commit(String message, {bool amend = false}) async {
    final args = ['commit', '-m', message];
    if (amend) args.add('--amend');
    final r = await _run(args);
    if (r.exitCode != 0) throw GitException('git commit failed', stderr: r.stderr as String);
    final hash = await _run(['rev-parse', 'HEAD']);
    return (hash.stdout as String).trim();
  }

  Future<void> stash({String? message, bool includeUntracked = false}) async {
    final args = ['stash', 'push'];
    if (message != null) args.addAll(['-m', message]);
    if (includeUntracked) args.add('--include-untracked');
    final r = await _run(args);
    if (r.exitCode != 0) throw GitException('git stash failed', stderr: r.stderr as String);
  }

  Future<void> stashPop() async {
    final r = await _run(['stash', 'pop']);
    if (r.exitCode != 0) throw GitException('git stash pop failed', stderr: r.stderr as String);
  }

  Future<String> pull() async {
    final r = await _run(['pull']);
    if (r.exitCode != 0) throw GitException('git pull failed', stderr: r.stderr as String);
    return (r.stdout as String).trim();
  }

  Future<String> push({String? remote, String? branch, bool setUpstream = false}) async {
    final args = ['push'];
    if (setUpstream) args.add('-u');
    if (remote != null) args.add(remote);
    if (branch != null) args.add(branch);
    final r = await _run(args);
    if (r.exitCode != 0) throw GitException('git push failed', stderr: r.stderr as String);
    return ((r.stdout as String) + (r.stderr as String)).trim();
  }

  Future<void> checkout(String branch) async {
    final r = await _run(['checkout', branch]);
    if (r.exitCode != 0) throw GitException('git checkout failed', stderr: r.stderr as String);
  }

  // -- internal -------------------------------------------------------------

  Future<ProcessResult> _run(List<String> args) async {
    try {
      return await Process.run(toolchain.git, args, workingDirectory: workDir.path, environment: toolchain.gitEnv);
    } on ProcessException catch (e) {
      throw GitException('git ${args.first}: ${e.message}', stderr: e.toString());
    }
  }

  Future<void> _applyPatch(String patch, {bool cached = false, bool reverse = false}) async {
    final args = ['apply'];
    if (cached) args.add('--cached');
    if (reverse) args.add('--reverse');
    args.addAll(['--unidiff-zero', '-']);

    final proc = await Process.start(toolchain.git, args, workingDirectory: workDir.path, environment: toolchain.gitEnv);
    proc.stdin.write(patch);
    await proc.stdin.close();
    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      final stderr = await proc.stderr.transform(const SystemEncoding().decoder).join();
      throw GitException('git apply failed', stderr: stderr);
    }
  }
}

// -- parsers (pure, no I/O) -------------------------------------------------

List<GitLogEntry> parseLog(String output) {
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
