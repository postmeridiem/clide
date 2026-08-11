import 'dart:async';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:test/test.dart';

class _Proc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) {}
  @override
  Future<void> kill() async {}
}

/// T-532/T-546 — [SessionProfile] decides the argv, and the companion's shape is
/// a set of measured decisions rather than preferences. These pin each one,
/// because every difference here is a behaviour someone verified against a live
/// CLI and would otherwise have to verify again.
void main() {
  late List<String> args;
  late ClaudeSessionOrchestrator orch;

  setUp(() {
    args = [];
    orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        args = sessionArgs;
        return _Proc();
      },
    );
  });

  Future<void> spawnCompanion({String brief = 'You are Clide.', String? model = 'haiku'}) => orch.spawn(
    SpawnSpec(
      id: 'clide.companion',
      role: 'companion',
      sessionId: 'c1',
      cwd: '/repo',
      visible: false,
      profile: SessionProfile.companion,
      systemPrompt: brief,
      model: model,
    ),
  );

  Future<void> spawnAgent() => orch.spawn(const SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p1', cwd: '/repo'));

  group('the companion profile', () {
    test('replaces the system prompt rather than appending to it', () async {
      // He is not a coding assistant with a personality bolted on.
      await spawnCompanion(brief: 'BRIEF');
      expect(args, containsAllInOrder(['--system-prompt', 'BRIEF']));
      expect(args, isNot(contains('--append-system-prompt')));
    });

    test('runs in safe mode', () async {
      // Verified against a live CLI: without it he reads the workspace's
      // CLAUDE.md unprompted — clide's and the parent estate's — which is a
      // larger influence on his voice than his own brief.
      await spawnCompanion();
      expect(args, contains('--safe-mode'));
    });

    test('denies every tool with a wildcard, not a list', () async {
      // A partial deny is worse than none: blocking Bash and Read pushed the
      // model to Glob, which was not on the list, and it listed the repo.
      await spawnCompanion();
      final i = args.indexOf('--disallowedTools');
      expect(i, greaterThanOrEqualTo(0));
      expect(args[i + 1], '*');
    });

    test('carries no clide context note, skills nudge or tool pre-approval', () async {
      // All three tell him he is an IDE agent with a CLI to drive, which is the
      // opposite of what he is. The allow rule would also argue with the deny.
      await spawnCompanion();
      expect(args, isNot(contains('--allowedTools')));
      expect(args.join(' '), isNot(contains('clide exposes its IDE')));
      expect(args.join(' '), isNot(contains('skills are available')));
    });

    test('takes its model as a flag, never as a control request', () async {
      // A set_model request is echoed into the conversation as a local command,
      // which put a caveat block, a `/model` line and its stdout at the head of
      // his context — above the rule forbidding him to mention such things.
      await spawnCompanion();
      expect(args, containsAllInOrder(['--model', 'haiku']));
    });

    test('still creates its own session, so it gets a transcript like any other', () async {
      await spawnCompanion();
      expect(args, containsAllInOrder(['--session-id', 'c1']));
    });

    test('a companion without a brief is refused, not launched', () async {
      // A briefless companion is a stock assistant wearing Clide's face, which
      // is worse than no companion at all.
      expect(
        () => orch.spawn(const SpawnSpec(id: 'x', role: 'companion', sessionId: 's', cwd: '/repo', profile: SessionProfile.companion)),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => orch.spawn(const SpawnSpec(id: 'y', role: 'companion', sessionId: 's', cwd: '/repo', profile: SessionProfile.companion, systemPrompt: '   ')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('the agent profile is untouched', () {
    test('still appends, still pre-approves, still has its tools', () async {
      await spawnAgent();
      expect(args, contains('--append-system-prompt'));
      expect(args, contains('--allowedTools'));
      expect(args, isNot(contains('--safe-mode')));
      expect(args, isNot(contains('--disallowedTools')));
      expect(args, isNot(contains('--system-prompt')));
    });

    test('is the default, so nothing existing changes shape by omission', () async {
      const spec = SpawnSpec(id: 'a', role: 'primary', sessionId: 's', cwd: '/repo');
      expect(spec.profile, SessionProfile.agent);
    });
  });
}
