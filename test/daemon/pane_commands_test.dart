/// Tests for the `pane.*` command handlers.
///
/// Drives the real registry through the dispatcher — that's the
/// integration surface the CLI + Flutter app both hit. Registry-level
/// behaviour is covered more fully in `test/panes/registry_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) return;

  final ptycPath = File('ptyc/bin/ptyc').existsSync()
      ? File('ptyc/bin/ptyc').absolute.path
      : 'ptyc';

  group('pane.* dispatch', () {
    late DaemonDispatcher dispatcher;
    late PaneRegistry registry;

    setUp(() {
      final sink = RecordingEventSink();
      registry = PaneRegistry(events: sink);
      dispatcher = DaemonDispatcher();
      registerPaneCommands(dispatcher, registry);
    });

    tearDown(() => registry.shutdown());

    Future<IpcResponse> call(String cmd, Map<String, Object?> args) {
      return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
    }

    test('pane.spawn requires argv', () async {
      final r = await call('pane.spawn', const {});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
      expect(r.error!.message, contains('argv'));
    });

    test('pane.spawn returns pane metadata', () async {
      final r = await call('pane.spawn', {
        'argv': const ['/bin/sh', '-c', 'sleep 0.1'],
        'kind': 'terminal',
        'ptyc_path': ptycPath,
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['id'], startsWith('p_'));
      expect(r.data['kind'], 'terminal');
    });

    test('pane.list shows spawned panes', () async {
      await call('pane.spawn', {
        'argv': const ['/bin/cat'],
        'ptyc_path': ptycPath,
      });
      await call('pane.spawn', {
        'argv': const ['/bin/cat'],
        'kind': 'claude',
        'ptyc_path': ptycPath,
      });
      final r = await call('pane.list', const {});
      final panes = (r.data['panes'] as List).cast<Map>();
      expect(panes, hasLength(2));
      expect(panes.map((p) => p['kind']), containsAll(['terminal', 'claude']));
    });

    test('pane.write accepts text or bytes_b64', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
        'ptyc_path': ptycPath,
      });
      final id = spawn.data['id']! as String;

      final viaText = await call('pane.write', {'id': id, 'text': 'abc'});
      expect(viaText.ok, isTrue);
      expect(viaText.data['written'], greaterThan(0));

      final viaBase64 = await call('pane.write', {
        'id': id,
        'bytes_b64': base64Encode(utf8.encode('def')),
      });
      expect(viaBase64.ok, isTrue);
    });

    test('pane.write on unknown id → not-found', () async {
      final r = await call('pane.write', {'id': 'p_404', 'text': 'x'});
      expect(r.ok, isFalse);
      expect(r.error!.code, IpcExitCode.notFound);
    });

    test('pane.resize + pane.close + pane.focus round-trip', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
        'ptyc_path': ptycPath,
      });
      final id = spawn.data['id']! as String;

      final r1 = await call('pane.resize', {'id': id, 'cols': 100, 'rows': 30});
      expect(r1.ok, isTrue);

      final r2 = await call('pane.focus', {'id': id});
      expect(r2.ok, isTrue);

      final r3 = await call('pane.close', {'id': id});
      expect(r3.ok, isTrue);

      final list = await call('pane.list', const {});
      expect((list.data['panes'] as List), isEmpty);
    });

    test('pane.tail ack is a no-op', () async {
      final r = await call('pane.tail', const {});
      expect(r.ok, isTrue);
      expect(r.data['subscribed'], isTrue);
    });
  });
}
