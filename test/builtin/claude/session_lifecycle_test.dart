/// Session lifecycle tests for T-167 (--resume model, /clear, /resume,
/// kill-all-sessions via orchestrator).
///
/// Pure Dart (no Flutter): exercises the session argv selection, the
/// spawn-spec logic for clear vs resume, and the kill-all-sessions command
/// behaviour — all without spawning a real `claude` process.
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal fake process — same as session_orchestrator_test.dart.
// ---------------------------------------------------------------------------

class _FakeProc extends StreamJsonProcess {
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ClaudeSessionOrchestrator _orch(List<_FakeProc> created) {
  return ClaudeSessionOrchestrator(
    processFactory: ({required sessionArgs, required cwd, env}) async {
      final p = _FakeProc();
      created.add(p);
      return p;
    },
  );
}

SpawnSpec _spec(String id, {bool resume = false, String? transcriptPath, String cwd = '/repo'}) =>
    SpawnSpec(id: id, role: id, sessionId: '$id-uuid', cwd: cwd, resume: resume, transcriptPath: transcriptPath);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---- argv selection (D-77 / T-161) -------------------------------------

  group('claudeLaunchArgs — argv selection', () {
    // These mirror session_naming_test.dart but put the semantics in context.

    test('/clear → fresh session — uses --session-id', () {
      // /clear spawns a brand-new session: transcript does not exist yet.
      final args = claudeLaunchArgs('new-uuid', resume: false);
      expect(args, ['--session-id', 'new-uuid']);
    });

    test('/resume → existing session — uses --resume', () {
      // /resume picks a past session whose transcript is already on disk.
      final args = claudeLaunchArgs('past-uuid', resume: true);
      expect(args, ['--resume', 'past-uuid']);
    });

    test('restart after transcript exists → --resume preserves continuity', () {
      // On restart, the primary's transcript is on disk → resume:true.
      const id = 'stable-uuid';
      expect(claudeLaunchArgs(id, resume: true).first, '--resume');
    });

    test('secondary spawn → always --session-id (fresh)', () {
      // Secondaries always start clean: freshSessionId() + resume:false.
      final id = freshSessionId();
      expect(claudeLaunchArgs(id, resume: false).first, '--session-id');
    });
  });

  // ---- primarySessionId stability (migration safety) ----------------------

  group('primarySessionId — stable across restart', () {
    test('same repo root always yields the same UUID', () {
      const root = '/home/user/projects/myapp';
      expect(primarySessionId(root), primarySessionId(root));
    });

    test('different repos yield different UUIDs', () {
      expect(primarySessionId('/home/user/a'), isNot(primarySessionId('/home/user/b')));
    });
  });

  // ---- /clear — spawn a fresh session via orchestrator --------------------

  group('/clear — fresh session via orchestrator', () {
    late List<_FakeProc> created;
    late ClaudeSessionOrchestrator orch;

    setUp(() {
      created = [];
      orch = _orch(created);
    });

    tearDown(() => orch.dispose());

    test('spawns a new session with resume:false (empty conversation)', () async {
      final managed = await orch.spawn(_spec('primary', resume: false));
      expect(managed.id, 'primary');
      expect(managed.conversation.items, isEmpty);
      expect(created, hasLength(1));
      // The process receives --session-id (not --resume) in its init args.
      // The factory was given the right spec; verify the session is new.
      expect(managed.sessionId, 'primary-uuid');
    });

    test('close old + spawn new resets the session (clear flow)', () async {
      await orch.spawn(_spec('primary', resume: false));
      // /clear: close the current session and spawn a fresh one.
      await orch.close('primary');
      expect(orch.byId('primary'), isNull);
      expect(created.first.killed, isTrue);

      await orch.spawn(_spec('primary', resume: false));
      expect(orch.sessions, hasLength(1));
      expect(created, hasLength(2)); // a second process was created
    });
  });

  // ---- in-place workspace switch (T-269) ---------------------------------

  group('spawn — cwd-aware idempotency (T-269)', () {
    late List<_FakeProc> created;
    late ClaudeSessionOrchestrator orch;

    setUp(() {
      created = [];
      orch = _orch(created);
    });

    tearDown(() => orch.dispose());

    test('same id + same cwd reuses the session (no second process)', () async {
      final a = await orch.spawn(_spec('primary', cwd: '/repo-a'));
      final b = await orch.spawn(_spec('primary', cwd: '/repo-a'));
      expect(identical(a, b), isTrue);
      expect(created, hasLength(1));
    });

    test('same id + different cwd tears down the old session and spawns fresh', () async {
      // Workspace switched in place: the new repo must NOT inherit the old
      // repo's 'primary' session.
      final a = await orch.spawn(_spec('primary', cwd: '/repo-a'));
      final b = await orch.spawn(_spec('primary', cwd: '/repo-b'));
      expect(identical(a, b), isFalse);
      expect(b.cwd, '/repo-b');
      expect(created, hasLength(2));
      expect(created.first.killed, isTrue, reason: 'old repo session is killed');
      expect(orch.sessions, hasLength(1));
      expect(orch.byId('primary')!.cwd, '/repo-b');
    });
  });

  // ---- /resume — bind to an existing session via orchestrator -------------

  group('/resume — resume an existing session via orchestrator', () {
    late List<_FakeProc> created;
    late ClaudeSessionOrchestrator orch;

    setUp(() {
      created = [];
      orch = _orch(created);
    });

    tearDown(() => orch.dispose());

    test('spawns with resume:true and seeds conversation from transcript', () async {
      final tmp = await Directory.systemTemp.createTemp('clide-resume-');
      final file = File('${tmp.path}/session.jsonl');
      await file.writeAsString(
        '{"type":"user","uuid":"u1","timestamp":"2026-05-01T00:00:00Z","isSidechain":false,'
        '"message":{"role":"user","content":"hello from the past"}}\n',
      );

      final managed = await orch.spawn(_spec('primary', resume: true, transcriptPath: file.path));

      expect(managed.conversation.items, hasLength(1));
      await tmp.delete(recursive: true);
    });

    test('close old + spawn resumed resets to picked session (resume flow)', () async {
      await orch.spawn(_spec('primary', resume: false));
      await orch.close('primary');

      // /resume picked a past session id; re-spawn with resume:true.
      final picked = SpawnSpec(id: 'primary', role: 'primary', sessionId: 'picked-past-uuid', cwd: '/repo', resume: true);
      final managed = await orch.spawn(picked);
      expect(managed.sessionId, 'picked-past-uuid');
      expect(created, hasLength(2));
    });
  });

  // ---- claude.kill-all-sessions via orchestrator --------------------------

  group('claude.kill-all-sessions via orchestrator (T-167)', () {
    late List<_FakeProc> created;
    late ClaudeSessionOrchestrator orch;

    setUp(() {
      created = [];
      orch = _orch(created);
    });

    tearDown(() => orch.dispose());

    test('kills the primary session through the orchestrator', () async {
      await orch.spawn(_spec('primary'));
      expect(orch.sessions, hasLength(1));

      final ids = orch.sessions.map((m) => m.id).toList();
      for (final id in ids) {
        await orch.close(id);
      }

      expect(orch.sessions, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(created.single.killed, isTrue);
    });

    test('kills primary + all secondaries and leaves orchestrator empty', () async {
      await orch.spawn(_spec('primary'));
      await orch.spawn(_spec('secondary-1'));
      await orch.spawn(_spec('secondary-2'));
      expect(orch.sessions, hasLength(3));

      // Simulate what _killAllSessions does in extension.dart.
      final ids = orch.sessions.map((m) => m.id).toList();
      for (final id in ids) {
        await orch.close(id);
      }

      expect(orch.sessions, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(created.every((p) => p.killed), isTrue);
    });

    test('kill-all on empty orchestrator is a no-op', () async {
      // No sessions — the loop is a no-op, no crash.
      final ids = orch.sessions.map((m) => m.id).toList();
      for (final id in ids) {
        await orch.close(id);
      }
      expect(orch.sessions, isEmpty);
      expect(created, isEmpty);
    });

    test('kill-all includes team sessions', () async {
      await orch.spawn(SpawnSpec(id: 'primary', role: 'lead', sessionId: 'primary-uuid', cwd: '/repo', team: true, memberName: 'lead'));
      await orch.spawn(SpawnSpec(id: 'teammate:tyre', role: 'teammate', sessionId: 'tyre-uuid', cwd: '/repo', team: true, memberName: 'tyre'));
      expect(orch.sessions, hasLength(2));
      // Broker has 2 agent members + 1 virtual 'user' member (T-180).
      final agentMembers = orch.broker.members.where((m) => m.id != 'user');
      expect(agentMembers, hasLength(2));

      final ids = orch.sessions.map((m) => m.id).toList();
      for (final id in ids) {
        await orch.close(id);
      }

      expect(orch.sessions, isEmpty);
      // Only the virtual 'user' member remains after closing all sessions.
      final agentMembersAfter = orch.broker.members.where((m) => m.id != 'user');
      expect(agentMembersAfter, isEmpty);
    });
  });
}
