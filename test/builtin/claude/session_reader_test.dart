import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:test/test.dart';

/// A fake that can actually **exit**, because the alternative was inventing a
/// `debugEnd` setter on `StreamJsonSession` — and a fake able to force the end
/// state would stop proving the reader reacts to a real one. The session watches
/// `exitCode`, so completing it drives `_onExit` down the production path.
class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final _exit = Completer<int>();
  final List<String> writes = [];

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> kill() async {}

  @override
  Future<int>? get exitCode => _exit.future;

  @override
  List<String> get stderrTail => const ['boom'];

  void emit(Map<String, Object?> event) => _ctl.add(jsonEncode(event));

  /// Die, as the real process does.
  void die([int code = 1]) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

void main() {
  late _FakeProc proc;

  ClaudeSessionOrchestrator orchestrator() =>
      ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc = _FakeProc());

  Future<ManagedSession> spawn(ClaudeSessionOrchestrator orch, String id) => orch.spawn(SpawnSpec(id: id, role: id, sessionId: '$id-uuid', cwd: '/repo'));

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('binding', () {
    test('starts unattached when there is no session', () async {
      final reader = SessionReader.primary(orchestrator: orchestrator())..start();
      await settle();
      expect(reader.attached, isFalse);
      expect(reader.isBusy, isFalse, reason: 'nothing bound cannot be busy');
      reader.dispose();
    });

    test('attaches when the session appears', () async {
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      await spawn(orch, 'primary');
      await settle();
      expect(reader.attached, isTrue);
      reader.dispose();
    });

    test('follows the id it was given, not the primary one', () async {
      // The requirement that makes this epic's own bug impossible: three
      // consumers read the primary, so an interface that assumed it would pass
      // every migration and fail on Epic D's companion.
      final orch = orchestrator();
      final reader = SessionReader(sessionId: 'clide.companion', orchestrator: orch)..start();

      await spawn(orch, 'primary');
      await settle();
      expect(reader.attached, isFalse, reason: 'it bound the wrong session');

      await spawn(orch, 'clide.companion');
      await settle();
      expect(reader.attached, isTrue);
      reader.dispose();
    });

    test('notifies when the binding changes, not on every event', () async {
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      var notified = 0;
      reader.addListener(() => notified++);

      final managed = await spawn(orch, 'primary');
      await settle();
      expect(notified, 1);

      managed.session.send('hello');
      await settle();
      expect(notified, 1, reason: 'a widget should not rebuild on every token');
      reader.dispose();
    });
  });

  group('forwarding survives a respawn', () {
    test('one subscription keeps working across close and respawn', () async {
      // The whole point: consumers subscribe once and never see the
      // orchestrator. Before this, each site re-bound its own subscriptions.
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      final busy = <bool>[];
      final sub = reader.busy.listen(busy.add);

      final first = await spawn(orch, 'primary');
      await settle();
      first.session.send('one');
      await settle();
      expect(busy.last, isTrue);

      await orch.close('primary');
      await settle();
      expect(busy.last, isFalse, reason: 'a vanished session must not look busy');

      final second = await spawn(orch, 'primary');
      await settle();
      second.session.send('two');
      await settle();
      expect(busy.last, isTrue, reason: 'the subscription did not survive the respawn');

      await sub.cancel();
      reader.dispose();
    });

    test('does not double-forward after a rebind', () async {
      // A missed cancel is the failure mode every hand-written copy had to
      // guard against: the orchestrator notifies on show/hide/mute too, so this
      // happens in ordinary use.
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      final managed = await spawn(orch, 'primary');
      await settle();

      orch.hide('primary');
      orch.show('primary');
      await settle();

      final busy = <bool>[];
      final sub = reader.busy.listen(busy.add);
      await settle();
      busy.clear();

      managed.session.send('once');
      await settle();
      expect(busy, [true], reason: 'a stale subscription forwarded the same event twice');

      await sub.cancel();
      reader.dispose();
    });
  });

  group('seeding the streams that do not replay', () {
    test('a session that already died still reports its end', () async {
      // `endedStream` has no replay. Binding after the process exited would
      // otherwise wait forever for news that already passed — the session looks
      // thoughtful rather than dead (T-361). Only the pane got this right by
      // hand.
      final orch = orchestrator();
      await spawn(orch, 'primary');
      proc.die();
      await settle();

      final reader = SessionReader.primary(orchestrator: orch);
      final ends = <SessionEnd>[];
      final sub = reader.ended.listen(ends.add);
      reader.start();
      await settle();

      expect(ends, hasLength(1), reason: 'a late binder was never told the session had ended');
      expect(ends.single.reason, 'boom');
      await sub.cancel();
      reader.dispose();
    });

    test('replay-latest sources need no seeding — subscribing is the seed', () async {
      final orch = orchestrator();
      final managed = await spawn(orch, 'primary');
      managed.session.send('mid-flight');
      await settle();

      final reader = SessionReader.primary(orchestrator: orch)..start();
      await settle();
      expect(reader.isBusy, isTrue, reason: 'a reader binding mid-turn should know a turn is running');
      reader.dispose();
    });
  });

  group('the new turn signals come through', () {
    test('phase and outcome forward like everything else', () async {
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      await spawn(orch, 'primary');
      await settle();

      final phases = <TurnPhase>[];
      final outcomes = <TurnOutcome>[];
      final a = reader.phase.listen(phases.add);
      final b = reader.turnOutcomes.listen(outcomes.add);
      await settle();

      proc.emit({
        'type': 'stream_event',
        'event': {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
        },
      });
      await settle();
      proc.emit({'type': 'result', 'is_error': false, 'stop_reason': 'end_turn'});
      await settle();

      expect(phases, contains(TurnPhase.thinking));
      expect(outcomes, hasLength(1));
      await a.cancel();
      await b.cancel();
      reader.dispose();
    });
  });

  group('teardown', () {
    test('disposing stops forwarding and releases the orchestrator', () async {
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      final managed = await spawn(orch, 'primary');
      await settle();

      final busy = <bool>[];
      final sub = reader.busy.listen(busy.add);
      await settle();
      reader.dispose();
      busy.clear();

      managed.session.send('after dispose');
      await settle();
      expect(busy, isEmpty);

      // A retained orchestrator listener would fire into a disposed notifier.
      orch.hide('primary');
      await settle();
      await sub.cancel();
    });

    test('start after dispose is a no-op rather than a resurrection', () async {
      final orch = orchestrator();
      final reader = SessionReader.primary(orchestrator: orch)..start();
      reader.dispose();
      reader.start();
      await settle();
      expect(reader.attached, isFalse);
    });
  });
}
