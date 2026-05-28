import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProc implements StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];
  bool killed = false;
  @override
  Stream<String> get lines => _ctl.stream;
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
    orch = ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async {
      final p = _FakeProc();
      created.add(p);
      return p;
    });
  });

  SpawnSpec spec(String id, {bool visible = true}) => SpawnSpec(id: id, role: id, sessionId: '$id-uuid', cwd: '/repo', visible: visible);

  test('spawns multiple concurrent sessions, each with its own process', () async {
    await orch.spawn(spec('primary'));
    await orch.spawn(spec('teammate:tyre'));
    expect(orch.sessions, hasLength(2));
    expect(created, hasLength(2));
    expect(orch.byId('teammate:tyre')!.role, 'teammate:tyre');
  });

  test('spawn is idempotent on id — no second process', () async {
    final a = await orch.spawn(spec('primary'));
    final b = await orch.spawn(spec('primary'));
    expect(identical(a, b), isTrue);
    expect(created, hasLength(1));
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
      expect(orch.broker.members, isEmpty);
      await orch.spawn(teamSpec('primary', 'lead', 'lead'));
      expect(orch.broker.members.map((m) => m.name), ['lead']);
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
      expect(orch.broker.members.map((m) => m.name), ['lead']);
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

      final managed = await orch.spawn(SpawnSpec(
        id: 'primary',
        role: 'primary',
        sessionId: 'primary-uuid',
        cwd: '/repo',
        resume: true,
        transcriptPath: file.path,
      ));
      final items = managed.conversation.items;
      expect(items, hasLength(2));
      expect(items.first, isA<UserMessage>());
      expect((items.first as UserMessage).text, 'hello');
      expect(items.last, isA<AssistantTextMessage>());

      await tmp.delete(recursive: true);
    });

    test('non-resume spawn does not read the transcript', () async {
      final managed = await orch.spawn(SpawnSpec(
        id: 'primary',
        role: 'primary',
        sessionId: 'primary-uuid',
        cwd: '/repo',
        // resume:false → transcriptPath ignored even if set
        transcriptPath: '/does/not/exist.jsonl',
      ));
      expect(managed.conversation.items, isEmpty);
    });

    test('missing transcript file is tolerated (best-effort hydration)', () async {
      final managed = await orch.spawn(SpawnSpec(
        id: 'primary',
        role: 'primary',
        sessionId: 'primary-uuid',
        cwd: '/repo',
        resume: true,
        transcriptPath: '/does/not/exist.jsonl',
      ));
      expect(managed.conversation.items, isEmpty);
    });
  });
}
