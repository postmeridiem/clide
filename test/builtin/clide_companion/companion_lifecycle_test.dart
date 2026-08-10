import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_lifecycle.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final written = <String>[];
  var killed = false;

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => written.add(line);

  @override
  Future<void> kill() async {
    killed = true;
    if (!_ctl.isClosed) await _ctl.close();
  }

  /// Ask to use a tool, the way the CLI does over the control channel.
  void askToUseTool({String promptId = 'req-1'}) => _ctl.add(
    jsonEncode({
      'type': 'control_request',
      'request_id': promptId,
      'request': {'subtype': 'can_use_tool', 'tool_name': 'Bash', 'tool_use_id': 'tu-1', 'input': <String, Object?>{}},
    }),
  );

  /// Everything written on the control channel, decoded.
  Iterable<Map<String, Object?>> get control =>
      written.map((l) => jsonDecode(l) as Map<String, Object?>).where((m) => (m['type'] as String?)?.startsWith('control_') ?? false);
}

/// T-545 — the companion's process lifecycle. The kill switch is the load-
/// bearing case: it must drop a *running* process, not merely refuse the next
/// one, because a hidden companion still spends the primary session's quota.
void main() {
  late ClaudeSessionOrchestrator orch;
  final procs = <_FakeProc>[];
  final ids = <String>[];

  setUp(() {
    procs.clear();
    ids.clear();
    orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        final p = _FakeProc();
        procs.add(p);
        return p;
      },
    );
  });

  String nextId() {
    final id = companionSessionId();
    ids.add(id);
    return id;
  }

  CompanionSessionController controller({SessionReader? primary}) => CompanionSessionController(orchestrator: orch, newSessionId: nextId, primary: primary);

  Future<ManagedSession> spawnPrimary(String sessionId) => orch.spawn(SpawnSpec(id: kPrimarySessionId, role: 'primary', sessionId: sessionId, cwd: '/repo'));

  group('the kill switch', () {
    test('enabled with a workspace spawns exactly one session', () async {
      final c = controller();
      addTearDown(c.shutdown);

      await c.sync(enabled: true, open: true, root: '/repo');

      expect(c.running, isTrue);
      expect(procs, hasLength(1));
      expect(orch.byId(kCompanionSessionId), isNotNull);
    });

    test('disabled spawns nothing at all', () async {
      final c = controller();
      addTearDown(c.shutdown);

      await c.sync(enabled: false, open: true, root: '/repo');

      expect(c.running, isFalse);
      expect(procs, isEmpty, reason: 'a disabled companion must not start a process to then hide it');
    });

    test('turning it off tears a running process down', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');

      await c.sync(enabled: false, open: true, root: '/repo');

      expect(c.running, isFalse);
      expect(procs.single.killed, isTrue, reason: 'off must kill the process, not just stop rendering — it spends the same quota either way');
      expect(orch.byId(kCompanionSessionId), isNull);
    });

    test('turning it back on starts a fresh session, not the old one', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      await c.sync(enabled: false, open: true, root: '/repo');

      await c.sync(enabled: true, open: true, root: '/repo');

      expect(procs, hasLength(2));
      expect(ids.toSet(), hasLength(2), reason: 'off is off — coming back must not resume what was torn down');
    });

    test('no workspace means no session', () async {
      final c = controller();
      addTearDown(c.shutdown);

      await c.sync(enabled: true, open: true, root: null);

      expect(c.running, isFalse);
    });
  });

  group('minimising', () {
    test('pauses ingest and keeps the process', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      final before = c.session;

      await c.sync(enabled: true, open: false, root: '/repo');

      expect(c.ingesting, isFalse, reason: 'a minimised stretch is conversation Clide genuinely did not see');
      expect(c.running, isTrue);
      expect(identical(c.session, before), isTrue, reason: 'restoring must be instant and keep what he knew');
      expect(procs.single.killed, isFalse);
    });

    test('restoring resumes ingest without respawning', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      await c.sync(enabled: true, open: false, root: '/repo');

      await c.sync(enabled: true, open: true, root: '/repo');

      expect(c.ingesting, isTrue);
      expect(procs, hasLength(1));
    });

    test('the kill switch stops ingest too', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');

      await c.sync(enabled: false, open: true, root: '/repo');

      expect(c.ingesting, isFalse, reason: 'off is off at every level, not only the process one');
    });
  });

  group('idempotence', () {
    test('re-syncing the same state does not respawn', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      final before = c.session;

      await c.sync(enabled: true, open: true, root: '/repo');
      await c.sync(enabled: true, open: true, root: '/repo');

      expect(procs, hasLength(1), reason: 'sync runs on every settings notification, so it must compare before acting');
      expect(identical(c.session, before), isTrue);
    });

    test('a workspace switch spawns a companion for the new repo', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');

      await c.sync(enabled: true, open: true, root: '/other');

      expect(procs, hasLength(2));
      expect(c.session!.cwd, '/other');
      expect(ids.toSet(), hasLength(2), reason: 'the new repo gets its own session id, not the previous repo\'s');
    });
  });

  group('tracking the primary', () {
    test('a primary respawn restarts the companion', () async {
      // What `/clear` on the main pane looks like from here: the orchestrator
      // closes `primary` and spawns a new session under the same id. A companion
      // still holding the old conversation is a surprise the user did not ask
      // for.
      await spawnPrimary('p-1');
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      expect(procs, hasLength(2), reason: 'primary + companion');
      final before = c.session;

      await orch.close(kPrimarySessionId);
      await spawnPrimary('p-2');
      await pumpEventQueue();

      expect(identical(c.session, before), isFalse, reason: 'the companion kept the conversation the user cleared');
      expect(ids, hasLength(2), reason: 'and the replacement is a fresh session, not a resume of the old one');
    });

    test('the primary merely appearing does not restart anything', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');
      final before = c.session;

      await spawnPrimary('p-1');
      await pumpEventQueue();

      expect(identical(c.session, before), isTrue, reason: 'the first attach has nothing to restart');
      expect(ids, hasLength(1));
    });
  });

  group('the paneless session', () {
    test('runs on haiku', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');

      final setModel = procs.single.control.firstWhere((m) => (m['request'] as Map?)?['subtype'] == 'set_model');
      expect((setModel['request'] as Map)['model'], kCompanionModel);
    });

    test('refuses tool use rather than waiting for an approval that cannot come', () async {
      final c = controller();
      addTearDown(c.shutdown);
      await c.sync(enabled: true, open: true, root: '/repo');

      procs.single.askToUseTool();
      await pumpEventQueue();

      final answer = procs.single.control.firstWhere((m) => m['type'] == 'control_response');
      final response = (answer['response'] as Map)['response'] as Map;
      expect(response['behavior'], 'deny', reason: 'it spawns visible: false, so a prompt would hang the session forever');
      expect(c.session!.session.pendingPrompt, isNull, reason: 'and the queue must advance, not stay blocked on the refused one');
    });
  });

  group('shutdown', () {
    test('kills the process', () async {
      final c = controller();
      await c.sync(enabled: true, open: true, root: '/repo');

      await c.shutdown();

      expect(procs.single.killed, isTrue);
      expect(orch.byId(kCompanionSessionId), isNull);
    });

    test('is idempotent', () async {
      final c = controller();
      await c.sync(enabled: true, open: true, root: '/repo');

      await c.shutdown();
      await c.shutdown();

      expect(procs, hasLength(1));
    });
  });

  group('a failed spawn', () {
    test('is recorded and leaves the controller re-tryable', () async {
      var fail = true;
      final broken = ClaudeSessionOrchestrator(
        processFactory: ({required sessionArgs, required cwd, env}) async {
          if (fail) throw StateError('claude: not found');
          final p = _FakeProc();
          procs.add(p);
          return p;
        },
      );
      final c = CompanionSessionController(orchestrator: broken, newSessionId: nextId);
      addTearDown(c.shutdown);

      await c.sync(enabled: true, open: true, root: '/repo');
      expect(c.running, isFalse);
      expect(c.spawnError, isA<StateError>());

      fail = false;
      await c.restart();
      expect(c.running, isTrue, reason: 'one bad spawn must not wedge the queue for everything after it');
      expect(c.spawnError, isNull);
    });
  });

  group('the session-id namespace', () {
    test('a companion id is recognised and an ordinary one is not', () {
      expect(isCompanionSessionId(companionSessionId()), isTrue);
      expect(isCompanionSessionId(freshSessionId()), isFalse);
      expect(isCompanionSessionId(primarySessionId('/repo')), isFalse);
    });

    test('ids are unique and keep the UUID shape --session-id validates', () {
      final a = companionSessionId();
      final b = companionSessionId();
      expect(a, isNot(b));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(a),
        isTrue,
        reason: 'claude rejects a malformed --session-id',
      );
    });
  });
}
