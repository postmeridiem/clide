import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:test/test.dart';

/// A fake that can exit, so the death path runs through `_onExit` rather than
/// being forced by a test-only setter on the session (see T-551).
class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final _exit = Completer<int>();

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) {}

  @override
  Future<void> kill() async {}

  @override
  Future<int>? get exitCode => _exit.future;

  @override
  List<String> get stderrTail => const ['companion died'];

  void emit(Map<String, Object?> event) => _ctl.add(jsonEncode(event));

  void die([int code = 1]) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

/// The binding contract Epic D depends on. Nothing here is about *what* the
/// companion says — the digest is T-546's and the reply seam is T-548's — only
/// that a reader can follow a session that is not the primary one, through the
/// whole life of a process.
void main() {
  late _FakeProc proc;

  ClaudeSessionOrchestrator orchestrator() =>
      ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc = _FakeProc());

  Future<ManagedSession> spawn(ClaudeSessionOrchestrator orch, String id) => orch.spawn(SpawnSpec(id: id, role: id, sessionId: '$id-uuid', cwd: '/repo'));

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('the id', () {
    test('is namespaced to clide, matching the bus publisher', () {
      // One name for one thing. The namespace is also what makes filtering
      // companion transcripts out of the /resume picker a check rather than a
      // guess (T-545).
      expect(kCompanionSessionId, 'clide.companion');
      expect(kCompanionSessionId, clideCompanionPublisher);
    });
  });

  group('it follows the companion, not the primary', () {
    test('a primary session does not attach it', () async {
      // The failure this whole epic exists to prevent, reproduced one layer up:
      // an interface that assumed "primary" would pass every other migration
      // and bind the wrong session here.
      final orch = orchestrator();
      final reader = companionSessionReader(orchestrator: orch)..start();

      await spawn(orch, 'primary');
      await settle();
      expect(reader.attached, isFalse);

      await spawn(orch, kCompanionSessionId);
      await settle();
      expect(reader.attached, isTrue);
      reader.dispose();
    });

    test('the two are independent', () async {
      // Both alive at once is the normal state once Epic D ships.
      final orch = orchestrator();
      final companion = companionSessionReader(orchestrator: orch)..start();
      await spawn(orch, 'primary');
      await spawn(orch, kCompanionSessionId);
      await settle();
      expect(companion.attached, isTrue);

      await orch.close('primary');
      await settle();
      expect(companion.attached, isTrue, reason: 'closing the primary detached the companion');
      companion.dispose();
    });
  });

  group('through the life of the process', () {
    test('spawn, death, respawn — on one subscription', () async {
      final orch = orchestrator();
      final reader = companionSessionReader(orchestrator: orch)..start();
      final ends = <SessionEnd>[];
      final endSub = reader.ended.listen(ends.add);
      final busy = <bool>[];
      final busySub = reader.busy.listen(busy.add);

      await spawn(orch, kCompanionSessionId);
      await settle();
      expect(reader.attached, isTrue);

      // Death. The companion crashing is the case that drives the face's
      // `error` state (D-107 commitment 5), so it has to arrive.
      proc.die();
      await settle();
      expect(ends, hasLength(1), reason: 'the companion died and nothing was told');
      expect(ends.single.reason, 'companion died');

      // Respawn under the same id — T-545 restarts it on /clear and on a
      // locale change (T-558).
      await orch.close(kCompanionSessionId);
      await settle();
      await spawn(orch, kCompanionSessionId);
      await settle();
      expect(reader.attached, isTrue, reason: 'the reader did not pick up the replacement');

      proc.emit({'type': 'result', 'is_error': false});
      await settle();
      expect(busy.last, isFalse);

      await endSub.cancel();
      await busySub.cancel();
      reader.dispose();
    });

    test('binding after the companion has already died still reports it', () async {
      // Ingest is paused while the strip is minimised (T-528), so a consumer
      // binding late is ordinary rather than exotic.
      final orch = orchestrator();
      await spawn(orch, kCompanionSessionId);
      proc.die();
      await settle();

      final reader = companionSessionReader(orchestrator: orch);
      final ends = <SessionEnd>[];
      final sub = reader.ended.listen(ends.add);
      reader.start();
      await settle();

      expect(ends, hasLength(1));
      await sub.cancel();
      reader.dispose();
    });
  });

  group('the signals Epic D needs arrive', () {
    test('phase distinguishes thinking from answering', () async {
      // Haiku thinks on every turn and no flag stops it (verified at 2.1.226),
      // so this is the ordinary opening of every companion reply — and the
      // honest source for `pensive` versus `speaking`.
      final orch = orchestrator();
      final reader = companionSessionReader(orchestrator: orch)..start();
      await spawn(orch, kCompanionSessionId);
      await settle();

      final phases = <TurnPhase>[];
      final sub = reader.phase.listen(phases.add);
      await settle();

      for (final kind in const ['thinking', 'text']) {
        proc.emit({
          'type': 'stream_event',
          'event': {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {'type': kind},
          },
        });
        await settle();
      }

      expect(phases, containsAllInOrder([TurnPhase.thinking, TurnPhase.answering]));
      await sub.cancel();
      reader.dispose();
    });

    test('a failed turn is reported, which is the only source for rage', () async {
      final orch = orchestrator();
      final reader = companionSessionReader(orchestrator: orch)..start();
      await spawn(orch, kCompanionSessionId);
      await settle();

      final outcomes = <TurnOutcome>[];
      final sub = reader.turnOutcomes.listen(outcomes.add);
      await settle();

      proc.emit({'type': 'result', 'is_error': true, 'terminal_reason': 'error', 'api_error_status': 529});
      await settle();

      expect(outcomes.single.isError, isTrue);
      expect(outcomes.single.apiErrorStatus, 529);
      await sub.cancel();
      reader.dispose();
    });
  });
}
