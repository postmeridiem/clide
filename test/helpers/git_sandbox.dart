/// Hermetic git for tests (T-639).
///
/// A test repo must not pick up the developer's global or system git
/// config: commit signing, hooks paths, templates, `init.defaultBranch`,
/// aliases and credential helpers all change what git does, so a test
/// that passes on one machine fails (or signs, or prompts) on another.
/// Every git call here runs with no global/system config and a fixed
/// identity, and a failing setup step throws instead of leaving a
/// half-built repo behind for the assertions to trip over.
///
/// Flutter-free: used by suites that run under plain `dart test`.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain_paths.dart';

/// Environment for any git process a test starts, directly or through a
/// `GitClient`: no global or system config, and a fixed identity.
const Map<String, String> sandboxGitEnv = {
  'GIT_CONFIG_GLOBAL': '/dev/null',
  'GIT_CONFIG_NOSYSTEM': '1',
  'GIT_AUTHOR_NAME': 'Test',
  'GIT_AUTHOR_EMAIL': 'test@example.com',
  'GIT_COMMITTER_NAME': 'Test',
  'GIT_COMMITTER_EMAIL': 'test@example.com',
};

/// The resolved toolchain with [sandboxGitEnv] layered over its git env,
/// for handing to a `GitClient` under test.
ToolchainView sandboxToolchain() {
  final r = resolveToolchainPaths();
  return ToolchainView.resolved(ResolvedPaths(git: r.git, pql: r.pql, shell: r.shell, gitEnv: {...?r.gitEnv, ...sandboxGitEnv}));
}

/// Run `git [args]` in [dir] with the sandbox env. Throws [StateError]
/// on a non-zero exit, with git's stderr.
Future<ProcessResult> sandboxGit(Directory dir, List<String> args) async {
  final r = await Process.run('git', args, workingDirectory: dir.path, environment: sandboxGitEnv);
  if (r.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed (${r.exitCode}): ${r.stderr}');
  }
  return r;
}

/// A fresh repo on `main` in a temp dir (symlinks resolved, so paths
/// compare equal to what git reports). With [files], they are written
/// and committed as `init`. The caller deletes it.
Future<Directory> newSandboxRepo({String prefix = 'clide-git-', Map<String, String> files = const {}}) async {
  final dir = Directory((await Directory.systemTemp.createTemp(prefix)).resolveSymbolicLinksSync());
  await sandboxGit(dir, ['init', '-q', '-b', 'main']);
  if (files.isNotEmpty) {
    for (final e in files.entries) {
      final f = File('${dir.path}/${e.key}');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(e.value);
    }
    await sandboxGit(dir, ['add', '.']);
    await sandboxGit(dir, ['commit', '-q', '-m', 'init']);
  }
  return dir;
}
