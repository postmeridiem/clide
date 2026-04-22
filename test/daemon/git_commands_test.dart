import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late DaemonDispatcher dispatcher;
  late RecordingEventSink sink;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-git-cmd-test-');
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

    sink = RecordingEventSink();
    dispatcher = DaemonDispatcher();
    registerGitCommands(dispatcher, sandbox, sink);
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<IpcResponse> call(String cmd,
      [Map<String, Object?> args = const {}]) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  test('git.status returns clean status', () async {
    final r = await call('git.status');
    expect(r.ok, isTrue);
    expect(r.data['clean'], isTrue);
    expect(r.data['branch'], isNotNull);
  });

  test('git.status shows untracked files', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    final r = await call('git.status');
    expect(r.ok, isTrue);
    final untracked = r.data['untracked'] as List;
    expect(untracked, hasLength(1));
  });

  test('git.stage + git.status shows staged file', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    final stage = await call('git.stage', {'paths': ['new.txt']});
    expect(stage.ok, isTrue);

    final r = await call('git.status');
    final staged = r.data['staged'] as List;
    expect(staged, hasLength(1));
  });

  test('git.stage without paths returns error', () async {
    final r = await call('git.stage');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('git.unstage removes from staging', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    await call('git.stage', {'paths': ['new.txt']});
    final unstage = await call('git.unstage', {'paths': ['new.txt']});
    expect(unstage.ok, isTrue);

    final r = await call('git.status');
    final staged = r.data['staged'] as List;
    expect(staged, isEmpty);
  });

  test('git.commit creates a commit', () async {
    await File('${sandbox.path}/c.txt').writeAsString('x');
    await call('git.stage', {'paths': ['c.txt']});
    final r = await call('git.commit', {'message': 'test commit'});
    expect(r.ok, isTrue);
    expect(r.data['hash'], hasLength(40));
  });

  test('git.commit without message returns error', () async {
    final r = await call('git.commit');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('git.diff returns diffs for modified files', () async {
    await File('${sandbox.path}/file.txt').writeAsString('modified\n');
    final r = await call('git.diff');
    expect(r.ok, isTrue);
    final diffs = r.data['diffs'] as List;
    expect(diffs, hasLength(1));
  });

  test('git.diff --staged returns staged diffs', () async {
    await File('${sandbox.path}/file.txt').writeAsString('modified\n');
    await call('git.stage', {'paths': ['file.txt']});
    final r = await call('git.diff', {'staged': true});
    expect(r.ok, isTrue);
    final diffs = r.data['diffs'] as List;
    expect(diffs, hasLength(1));
  });

  test('git.log returns entries', () async {
    final r = await call('git.log');
    expect(r.ok, isTrue);
    final entries = r.data['entries'] as List;
    expect(entries, isNotEmpty);
  });

  test('git.discard restores a file', () async {
    await File('${sandbox.path}/file.txt').writeAsString('changed');
    final r = await call('git.discard', {'paths': ['file.txt']});
    expect(r.ok, isTrue);
    final content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'hello\n');
  });

  test('git.discard without paths returns error', () async {
    final r = await call('git.discard');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('mutations emit git.changed events', () async {
    await File('${sandbox.path}/e.txt').writeAsString('x');
    await call('git.stage', {'paths': ['e.txt']});
    expect(
      sink.events,
      contains(predicate<IpcEvent>((e) => e.kind == 'git.changed')),
    );
  });

  test('git.stage-all stages everything', () async {
    await File('${sandbox.path}/a.txt').writeAsString('a');
    await File('${sandbox.path}/b.txt').writeAsString('b');
    final r = await call('git.stage-all');
    expect(r.ok, isTrue);

    final status = await call('git.status');
    final staged = status.data['staged'] as List;
    expect(staged.length, greaterThanOrEqualTo(2));
  });

  test('git.stash and git.stash-pop round-trip', () async {
    await File('${sandbox.path}/file.txt').writeAsString('stash-me');
    final stash = await call('git.stash');
    expect(stash.ok, isTrue);

    var content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'hello\n');

    final pop = await call('git.stash-pop');
    expect(pop.ok, isTrue);
    content = await File('${sandbox.path}/file.txt').readAsString();
    expect(content, 'stash-me');
  });
}
