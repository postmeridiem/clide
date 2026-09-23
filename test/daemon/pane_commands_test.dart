/// Tests for the `pane.*` command handlers.
///
/// Drives the real registry through the dispatcher — that's the
/// integration surface the CLI + Flutter app both hit. Registry-level
/// behaviour is covered more fully in `test/panes/registry_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/escalation.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/panes/view_pane.dart';
import 'package:test/test.dart';

void main() {
  if (!Platform.isLinux && !Platform.isMacOS) return;

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
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['id'], startsWith('p_'));
      expect(r.data['kind'], 'terminal');
    });

    test('pane.list shows spawned panes', () async {
      await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      await call('pane.spawn', {
        'argv': const ['/bin/cat'],
        'kind': 'claude',
      });
      final r = await call('pane.list', const {});
      final panes = (r.data['panes'] as List).cast<Map>();
      expect(panes, hasLength(2));
      expect(panes.map((p) => p['kind']), containsAll(['terminal', 'claude']));
    });

    test('pane.write accepts text or bytes_b64', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final id = spawn.data['id']! as String;

      final viaText = await call('pane.write', {'id': id, 'text': 'abc'});
      expect(viaText.ok, isTrue);
      expect(viaText.data['written'], greaterThan(0));

      final viaBase64 = await call('pane.write', {'id': id, 'bytes_b64': base64Encode(utf8.encode('def'))});
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

    test('pane.spawn rejects non-string argv entries', () async {
      final r = await call('pane.spawn', const {
        'argv': ['/bin/sh', 42],
      });
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('strings'));
    });

    test('pane.spawn rejects an unknown kind', () async {
      final r = await call('pane.spawn', const {
        'argv': ['/bin/cat'],
        'kind': 'no-such-kind',
      });
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
    });

    test('pane.spawn passes env through as strings', () async {
      final r = await call('pane.spawn', {
        'argv': const ['/bin/sh', '-c', 'env'],
        'env': const {'FOO': 'bar'},
      });
      expect(r.ok, isTrue, reason: r.error?.message);
    });

    test('pane.close requires id and validates it', () async {
      final missing = await call('pane.close', const {});
      expect(missing.ok, isFalse);
      expect(missing.error!.kind, 'user_error');
      final unknown = await call('pane.close', const {'id': 'p_404'});
      expect(unknown.ok, isFalse);
      expect(unknown.error!.kind, 'not_found');
    });

    test('pane.write requires id and validates it', () async {
      final missing = await call('pane.write', const {'text': 'x'});
      expect(missing.ok, isFalse);
      expect(missing.error!.kind, 'user_error');
    });

    test('pane.write requires bytes_b64 or text', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final id = spawn.data['id']! as String;
      final r = await call('pane.write', {'id': id});
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('bytes_b64 or text'));
    });

    test('pane.write rejects malformed base64', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final id = spawn.data['id']! as String;
      final r = await call('pane.write', {'id': id, 'bytes_b64': 'not-base64!!!'});
      expect(r.ok, isFalse);
      expect(r.error!.message, contains('base64'));
    });

    test('pane.resize requires all three of id / cols / rows', () async {
      final r = await call('pane.resize', const {'id': 'p_1'});
      expect(r.ok, isFalse);
      expect(r.error!.kind, 'user_error');
    });

    test('pane.resize on unknown id is not-found', () async {
      final r = await call('pane.resize', const {'id': 'p_404', 'cols': 80, 'rows': 24});
      expect(r.ok, isFalse);
      expect(r.error!.code, IpcExitCode.notFound);
    });

    test('pane.focus requires id and validates it', () async {
      final missing = await call('pane.focus', const {});
      expect(missing.ok, isFalse);
      expect(missing.error!.kind, 'user_error');
      final unknown = await call('pane.focus', const {'id': 'p_404'});
      expect(unknown.ok, isFalse);
      expect(unknown.error!.kind, 'not_found');
    });

    // T-232: the CLI argv shape ({positional, flags}) must reach the handlers
    // via the registered schemas' normalize, incl. numeric coercion.
    test('CLI positional id binds to pane.focus (T-232)', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final id = spawn.data['id']! as String;
      final r = await call('pane.focus', {
        'positional': [id],
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['id'], id);
    });

    test('CLI positional id/cols/rows coerce + bind to pane.resize (T-232)', () async {
      final spawn = await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final id = spawn.data['id']! as String;
      // cols/rows arrive as strings from argv; the schema coerces them to num
      // so the handler (which reads them as num) doesn't see "required".
      final r = await call('pane.resize', {
        'positional': [id, '100', '40'],
      });
      expect(r.ok, isTrue, reason: r.error?.message);
      expect(r.data['cols'], 100);
      expect(r.data['rows'], 40);
    });
  });

  // T-219 / D-83: `pane list` reflects the GUI tabs the user sees, merged
  // with the PTY panes, via an injected view-pane source.
  group('pane.list view-pane merge (T-219)', () {
    late DaemonDispatcher dispatcher;
    late PaneRegistry registry;

    setUp(() {
      registry = PaneRegistry(events: RecordingEventSink());
      dispatcher = DaemonDispatcher();
      registerPaneCommands(
        dispatcher,
        registry,
        viewPanes: () => const [
          ViewPane(id: 'claude', slot: 'workspace', title: 'Claude', active: true, visible: true),
          ViewPane(id: 'files', slot: 'sidebar', title: 'Files', active: false, visible: true),
          ViewPane(id: 'tickets.detail', slot: 'context', title: 'Ticket', active: true, visible: true, subject: 'T-244'),
        ],
      );
    });

    tearDown(() => registry.shutdown());

    Future<IpcResponse> call(String cmd, Map<String, Object?> args) => dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));

    test('lists the live UI tabs with stable ids, slot, title, focus state', () async {
      final r = await call('pane.list', const {});
      final panes = (r.data['panes'] as List).cast<Map>();
      expect(panes, hasLength(3));
      final claude = panes.firstWhere((p) => p['id'] == 'claude');
      expect(claude['source'], 'ui');
      expect(claude['kind'], 'view');
      expect(claude['slot'], 'workspace');
      expect(claude['title'], 'Claude');
      expect(claude['active'], isTrue);
      expect(panes.firstWhere((p) => p['id'] == 'files')['active'], isFalse);
    });

    test('a detail tab carries the subject it shows; others omit the key (T-246)', () async {
      final r = await call('pane.list', const {});
      final panes = (r.data['panes'] as List).cast<Map>();
      expect(panes.firstWhere((p) => p['id'] == 'tickets.detail')['subject'], 'T-244');
      expect(panes.firstWhere((p) => p['id'] == 'claude').containsKey('subject'), isFalse);
    });

    test('merges PTY panes and UI tabs in one list', () async {
      await call('pane.spawn', {
        'argv': const ['/bin/cat'],
      });
      final r = await call('pane.list', const {});
      final panes = (r.data['panes'] as List).cast<Map>();
      // one PTY pane (source absent) + three UI tabs (source: ui).
      expect(panes, hasLength(4));
      expect(panes.where((p) => p['source'] == 'ui'), hasLength(3));
      expect(panes.where((p) => p['id'].toString().startsWith('p_')), hasLength(1));
    });
  });

  // D-115: agents start allowlisted commands freely, and type into / close
  // the panes they spawned; everything else waits on the user's confirm.
  group('agent access to panes (D-115)', () {
    late DaemonDispatcher d;
    late PaneRegistry registry;
    late List<EscalationRequest> asked;
    late EscalationVerdict answer;

    setUp(() {
      asked = [];
      answer = EscalationVerdict.once;
      registry = PaneRegistry(events: RecordingEventSink());
      d = DaemonDispatcher()
        ..escalationGate = (r) async {
          asked.add(r);
          return answer;
        };
      registerPaneCommands(d, registry, agentSpawnAllow: () => const ['/bin/cat']);
    });
    tearDown(() => registry.shutdown());

    Future<IpcResponse> call(String cmd, Map<String, Object?> args, {String? agent}) => runZoned(
      () => d.dispatch(IpcRequest(id: '1', cmd: cmd, args: args)),
      zoneValues: {callerZoneKey: agent == null ? null : CallerInfo(pid: 1, detector: _AgentIs(agent))},
    );

    Future<String> spawn({String? agent, List<String> argv = const ['/bin/cat']}) async {
      final r = await call('pane.spawn', {'argv': argv}, agent: agent);
      expect(r.ok, isTrue, reason: r.error?.message);
      return r.data['id'] as String;
    }

    test('an allowlisted spawn runs without asking; anything else asks', () async {
      await spawn(agent: 'claude:1');
      expect(asked, isEmpty);
      answer = EscalationVerdict.deny;
      final r = await call('pane.spawn', {
        'argv': ['/bin/sh', '-c', 'true'],
      }, agent: 'claude:1');
      expect(r.ok, isFalse);
      expect(asked.single.command, 'pane.spawn');
      expect(registry.panes, hasLength(1), reason: 'the denied pane never started');
    });

    test('an allowlisted argv with an env override still asks', () async {
      await call('pane.spawn', {
        'argv': ['/bin/cat'],
        'env': {'LD_PRELOAD': '/x.so'},
      }, agent: 'claude:1');
      expect(asked, hasLength(1));
    });

    test('an agent types into and closes its own pane without asking', () async {
      final id = await spawn(agent: 'claude:1');
      expect((await call('pane.write', {'id': id, 'text': 'hi\n'}, agent: 'claude:1')).ok, isTrue);
      expect((await call('pane.close', {'id': id}, agent: 'claude:1')).ok, isTrue);
      expect(asked, isEmpty);
    });

    test('typing into or closing someone else\'s pane asks', () async {
      final mine = await spawn(); // the user's, opened in the app
      final theirs = await spawn(agent: 'claude:2');
      answer = EscalationVerdict.deny;
      expect((await call('pane.write', {'id': mine, 'text': 'rm -rf .\n'}, agent: 'claude:1')).ok, isFalse);
      expect((await call('pane.write', {'id': theirs, 'text': 'x'}, agent: 'claude:1')).ok, isFalse, reason: 'another agent\'s pane');
      expect((await call('pane.close', {'id': mine}, agent: 'claude:1')).ok, isFalse);
      expect(asked.map((r) => r.command), ['pane.write', 'pane.write', 'pane.close']);
      expect(registry.panes, hasLength(2), reason: 'nothing was closed');
    });

    test('the user in the app is never asked', () async {
      final id = await spawn(argv: const ['/bin/sh', '-c', 'cat']);
      expect((await call('pane.write', {'id': id, 'text': 'x'})).ok, isTrue);
      expect((await call('pane.close', {'id': id})).ok, isTrue);
      expect(asked, isEmpty);
    });
  });
}

class _AgentIs implements AgentDetector {
  _AgentIs(this.key);
  final String key;

  @override
  Future<AgentIdentity?> agentOf(int? pid) async => AgentIdentity(key: key, label: key);
}
