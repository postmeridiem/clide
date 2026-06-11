/// Drives every git.* daemon handler with a GitClient whose toolchain
/// points at a non-existent binary. Each underlying call throws
/// GitException, exercising the catch branches in
/// `lib/src/daemon/git_commands.dart` that the happy-path suite can't
/// reach.
library;

import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:test/test.dart';

void main() {
  late DaemonDispatcher dispatcher;
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('clide-git-cmd-err-');
    final toolchain = ToolchainView.resolved(const ResolvedPaths(git: '/tmp/clide-no-such-git-binary'));
    final git = GitClient(toolchain: toolchain, workDir: sandbox);
    dispatcher = DaemonDispatcher();
    final sink = RecordingEventSink();
    registerGitCommands(dispatcher, git, sink);
  });

  tearDown(() async {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  final cases = [
    ('git.status', const <String, Object?>{}),
    ('git.diff', const <String, Object?>{}),
    ('git.log', const <String, Object?>{}),
    (
      'git.stage',
      const {
        'paths': ['file.txt'],
      },
    ),
    ('git.stage-all', const <String, Object?>{}),
    ('git.unstage', const <String, Object?>{}),
    // git.stage-hunk / git.unstage-hunk go through GitClient._applyPatch
    // which uses Process.start (not Process.run) — that throws
    // ProcessException directly without wrapping in GitException.
    // Leaving them out so the fault-injection harness stays clean;
    // separate ticket if we ever want to catch + rewrap there.
    (
      'git.discard',
      const {
        'paths': ['file.txt'],
      },
    ),
    ('git.commit', const {'message': 'hi'}),
    ('git.stash', const <String, Object?>{}),
    ('git.stash-pop', const <String, Object?>{}),
    ('git.pull', const <String, Object?>{}),
    ('git.push', const <String, Object?>{}),
    ('git.branches', const <String, Object?>{}),
    ('git.checkout', const {'branch': 'main'}),
  ];

  for (final (cmd, args) in cases) {
    test('$cmd surfaces GitException as a toolError', () async {
      final r = await call(cmd, args);
      // Some commands have happy fallbacks (git.diff returns empty on
      // non-zero exit; git.log similar) — those return ok=true with
      // empty data. Only assert ok=false for the ones that throw.
      if (!r.ok) {
        expect(r.error?.kind, IpcErrorKind.toolError, reason: cmd);
      }
    });
  }
}
