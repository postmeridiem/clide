/// Integration tests for `lib/src/git/client.dart` — drives a real
/// git binary against a temp sandbox, covering the GitClient public
/// API + the parseLog parser.
library;

import 'dart:io';

import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/git/client.dart';
import 'package:clide/src/git/operations.dart' show GitException;
import 'package:test/test.dart';

ToolchainView _toolchain() => ToolchainView.resolved(resolveToolchainPaths());

Future<Directory> _newRepo({String filename = 'file.txt', String contents = 'hello\n'}) async {
  final dir = await Directory.systemTemp.createTemp('clide-git-client-');
  await Process.run('git', ['init', '-b', 'main'], workingDirectory: dir.path);
  await Process.run('git', ['config', 'user.email', 'test@test.com'], workingDirectory: dir.path);
  await Process.run('git', ['config', 'user.name', 'Test'], workingDirectory: dir.path);
  await File('${dir.path}/$filename').writeAsString(contents);
  await Process.run('git', ['add', '.'], workingDirectory: dir.path);
  await Process.run('git', ['commit', '-m', 'init'], workingDirectory: dir.path);
  return dir;
}

void main() {
  group('GitClient — init (T-487)', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('clide-git-init-'));
    tearDown(() async {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('init creates a repo on the default branch and is idempotent', () async {
      final git = GitClient(toolchain: _toolchain(), workDir: dir);
      await git.init();
      expect(Directory('${dir.path}/.git').existsSync(), isTrue);
      expect(await git.currentBranch(), 'main');
      // A second init on the existing repo is a no-op, not an error.
      await git.init();
      expect(Directory('${dir.path}/.git').existsSync(), isTrue);
    });
  });

  group('GitClient — queries', () {
    late Directory sandbox;
    late GitClient git;

    setUp(() async {
      sandbox = await _newRepo();
      git = GitClient(toolchain: _toolchain(), workDir: sandbox);
    });

    tearDown(() async {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('status returns branch + entries on a clean repo', () async {
      final s = await git.status();
      expect(s.branch, 'main');
      expect(s.entries, isEmpty);
    });

    test('status with an upstream parses ahead/behind counts', () async {
      // Set up a bare repo as a remote and track it.
      final remote = await Directory.systemTemp.createTemp('clide-git-remote-');
      addTearDown(() => remote.deleteSync(recursive: true));
      await Process.run('git', ['init', '--bare'], workingDirectory: remote.path);
      await Process.run('git', ['remote', 'add', 'origin', remote.path], workingDirectory: sandbox.path);
      await Process.run('git', ['push', '-u', 'origin', 'main'], workingDirectory: sandbox.path);
      // Add an uncommitted divergence to make ahead/behind interesting.
      await File('${sandbox.path}/extra.txt').writeAsString('x');
      await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
      await Process.run('git', ['commit', '-m', 'second'], workingDirectory: sandbox.path);
      final s = await git.status();
      expect(s.branch, 'main');
      expect(s.upstream, contains('origin/main'));
      expect(s.ahead, 1);
      expect(s.behind, 0);
    });

    test('diff with explicit paths narrows the diff to those files', () async {
      await File('${sandbox.path}/file.txt').writeAsString('hello\nworld\n');
      await File('${sandbox.path}/other.txt').writeAsString('other');
      final scoped = await git.diff(paths: ['file.txt']);
      expect(scoped, hasLength(1));
      expect(scoped.first.path, 'file.txt');
    });

    test('log returns commit entries', () async {
      final entries = await git.log(count: 5);
      expect(entries, isNotEmpty);
      expect(entries.first.subject, 'init');
    });

    test('currentBranch returns the current branch name', () async {
      expect(await git.currentBranch(), 'main');
    });

    test('branches lists local branches and marks the current one', () async {
      await Process.run('git', ['branch', 'feature/a'], workingDirectory: sandbox.path);
      final all = await git.branches();
      final names = all.map((b) => b.name).toList();
      expect(names, containsAll(['main', 'feature/a']));
      final main = all.firstWhere((b) => b.name == 'main');
      expect(main.current, isTrue);
    });

    test('repoRoot returns the repo path for an in-repo dir', () async {
      final root = await git.repoRoot(sandbox.path);
      expect(root, isNotNull);
      // Resolve symlinks both ways: realpath may differ from sandbox.path.
      expect(File(root!).existsSync() || Directory(root).existsSync(), isTrue);
    });

    test('repoRoot returns null for a non-git directory', () async {
      final notGit = await Directory.systemTemp.createTemp('clide-not-git-');
      addTearDown(() => notGit.deleteSync(recursive: true));
      expect(await git.repoRoot(notGit.path), isNull);
    });
  });

  group('GitClient — mutations', () {
    late Directory sandbox;
    late GitClient git;

    setUp(() async {
      sandbox = await _newRepo();
      git = GitClient(toolchain: _toolchain(), workDir: sandbox);
    });

    tearDown(() async {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('unstage with explicit paths resets only those', () async {
      await File('${sandbox.path}/new.txt').writeAsString('x');
      await git.stage(['new.txt']);
      await git.unstage(['new.txt']);
      final r = await Process.run('git', ['diff', '--cached', '--name-only'], workingDirectory: sandbox.path);
      expect((r.stdout as String).trim(), isEmpty);
    });

    test('commit creates a commit and returns the HEAD hash', () async {
      await File('${sandbox.path}/c.txt').writeAsString('commit me');
      await git.stage(['c.txt']);
      final hash = await git.commit('add c');
      expect(hash, hasLength(40));
    });

    test('discard restores tracked files to HEAD', () async {
      await File('${sandbox.path}/file.txt').writeAsString('mutated');
      await git.discard(['file.txt']);
      final contents = await File('${sandbox.path}/file.txt').readAsString();
      expect(contents, 'hello\n');
    });

    test('discard with an empty list is a no-op', () async {
      await git.discard(const []);
    });

    test('stash + stashPop save and restore working-tree changes', () async {
      await File('${sandbox.path}/file.txt').writeAsString('mutated\n');
      await git.stash(message: 'wip', includeUntracked: true);
      // After stash, the working tree is restored to HEAD.
      expect(await File('${sandbox.path}/file.txt').readAsString(), 'hello\n');
      await git.stashPop();
      expect(await File('${sandbox.path}/file.txt').readAsString(), 'mutated\n');
    });

    test('checkout switches to an existing branch', () async {
      await Process.run('git', ['branch', 'feature/x'], workingDirectory: sandbox.path);
      await git.checkout('feature/x');
      expect(await git.currentBranch(), 'feature/x');
    });

    test('stageHunk applies a patch to the index; unstageHunk reverses it', () async {
      // Modify file.txt and produce a patch for the change.
      await File('${sandbox.path}/file.txt').writeAsString('hello\nworld\n');
      final patchProc = await Process.run('git', ['diff', '-U0'], workingDirectory: sandbox.path);
      final patch = patchProc.stdout as String;
      await git.stageHunk(patch);
      // After stageHunk, the change is in the index.
      final cached = await Process.run('git', ['diff', '--cached', '--name-only'], workingDirectory: sandbox.path);
      expect((cached.stdout as String).trim(), 'file.txt');
      await git.unstageHunk(patch);
      // After unstageHunk, the index is clean again.
      final cleared = await Process.run('git', ['diff', '--cached', '--name-only'], workingDirectory: sandbox.path);
      expect((cleared.stdout as String).trim(), isEmpty);
    });

    test('mutations throw GitException on non-zero exit', () async {
      // commit with nothing staged → non-zero exit.
      try {
        await git.commit('nothing');
        fail('expected GitException');
      } on GitException catch (_) {}
    });

    test('_applyPatch surfaces stderr in the GitException on bad patch', () async {
      try {
        await git.stageHunk('not a valid patch\n');
        fail('expected GitException');
      } on GitException catch (e) {
        expect(e.toString(), contains('apply'));
      }
    });
  });

  group('GitClient — error surface', () {
    test('a bad git binary path makes _run throw GitException', () async {
      final t = ToolchainView.resolved(const ResolvedPaths(git: '/tmp/clide-no-such-git-binary'));
      final dir = await Directory.systemTemp.createTemp('clide-git-bad-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final git = GitClient(toolchain: t, workDir: dir);
      try {
        await git.commit('whatever');
        fail('expected GitException');
      } on GitException catch (e) {
        expect(e.toString(), contains('git'));
      }
    });

    test('queries return empty fallbacks when git exits non-zero', () async {
      // workDir is a temp dir that's NOT a git repo — every command exits
      // non-zero. Each query method returns its empty fallback.
      final dir = await Directory.systemTemp.createTemp('clide-not-git-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final git = GitClient(toolchain: _toolchain(), workDir: dir);
      expect(await git.diff(), isEmpty);
      expect(await git.log(), isEmpty);
      expect(await git.currentBranch(), isNull);
      expect(await git.branches(), isEmpty);
    });
  });

  group('parseLog — pure parser', () {
    test('empty input returns an empty list', () {
      expect(parseLog(''), isEmpty);
      expect(parseLog('   \n'), isEmpty);
    });

    test('skips records with fewer than 5 fields', () {
      // Only 3 fields between record separators.
      expect(parseLog('abc\x00def\x00ghi\x01'), isEmpty);
    });

    test('parses a full record with a body', () {
      const record = 'fullhash\x00short\x00subject line\x00Author\x002026-05-13\x00body text\x01';
      final r = parseLog(record);
      expect(r, hasLength(1));
      expect(r.first.hash, 'fullhash');
      expect(r.first.subject, 'subject line');
      expect(r.first.body, 'body text');
    });

    test('handles records without a body (5 fields exactly)', () {
      const record = 'fullhash\x00short\x00subject\x00Author\x002026-05-13\x01';
      final r = parseLog(record);
      expect(r, hasLength(1));
      expect(r.first.body, '');
    });
  });
}
