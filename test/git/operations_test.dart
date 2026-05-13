import 'dart:io';

import 'package:clide/src/git/operations.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-git-ops-test-');
    await Process.run('git', ['init'], workingDirectory: sandbox.path);
    await Process.run(
      'git',
      ['config', 'user.email', 'test@test.com'],
      workingDirectory: sandbox.path,
    );
    await Process.run(
      'git',
      ['config', 'user.name', 'Test'],
      workingDirectory: sandbox.path,
    );
    await File('${sandbox.path}/file.txt').writeAsString('hello\n');
    await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
    await Process.run(
      'git',
      ['commit', '-m', 'init'],
      workingDirectory: sandbox.path,
    );
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('gitStage stages a file', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    await gitStage(sandbox, ['new.txt']);
    final r = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: sandbox.path,
    );
    expect((r.stdout as String).trim(), 'new.txt');
  });

  test('gitUnstage unstages a file', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    await gitStage(sandbox, ['new.txt']);
    await gitUnstage(sandbox, ['new.txt']);
    final r = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: sandbox.path,
    );
    expect((r.stdout as String).trim(), isEmpty);
  });

  test('gitCommit creates a commit', () async {
    await File('${sandbox.path}/c.txt').writeAsString('commit me');
    await gitStage(sandbox, ['c.txt']);
    final hash = await gitCommit(sandbox, 'test commit');
    expect(hash, hasLength(40));
    final r = await Process.run(
      'git',
      ['log', '-1', '--format=%s'],
      workingDirectory: sandbox.path,
    );
    expect((r.stdout as String).trim(), 'test commit');
  });

  test('gitCommit with nothing staged throws', () async {
    expect(
      () => gitCommit(sandbox, 'empty'),
      throwsA(isA<GitException>()),
    );
  });

  test('gitLog returns entries', () async {
    final entries = await gitLog(sandbox);
    expect(entries, hasLength(1));
    expect(entries.first.subject, 'init');
    expect(entries.first.hash, hasLength(40));
  });

  test('gitDiscard restores a file', () async {
    await File('${sandbox.path}/file.txt').writeAsString('changed');
    await gitDiscard(sandbox, ['file.txt']);
    final content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'hello\n');
  });

  test('gitStash and gitStashPop round-trip', () async {
    await File('${sandbox.path}/file.txt').writeAsString('stashed');
    await gitStash(sandbox);
    var content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'hello\n');

    await gitStashPop(sandbox);
    content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'stashed');
  });

  test('gitCurrentBranch returns branch name', () async {
    final branch = await gitCurrentBranch(sandbox);
    expect(branch, isNotNull);
  });

  test('GitException.toString includes the message', () {
    const e = GitException('boom');
    expect(e.toString(), contains('boom'));
  });

  test('GitLogEntry.toJson serialises every field (body omitted when empty)', () {
    const a = GitLogEntry(
      hash: 'h',
      shortHash: 's',
      subject: 'sub',
      author: 'a',
      date: 'd',
    );
    expect(a.toJson().containsKey('body'), isFalse);
    const b = GitLogEntry(
      hash: 'h',
      shortHash: 's',
      subject: 'sub',
      author: 'a',
      date: 'd',
      body: 'bd',
    );
    expect(b.toJson()['body'], 'bd');
  });

  test('gitStage with a bogus path throws GitException', () async {
    try {
      await gitStage(sandbox, ['no-such-file-here']);
      fail('expected GitException');
    } on GitException catch (_) {}
  });

  test('gitUnstage with no paths unstages everything', () async {
    await File('${sandbox.path}/a.txt').writeAsString('x');
    await File('${sandbox.path}/b.txt').writeAsString('y');
    await gitStage(sandbox, ['a.txt', 'b.txt']);
    await gitUnstage(sandbox, const []);
    final r = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: sandbox.path,
    );
    expect((r.stdout as String).trim(), isEmpty);
  });

  test('gitStageHunk + gitUnstageHunk apply a patch via _applyPatch', () async {
    await File('${sandbox.path}/file.txt').writeAsString('hello\nworld\n');
    final patchResult = await Process.run(
      'git',
      ['diff', '-U0'],
      workingDirectory: sandbox.path,
    );
    final patch = patchResult.stdout as String;
    await gitStageHunk(sandbox, patch);
    final cached = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: sandbox.path,
    );
    expect((cached.stdout as String).trim(), 'file.txt');
    await gitUnstageHunk(sandbox, patch);
    final cleared = await Process.run(
      'git',
      ['diff', '--cached', '--name-only'],
      workingDirectory: sandbox.path,
    );
    expect((cleared.stdout as String).trim(), isEmpty);
  });

  test('_applyPatch surfaces stderr in the GitException on a bad patch', () async {
    try {
      await gitStageHunk(sandbox, 'not a valid patch\n');
      fail('expected GitException');
    } on GitException catch (e) {
      expect(e.stderr, isNotEmpty);
    }
  });

  test('gitBranches lists branches and marks the current one', () async {
    await Process.run('git', ['branch', 'feature/a'], workingDirectory: sandbox.path);
    final branches = await gitBranches(sandbox);
    final names = branches.map((b) => b.name).toList();
    expect(names, containsAll(['feature/a']));
    expect(branches.any((b) => b.current), isTrue);
  });

  test('gitBranches returns empty on a non-git directory', () async {
    final notGit = await Directory.systemTemp.createTemp('clide-git-not-');
    addTearDown(() => notGit.deleteSync(recursive: true));
    expect(await gitBranches(notGit), isEmpty);
  });

  test('gitCheckout switches branches; an unknown branch throws', () async {
    await Process.run('git', ['branch', 'next'], workingDirectory: sandbox.path);
    await gitCheckout(sandbox, 'next');
    expect(await gitCurrentBranch(sandbox), 'next');
    try {
      await gitCheckout(sandbox, 'does-not-exist');
      fail('expected GitException');
    } on GitException catch (_) {}
  });

  test('gitPull + gitPush round-trip against a local bare remote', () async {
    final remote = await Directory.systemTemp.createTemp('clide-git-remote-');
    addTearDown(() => remote.deleteSync(recursive: true));
    await Process.run('git', ['init', '--bare'], workingDirectory: remote.path);
    await Process.run('git', ['remote', 'add', 'origin', remote.path], workingDirectory: sandbox.path);
    final pushOut = await gitPush(sandbox, remote: 'origin', branch: 'main', setUpstream: true);
    expect(pushOut, isNotEmpty);
    // Clone elsewhere and pull on the original. Cheaper: just call gitPull
    // and confirm it doesn't throw (already up-to-date).
    final pullOut = await gitPull(sandbox);
    expect(pullOut, isA<String>());
  });

  test('gitPush against no remote throws GitException', () async {
    try {
      await gitPush(sandbox);
      fail('expected GitException');
    } on GitException catch (_) {}
  });

  test('gitPull against no remote throws GitException', () async {
    try {
      await gitPull(sandbox);
      fail('expected GitException');
    } on GitException catch (_) {}
  });

  test('gitLog returns empty on a non-git directory', () async {
    final notGit = await Directory.systemTemp.createTemp('clide-git-log-');
    addTearDown(() => notGit.deleteSync(recursive: true));
    expect(await gitLog(notGit), isEmpty);
  });

  test('gitCurrentBranch returns null on a non-git directory', () async {
    final notGit = await Directory.systemTemp.createTemp('clide-git-cb-');
    addTearDown(() => notGit.deleteSync(recursive: true));
    expect(await gitCurrentBranch(notGit), isNull);
  });

  test('gitStashPop on an empty stash throws GitException', () async {
    try {
      await gitStashPop(sandbox);
      fail('expected GitException');
    } on GitException catch (_) {}
  });

  test('gitDiscard with an empty list returns without invoking git', () async {
    // Empty list short-circuits before the subprocess call; just verify
    // it doesn't throw.
    await gitDiscard(sandbox, const []);
  });

  test('gitBin resolves to a usable binary path', () {
    expect(gitBin, isNotEmpty);
  });
}
