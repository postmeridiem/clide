import 'dart:io';

import 'package:clide/src/git/status.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-git-status-test-');
    await Process.run('git', ['init'], workingDirectory: sandbox.path);
    await Process.run('git', ['config', 'user.email', 'test@test.com'], workingDirectory: sandbox.path);
    await Process.run('git', ['config', 'user.name', 'Test'], workingDirectory: sandbox.path);
    // Initial commit so HEAD exists.
    await File('${sandbox.path}/.gitkeep').writeAsString('');
    await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
    await Process.run('git', ['commit', '-m', 'init'], workingDirectory: sandbox.path);
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('clean repo returns empty entries', () async {
    final status = await gitStatus(sandbox);
    expect(status.isClean, isTrue);
    expect(status.branch, isNotNull);
  });

  test('untracked file appears in untracked', () async {
    await File('${sandbox.path}/new.txt').writeAsString('hello');
    final status = await gitStatus(sandbox);
    expect(status.untracked, hasLength(1));
    expect(status.untracked.first.path, 'new.txt');
  });

  test('staged file appears in staged', () async {
    await File('${sandbox.path}/staged.txt').writeAsString('x');
    await Process.run('git', ['add', 'staged.txt'], workingDirectory: sandbox.path);
    final status = await gitStatus(sandbox);
    expect(status.staged, hasLength(1));
    expect(status.staged.first.path, 'staged.txt');
    expect(status.staged.first.indexState, GitFileState.added);
  });

  test('modified tracked file appears in unstaged', () async {
    await File('${sandbox.path}/.gitkeep').writeAsString('changed');
    final status = await gitStatus(sandbox);
    expect(status.unstaged, hasLength(1));
    expect(status.unstaged.first.workTreeState, GitFileState.modified);
  });

  test('deleted file appears in unstaged', () async {
    await File('${sandbox.path}/.gitkeep').delete();
    final status = await gitStatus(sandbox);
    expect(status.unstaged, hasLength(1));
    expect(status.unstaged.first.workTreeState, GitFileState.deleted);
  });

  test('file staged and then modified appears in both', () async {
    await File('${sandbox.path}/both.txt').writeAsString('v1');
    await Process.run('git', ['add', 'both.txt'], workingDirectory: sandbox.path);
    await File('${sandbox.path}/both.txt').writeAsString('v2');
    final status = await gitStatus(sandbox);
    expect(status.staged.any((e) => e.path == 'both.txt'), isTrue);
    expect(status.unstaged.any((e) => e.path == 'both.txt'), isTrue);
  });

  test('branch info is populated', () async {
    final status = await gitStatus(sandbox);
    expect(status.branch, isNotNull);
    expect(status.ahead, isZero);
    expect(status.behind, isZero);
  });

  test('branch.upstream + branch.ab populate upstream/ahead/behind', () async {
    final remote = await Directory.systemTemp.createTemp('clide-status-remote-');
    addTearDown(() => remote.deleteSync(recursive: true));
    await Process.run('git', ['init', '--bare'], workingDirectory: remote.path);
    await Process.run('git', ['remote', 'add', 'origin', remote.path], workingDirectory: sandbox.path);
    await Process.run('git', ['push', '-u', 'origin', 'HEAD'], workingDirectory: sandbox.path);
    // Add a commit so we have ahead > 0.
    await File('${sandbox.path}/ahead.txt').writeAsString('x');
    await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
    await Process.run('git', ['commit', '-m', 'ahead'], workingDirectory: sandbox.path);
    final s = await gitStatus(sandbox);
    expect(s.upstream, contains('origin/'));
    expect(s.ahead, 1);
    expect(s.behind, 0);
  });

  test('gitStatus on a non-git directory returns an empty branchless status', () async {
    final notGit = await Directory.systemTemp.createTemp('clide-status-not-');
    addTearDown(() => notGit.deleteSync(recursive: true));
    final s = await gitStatus(notGit);
    expect(s.entries, isEmpty);
  });

  test('rename in porcelain output captures the original path', () async {
    await File('${sandbox.path}/a.txt').writeAsString('content\n');
    await Process.run('git', ['add', '.'], workingDirectory: sandbox.path);
    await Process.run('git', ['commit', '-m', 'add a'], workingDirectory: sandbox.path);
    await Process.run('git', ['mv', 'a.txt', 'renamed.txt'], workingDirectory: sandbox.path);
    final s = await gitStatus(sandbox);
    final renamed = s.entries.firstWhere((e) => e.path == 'renamed.txt');
    expect(renamed.origPath, 'a.txt');
  });

  test('parsePorcelainV1 handles empty input + short / empty parts', () {
    expect(parsePorcelainV1(''), isEmpty);
    // 'X' is too short (< 4 chars), should be skipped.
    expect(parsePorcelainV1('X\x00'), isEmpty);
    // Empty token-only input — skipped.
    expect(parsePorcelainV1('\x00'), isEmpty);
  });
}
