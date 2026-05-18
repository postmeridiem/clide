import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/toolchain_paths.dart';
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
    final toolchain = ToolchainView.resolved(resolveToolchainPaths());
    final gitClient = GitClient(toolchain: toolchain, workDir: sandbox);
    registerGitCommands(dispatcher, gitClient, sink);
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) {
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
    final stage = await call('git.stage', {
      'paths': ['new.txt']
    });
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
    await call('git.stage', {
      'paths': ['new.txt']
    });
    final unstage = await call('git.unstage', {
      'paths': ['new.txt']
    });
    expect(unstage.ok, isTrue);

    final r = await call('git.status');
    final staged = r.data['staged'] as List;
    expect(staged, isEmpty);
  });

  test('git.commit creates a commit', () async {
    await File('${sandbox.path}/c.txt').writeAsString('x');
    await call('git.stage', {
      'paths': ['c.txt']
    });
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
    await call('git.stage', {
      'paths': ['file.txt']
    });
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
    final r = await call('git.discard', {
      'paths': ['file.txt']
    });
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
    await call('git.stage', {
      'paths': ['e.txt']
    });
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

  test('git.diff with explicit paths narrows the result', () async {
    await File('${sandbox.path}/file.txt').writeAsString('hello\nworld\n');
    await File('${sandbox.path}/other.txt').writeAsString('o');
    final r = await call('git.diff', {
      'paths': ['file.txt']
    });
    expect(r.ok, isTrue);
    final diffs = r.data['diffs'] as List;
    expect(diffs, hasLength(1));
  });

  test('git.stage-hunk requires a non-empty patch', () async {
    final missing = await call('git.stage-hunk');
    expect(missing.ok, isFalse);
    expect(missing.error?.kind, IpcErrorKind.userError);
    final empty = await call('git.stage-hunk', {'patch': ''});
    expect(empty.ok, isFalse);
  });

  test('git.unstage-hunk requires a non-empty patch', () async {
    final missing = await call('git.unstage-hunk');
    expect(missing.ok, isFalse);
    expect(missing.error?.kind, IpcErrorKind.userError);
  });

  test('git.stage-hunk + git.unstage-hunk round-trip a real patch', () async {
    await File('${sandbox.path}/file.txt').writeAsString('hello\nworld\n');
    final p = await Process.run('git', ['diff', '-U0'], workingDirectory: sandbox.path);
    final patch = p.stdout as String;
    final staged = await call('git.stage-hunk', {'patch': patch});
    expect(staged.ok, isTrue);
    final unstaged = await call('git.unstage-hunk', {'patch': patch});
    expect(unstaged.ok, isTrue);
  });

  test('git.stage-hunk surfaces GitException as a tool error', () async {
    final r = await call('git.stage-hunk', {'patch': 'not a valid patch\n'});
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });

  test('git.branches lists the local branches', () async {
    await Process.run('git', ['branch', 'feature/a'], workingDirectory: sandbox.path);
    final r = await call('git.branches');
    expect(r.ok, isTrue);
    final branches = r.data['branches'] as List;
    expect(branches.map((b) => (b as Map)['name']), containsAll(['feature/a']));
  });

  test('git.checkout requires a branch name', () async {
    final missing = await call('git.checkout');
    expect(missing.ok, isFalse);
    expect(missing.error?.kind, IpcErrorKind.userError);
    final empty = await call('git.checkout', {'branch': ''});
    expect(empty.ok, isFalse);
  });

  test('git.checkout switches branches', () async {
    await Process.run('git', ['branch', 'next'], workingDirectory: sandbox.path);
    final r = await call('git.checkout', {'branch': 'next'});
    expect(r.ok, isTrue);
    expect(r.data['branch'], 'next');
  });

  test('git.checkout to an unknown branch surfaces a tool error', () async {
    final r = await call('git.checkout', {'branch': 'no-such-branch'});
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });

  test('git.log accepts an explicit count', () async {
    final r = await call('git.log', {'count': 5});
    expect(r.ok, isTrue);
    final entries = r.data['entries'] as List;
    expect(entries, isNotEmpty);
  });

  test('git.push to no remote surfaces a tool error', () async {
    final r = await call('git.push');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });

  test('git.pull with no remote surfaces a tool error', () async {
    final r = await call('git.pull');
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.toolError);
  });

  test('git.push + git.pull against a local bare remote return output', () async {
    final remote = await Directory.systemTemp.createTemp('clide-git-cmd-remote-');
    addTearDown(() => remote.deleteSync(recursive: true));
    await Process.run('git', ['init', '--bare'], workingDirectory: remote.path);
    await Process.run('git', ['remote', 'add', 'origin', remote.path], workingDirectory: sandbox.path);
    final pushed = await call('git.push', {'remote': 'origin', 'branch': 'HEAD', 'setUpstream': true});
    expect(pushed.ok, isTrue);
    final pulled = await call('git.pull');
    expect(pulled.ok, isTrue);
  });

  test('git.stage accepts a string single-path arg', () async {
    await File('${sandbox.path}/new.txt').writeAsString('x');
    // _pathList accepts a String, wrapping it as a singleton.
    final r = await call('git.stage', {'paths': 'new.txt'});
    expect(r.ok, isTrue);
  });

  test('git.checkout rejects a -prefixed branch (argv-injection guard)', () async {
    final r = await call('git.checkout', {'branch': '--upload-pack=evil'});
    expect(r.ok, isFalse);
    expect(r.error?.message, contains('branch'));
  });

  test('git.push rejects a -prefixed remote', () async {
    final r = await call('git.push', {'remote': '--upload-pack=evil', 'branch': 'main'});
    expect(r.ok, isFalse);
    expect(r.error?.message, contains('remote'));
  });

  test('git.push rejects a -prefixed branch', () async {
    final r = await call('git.push', {'remote': 'origin', 'branch': '--exec=evil'});
    expect(r.ok, isFalse);
    expect(r.error?.message, contains('branch'));
  });

  test('git.log over the count cap fails as userError', () async {
    final r = await call('git.log', {'count': 100000});
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(r.error?.message, contains('exceeds cap'));
  });

  test('git.diff with too many paths fails as userError', () async {
    final paths = [for (var i = 0; i < 300; i++) 'file_$i.txt'];
    final r = await call('git.diff', {'paths': paths});
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(r.error?.message, contains('exceeds cap'));
  });

  test('git.stage with too many paths fails as userError', () async {
    final paths = [for (var i = 0; i < 300; i++) 'file_$i.txt'];
    final r = await call('git.stage', {'paths': paths});
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.userError);
    expect(r.error?.message, contains('exceeds cap'));
  });
}
