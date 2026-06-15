/// Tests for GitController — the git sidebar's state model. Drives every
/// action against a stubbed DaemonClient (no real git), covering status
/// hydration + parsing, the stage/unstage/discard/commit/stash verbs, the
/// event-driven refresh, and the push/pull MessageBus toast emitters (T-50).
///
/// The KernelFixture is built in setUp (real file I/O — kept out of any
/// fake-async zone); these are plain async tests, so the toast auto-dismiss
/// Timers are real and cancelled by fixture dispose in tearDown.
library;

import 'package:clide/builtin/git/src/git_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  GitController controller() {
    final c = GitController(ipc: f.ipc, events: f.services.events, messages: f.services.messages);
    addTearDown(c.dispose);
    return c;
  }

  IpcResponse ok([Map<String, Object?> data = const {}]) => IpcResponse.ok(id: '', data: data);
  IpcResponse err(String message) => IpcResponse.err(
    id: '',
    error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message),
  );

  // Let the broadcast streams (bus / events) deliver.
  Future<void> settle() => pumpEventQueue();

  group('load + status parsing', () {
    test('hydrates branch / counts / file lists from git.status', () async {
      f.ipc.stub(
        'git.status',
        (_) async => ok({
          'branch': 'main',
          'upstream': 'origin/main',
          'ahead': 2,
          'behind': 1,
          'clean': false,
          'hasConflicts': true,
          'staged': [
            {'path': 'a.dart'},
          ],
          'unstaged': [
            {'path': 'b.dart'},
          ],
          'untracked': [
            {'path': 'c.dart'},
          ],
          'conflicted': [
            {'path': 'd.dart'},
          ],
        }),
      );
      final c = controller();
      await c.load();
      expect(c.loading, isFalse);
      expect(c.branch, 'main');
      expect(c.upstream, 'origin/main');
      expect(c.ahead, 2);
      expect(c.behind, 1);
      expect(c.isClean, isFalse);
      expect(c.hasConflicts, isTrue);
      expect(c.staged.single['path'], 'a.dart');
      expect(c.unstaged.single['path'], 'b.dart');
      expect(c.untracked.single['path'], 'c.dart');
      expect(c.conflicted.single['path'], 'd.dart');
    });

    test('defaults missing fields and tolerates a non-list payload', () async {
      f.ipc.stub('git.status', (_) async => ok({'branch': 'dev', 'staged': 'not-a-list'}));
      final c = controller();
      await c.load();
      expect(c.branch, 'dev');
      expect(c.ahead, 0);
      expect(c.behind, 0);
      expect(c.isClean, isTrue);
      expect(c.hasConflicts, isFalse);
      expect(c.staged, isEmpty);
    });

    test('records an error when git.status fails', () async {
      f.ipc.stub('git.status', (_) async => err('not a repo'));
      final c = controller();
      await c.load();
      expect(c.loading, isFalse);
      expect(c.error, 'not a repo');
    });
  });

  group('staging verbs pass through ok', () {
    test('stage / stageAll / unstage / discard', () async {
      for (final cmd in ['git.stage', 'git.stage-all', 'git.unstage', 'git.discard']) {
        f.ipc.stub(cmd, (_) async => ok());
      }
      final c = controller();
      expect(await c.stage(['a']), isTrue);
      expect(await c.stageAll(), isTrue);
      expect(await c.unstage(['a']), isTrue);
      expect(await c.discard(['a']), isTrue);
    });

    test('a failing verb returns false', () async {
      f.ipc.stub('git.stage', (_) async => err('locked'));
      expect(await controller().stage(['a']), isFalse);
    });
  });

  group('commit', () {
    test('returns the new hash on success', () async {
      f.ipc.stub('git.commit', (args) async {
        expect(args['message'], 'msg');
        return ok({'hash': 'abc123'});
      });
      expect(await controller().commit('msg'), 'abc123');
    });

    test('returns null and records the error on failure', () async {
      f.ipc.stub('git.commit', (_) async => err('nothing staged'));
      final c = controller();
      expect(await c.commit('msg'), isNull);
      expect(c.error, 'nothing staged');
      c.clearError();
      expect(c.error, isNull);
    });
  });

  group('stash', () {
    test('omits the message arg when none is given', () async {
      f.ipc.stub('git.stash', (args) async {
        expect(args.containsKey('message'), isFalse);
        return ok();
      });
      expect(await controller().stash(), isTrue);
    });

    test('passes the message arg when given', () async {
      f.ipc.stub('git.stash', (args) async {
        expect(args['message'], 'wip');
        return ok();
      });
      expect(await controller().stash(message: 'wip'), isTrue);
    });
  });

  group('push / pull raise toasts on the bus', () {
    test('push success → success toast', () async {
      f.ipc.stub('git.status', (_) async => ok({'upstream': 'origin/main'}));
      f.ipc.stub('git.push', (_) async => ok());
      final c = controller();
      await c.load(); // sets _upstream so the message includes it
      expect(await c.push(), isTrue);
      await settle();
      expect(f.services.toast.entries.any((e) => e.severity == ToastSeverity.success && e.message == 'Pushed to origin/main'), isTrue);
    });

    test('push failure → error toast + error state', () async {
      f.ipc.stub('git.push', (_) async => err('rejected'));
      final c = controller();
      expect(await c.push(), isFalse);
      expect(c.error, 'rejected');
      await settle();
      expect(f.services.toast.entries.any((e) => e.severity == ToastSeverity.error && e.message.contains('rejected')), isTrue);
    });

    test('pull success + failure raise toasts', () async {
      f.ipc.stub('git.pull', (_) async => ok());
      final c = controller();
      expect(await c.pull(), isTrue);
      await settle();
      expect(f.services.toast.entries.any((e) => e.severity == ToastSeverity.success && e.message.startsWith('Pulled')), isTrue);
      f.services.toast.clear();
      f.ipc.stub('git.pull', (_) async => err('diverged'));
      expect(await c.pull(), isFalse);
      await settle();
      expect(f.services.toast.entries.any((e) => e.severity == ToastSeverity.error && e.message.contains('diverged')), isTrue);
    });
  });

  group('event-driven refresh', () {
    test('a git.changed event triggers a reload; non-git events are ignored', () async {
      var statusCalls = 0;
      f.ipc.stub('git.status', (_) async {
        statusCalls++;
        return ok({'branch': 'main'});
      });
      controller();
      f.services.events.emit(DaemonEvent(subsystem: 'pty', kind: 'output', data: const {}, ts: DateTime.utc(2026)));
      f.services.events.emit(DaemonEvent(subsystem: 'git', kind: 'git.changed', data: const {}, ts: DateTime.utc(2026)));
      await settle();
      expect(statusCalls, 1); // only the git.changed reload
    });
  });
}
