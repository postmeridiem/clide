import 'dart:io';

import 'package:clide/src/git/status.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-git-status-test-');
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
    // Initial commit so HEAD exists.
    await File('${sandbox.path}/.gitkeep').writeAsString('');
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
    await Process.run(
      'git',
      ['add', 'staged.txt'],
      workingDirectory: sandbox.path,
    );
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
    await Process.run(
      'git',
      ['add', 'both.txt'],
      workingDirectory: sandbox.path,
    );
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
}
