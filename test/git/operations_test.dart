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
}
