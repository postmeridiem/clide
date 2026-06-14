/// Shared git plumbing: the resolved `git` binary path, the typed
/// failure ([GitException]), the ref-shaped-argument validator, and the
/// log entry model. The legacy free-function operation API that used to
/// live here duplicated [GitClient] verb-for-verb, had no non-test
/// callers, and carried a latent pipe deadlock in its hunk-apply path —
/// removed in the T-385 dead-code sweep; use [GitClient].
library;

import 'dart:io';

import '../pty/env.dart';

/// Resolve git to an absolute path. On macOS the sandbox blocks bare
/// `git` calls; Homebrew's git is a symlink into Cellar so we need
/// the real resolved path.
String get gitBin {
  _gitBin ??= _resolveGit();
  return _gitBin!;
}

String? _gitBin;

String _resolveGit() {
  for (final dir in expandedPath.split(':')) {
    if (dir.isEmpty) continue;
    final f = File('$dir/git');
    if (f.existsSync()) return f.resolveSymbolicLinksSync();
  }
  return 'git';
}

class GitException implements Exception {
  const GitException(this.message, {this.stderr = ''});
  final String message;
  final String stderr;

  @override
  String toString() => 'GitException: $message';
}

/// Validate a string about to be passed to git as a branch name,
/// remote name, or similar ref-shaped positional argument. Rejects
/// empty values and anything starting with `-`, which would otherwise
/// be parsed as an option flag by git (the classic
/// `--upload-pack=evil` argv-injection vector). Throws [GitException]
/// — callers convert it to the right IPC error kind.
void validateGitRef(String? value, {required String kind}) {
  if (value == null || value.isEmpty) {
    throw GitException('$kind is required');
  }
  if (value.startsWith('-')) {
    throw GitException('$kind cannot start with "-" (looks like an option flag): $value');
  }
}

class GitLogEntry {
  const GitLogEntry({required this.hash, required this.shortHash, required this.subject, required this.author, required this.date, this.body = ''});

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
