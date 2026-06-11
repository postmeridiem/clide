import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];
  bool killed = false;
  @override
  Stream<String> get lines => _ctl.stream;
  void emit(String line) => _ctl.add(line);
  @override
  void writeLine(String line) => writes.add(line);
  @override
  Future<void> kill() async => killed = true;
}

void main() {
  late List<_FakeProc> created;
  late ClaudeSessionOrchestrator orch;

  setUp(() {
    created = [];
    orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        final p = _FakeProc();
        created.add(p);
        return p;
      },
    );
  });

  SpawnSpec spec(String id, {bool visible = true}) => SpawnSpec(id: id, role: id, sessionId: '$id-uuid', cwd: '/repo', visible: visible);

  test('spawns multiple concurrent sessions, each with its own process', () async {
    await orch.spawn(spec('primary'));
    await orch.spawn(spec('teammate:tyre'));
    expect(orch.sessions, hasLength(2));
    expect(created, hasLength(2));
    expect(orch.byId('teammate:tyre')!.role, 'teammate:tyre');
  });

  test('folds the real claude session id from the init event into the session (T-185)', () async {
    final m = await orch.spawn(SpawnSpec(id: 'fork-x', role: 'teammate', sessionId: 'placeholder-uuid', cwd: '/repo', forkSourceSessionId: 'source-uuid'));
    expect(m.sessionId, 'placeholder-uuid'); // starts as the placeholder
    created.last.emit(jsonEncode({'type': 'system', 'subtype': 'init', 'session_id': 'real-fork-id', 'model': 'claude-opus-4-8', 'permissionMode': 'default'}));
    await Future<void>.delayed(Duration.zero);
    expect(m.sessionId, 'real-fork-id'); // updated to the branch's real id
  });

  test('spawn is idempotent on id — no second process', () async {
    final a = await orch.spawn(spec('primary'));
    final b = await orch.spawn(spec('primary'));
    expect(identical(a, b), isTrue);
    expect(created, hasLength(1));
  });

  // T-374: spawn() check-then-acts across awaits; without the in-flight
  // map, two CONCURRENT spawns both passed the registry check and the
  // loser's live claude process was orphaned.
  test('two concurrent spawns for one id share one session and one process (T-374)', () async {
    final (a, b) = await (orch.spawn(spec('primary')), orch.spawn(spec('primary'))).wait;
    expect(identical(a, b), isTrue);
    expect(created, hasLength(1));
  });

  test('a failed spawn clears the in-flight entry so a retry can proceed (T-374)', () async {
    var calls = 0;
    final flaky = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        calls++;
        if (calls == 1) throw StateError('spawn blew up');
        final p = _FakeProc();
        created.add(p);
        return p;
      },
    );
    await expectLater(flaky.spawn(spec('primary')), throwsStateError);
    final m = await flaky.spawn(spec('primary'));
    expect(m.id, 'primary');
    expect(calls, 2);
  });

  test('hide keeps the process alive and in the registry; show restores it', () async {
    await orch.spawn(spec('primary'));
    orch.hide('primary');
    expect(orch.byId('primary')!.visible, isFalse);
    expect(orch.visibleSessions, isEmpty);
    expect(orch.sessions, hasLength(1)); // still registered
    expect(created.single.killed, isFalse); // NOT torn down

    orch.show('primary');
    expect(orch.byId('primary')!.visible, isTrue);
    expect(orch.visibleSessions, hasLength(1));
  });

  test('close kills the process and removes the session', () async {
    await orch.spawn(spec('primary'));
    await orch.close('primary');
    expect(orch.byId('primary'), isNull);
    expect(orch.sessions, isEmpty);
    await Future<void>.delayed(Duration.zero); // session.dispose is async
    expect(created.single.killed, isTrue);
  });

  test('visibleSessions filters hidden ones', () async {
    await orch.spawn(spec('a'));
    await orch.spawn(spec('b', visible: false));
    expect(orch.visibleSessions.map((m) => m.id), ['a']);
  });

  test('notifies on spawn / hide / close', () async {
    var n = 0;
    orch.addListener(() => n++);
    await orch.spawn(spec('primary'));
    orch.hide('primary');
    await orch.close('primary');
    expect(n, 3);
  });

  test('dispose kills every session', () async {
    await orch.spawn(spec('a'));
    await orch.spawn(spec('b'));
    orch.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(created.every((p) => p.killed), isTrue);
  });

  group('team broker wiring (T-170)', () {
    SpawnSpec teamSpec(String id, String name, String role) => SpawnSpec(id: id, role: role, sessionId: '$id-uuid', cwd: '/repo', team: true, memberName: name);

    test('team sessions register in the broker; solo sessions do not', () async {
      await orch.spawn(spec('solo'));
      // The 'user' virtual member is always registered in the broker (T-180).
      final agentNames = orch.broker.members.where((m) => m.id != 'user').map((m) => m.name);
      expect(agentNames, isEmpty);
      await orch.spawn(teamSpec('primary', 'lead', 'lead'));
      final agentNamesAfter = orch.broker.members.where((m) => m.id != 'user').map((m) => m.name);
      expect(agentNamesAfter, ['lead']);
    });

    test('a message between team members is delivered into the target session stdin', () async {
      await orch.spawn(teamSpec('primary', 'lead', 'lead'));
      await orch.spawn(teamSpec('teammate:tyre', 'tyre', 'teammate'));
      orch.broker.sendMessage('primary', 'tyre', 'pick up T-9');
      await Future<void>.delayed(Duration.zero);
      final tyreProc = created[1];
      expect(tyreProc.writes.any((w) => w.contains('[team] lead: pick up T-9')), isTrue);
    });

    test('a team session declares the clide-team MCP server in its init handshake', () async {
      await orch.spawn(teamSpec('primary', 'lead', 'lead'));
      expect(created.single.writes.any((w) => w.contains('"sdkMcpServers":["clide-team"]')), isTrue);
    });

    test('closing a team member removes it from the broker roster', () async {
      await orch.spawn(teamSpec('primary', 'lead', 'lead'));
      await orch.spawn(teamSpec('teammate:tyre', 'tyre', 'teammate'));
      await orch.close('teammate:tyre');
      // 'user' is always in the broker (T-180); only agent members checked here.
      final agentNames = orch.broker.members.where((m) => m.id != 'user').map((m) => m.name);
      expect(agentNames, ['lead']);
    });
  });

  group('resume hydration', () {
    test('seeds the controller with prior items from the transcript', () async {
      final tmp = await Directory.systemTemp.createTemp('clide-resume-');
      final file = File('${tmp.path}/session.jsonl');
      await file.writeAsString(
        '{"type":"user","uuid":"u1","timestamp":"2026-05-26T00:00:00Z","isSidechain":false,"message":{"role":"user","content":"hello"}}\n'
        '{"type":"assistant","uuid":"a1","timestamp":"2026-05-26T00:00:01Z","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"hi back"}]}}\n',
      );

      final managed = await orch.spawn(
        SpawnSpec(id: 'primary', role: 'primary', sessionId: 'primary-uuid', cwd: '/repo', resume: true, transcriptPath: file.path),
      );
      final items = managed.conversation.items;
      expect(items, hasLength(2));
      expect(items.first, isA<UserMessage>());
      expect((items.first as UserMessage).text, 'hello');
      expect(items.last, isA<AssistantTextMessage>());

      await tmp.delete(recursive: true);
    });

    test('non-resume spawn does not read the transcript', () async {
      final managed = await orch.spawn(
        SpawnSpec(
          id: 'primary',
          role: 'primary',
          sessionId: 'primary-uuid',
          cwd: '/repo',
          // resume:false → transcriptPath ignored even if set
          transcriptPath: '/does/not/exist.jsonl',
        ),
      );
      expect(managed.conversation.items, isEmpty);
    });

    test('missing transcript file is tolerated (best-effort hydration)', () async {
      final managed = await orch.spawn(
        SpawnSpec(id: 'primary', role: 'primary', sessionId: 'primary-uuid', cwd: '/repo', resume: true, transcriptPath: '/does/not/exist.jsonl'),
      );
      expect(managed.conversation.items, isEmpty);
    });
  });

  // T-172: fork-into-a-pane --------------------------------------------------

  group('fork session (T-172)', () {
    List<String>? capturedArgs;

    setUp(() {
      capturedArgs = null;
      orch = ClaudeSessionOrchestrator(
        processFactory: ({required sessionArgs, required cwd, env}) async {
          capturedArgs = sessionArgs;
          return _FakeProc();
        },
      );
    });

    SpawnSpec forkSpec(String id, String sourceSessionId) =>
        SpawnSpec(id: id, role: 'fork', sessionId: '$id-placeholder', cwd: '/repo', forkSourceSessionId: sourceSessionId);

    test('fork spawn passes --resume <source> --fork-session instead of --session-id', () async {
      const sourceId = 'bbbb2222-2222-4222-8222-222222222222';
      await orch.spawn(forkSpec('fork-1', sourceId));
      expect(capturedArgs, isNotNull);
      // The Epic B bootstrap (T-215..T-217) prepends --append-system-prompt
      // + --allowedTools, so --resume <source> is no longer at index 0 — but
      // they stay adjacent and --fork-session is present, no --session-id.
      final resumeAt = capturedArgs!.indexOf('--resume');
      expect(resumeAt, greaterThanOrEqualTo(0));
      expect(capturedArgs![resumeAt + 1], sourceId);
      expect(capturedArgs!, contains('--fork-session'));
      expect(capturedArgs!, isNot(contains('--session-id')));
    });

    test('fork SpawnSpec.isFork is true when forkSourceSessionId is set', () {
      const sourceId = 'cccc3333-3333-4333-8333-333333333333';
      final s = forkSpec('fork-1', sourceId);
      expect(s.isFork, isTrue);
    });

    test('non-fork SpawnSpec.isFork is false', () {
      final s = spec('primary');
      expect(s.isFork, isFalse);
    });

    test('fork registers in the orchestrator under its own id', () async {
      const sourceId = 'dddd4444-4444-4444-8444-444444444444';
      final managed = await orch.spawn(forkSpec('fork-1', sourceId));
      expect(orch.byId('fork-1'), same(managed));
      expect(managed.isFork, isTrue);
      expect(managed.forkSourceSessionId, sourceId);
    });

    test('fork is independent from the source — source session is unaffected', () async {
      // Spawn the source session first.
      final source = await orch.spawn(spec('primary'));
      expect(orch.sessions, hasLength(1));

      // Fork it.
      await orch.spawn(forkSpec('fork-1', source.sessionId));
      // Both sessions exist; source is unchanged.
      expect(orch.sessions, hasLength(2));
      expect(orch.byId('primary'), same(source));
    });

    test('fork session appears in sessions list and is visible by default', () async {
      const sourceId = 'eeee5555-5555-4555-8555-555555555555';
      final managed = await orch.spawn(forkSpec('fork-1', sourceId));
      expect(orch.sessions.contains(managed), isTrue);
      expect(managed.visible, isTrue);
      expect(orch.visibleSessions.contains(managed), isTrue);
    });

    test('fork notifies listeners when spawned', () async {
      const sourceId = 'ffff6666-6666-4666-8666-666666666666';
      var notified = false;
      orch.addListener(() => notified = true);
      await orch.spawn(forkSpec('fork-1', sourceId));
      expect(notified, isTrue);
    });

    test('ManagedSession.cwd reflects the spec cwd', () async {
      final managed = await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'primary-uuid', cwd: '/my/project'));
      expect(managed.cwd, '/my/project');
    });
  });
}
