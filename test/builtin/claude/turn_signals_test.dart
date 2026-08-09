import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:test/test.dart';

/// Fake process so the session can be driven line by line.
class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> kill() async {}

  void emit(Map<String, Object?> event) => _ctl.add(jsonEncode(event));
}

/// Envelopes as the CLI actually emits them, copied from a real 2.1.226 capture
/// (`docs/spikes/cc-stream-json-2.1.226.md`). Hand-invented shapes are how the
/// old assumptions survived so long — these are the wire, not a guess at it.
Map<String, Object?> _blockStart(String type) => {
  'type': 'stream_event',
  'event': {
    'type': 'content_block_start',
    'index': 0,
    'content_block': type == 'thinking' ? {'type': 'thinking', 'thinking': '', 'signature': ''} : {'type': 'text', 'text': ''},
  },
};

Map<String, Object?> get _messageStop => {
  'type': 'stream_event',
  'event': {'type': 'message_stop'},
};

Map<String, Object?> _result({bool isError = false, String? stop = 'end_turn', String? terminal = 'completed', Object? apiError}) => {
  'type': 'result',
  'subtype': isError ? 'error' : 'success',
  'is_error': isError,
  'stop_reason': stop,
  'terminal_reason': terminal,
  'api_error_status': apiError,
  'total_cost_usd': 0.0345879,
};

void main() {
  late _FakeProc proc;
  late StreamJsonSession session;

  setUp(() {
    proc = _FakeProc();
    session = StreamJsonSession(proc)..start();
  });

  tearDown(() => session.dispose());

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('turn phase', () {
    test('starts idle', () {
      expect(session.phase, TurnPhase.idle);
    });

    test('a thinking block reports thinking', () async {
      // The signal that did not exist before: Haiku 4.5 opens every turn with a
      // thinking block, and clide used to see nothing until text arrived.
      proc.emit(_blockStart('thinking'));
      await settle();
      expect(session.phase, TurnPhase.thinking);
    });

    test('a text block reports answering', () async {
      proc.emit(_blockStart('text'));
      await settle();
      expect(session.phase, TurnPhase.answering);
    });

    test('thinking then answering, in the order the CLI sends them', () async {
      final seen = <TurnPhase>[];
      final sub = session.phaseStream.listen(seen.add);

      proc.emit(_blockStart('thinking'));
      await settle();
      proc.emit(_blockStart('text'));
      await settle();
      proc.emit(_result());
      await settle();
      await sub.cancel();

      expect(seen, [TurnPhase.idle, TurnPhase.thinking, TurnPhase.answering, TurnPhase.idle]);
    });

    test('replays the current phase to a late subscriber', () async {
      // Mid-turn binding is the normal case for a widget that mounts while
      // something is already running; a non-replaying signal would report idle.
      proc.emit(_blockStart('thinking'));
      await settle();
      expect(await session.phaseStream.first, TurnPhase.thinking);
    });

    test('message_stop resets it even without a result', () async {
      // An interrupt or a dropped process ends a turn without a `result`; the
      // phase must not stay stuck wherever it happened to be.
      proc.emit(_blockStart('text'));
      await settle();
      proc.emit(_messageStop);
      await settle();
      expect(session.phase, TurnPhase.idle);
    });

    test('does not re-announce an unchanged phase', () async {
      final seen = <TurnPhase>[];
      final sub = session.phaseStream.listen(seen.add);
      proc.emit(_blockStart('thinking'));
      await settle();
      proc.emit(_blockStart('thinking'));
      await settle();
      await sub.cancel();
      expect(seen, [TurnPhase.idle, TurnPhase.thinking]);
    });
  });

  group('turn outcome', () {
    test('a clean turn reports no error', () async {
      final outcomes = <TurnOutcome>[];
      final sub = session.turnOutcomes.listen(outcomes.add);
      proc.emit(_result());
      await settle();
      await sub.cancel();

      expect(outcomes, hasLength(1));
      expect(outcomes.single.isError, isFalse);
      expect(outcomes.single.stopReason, 'end_turn');
      expect(outcomes.single.terminalReason, 'completed');
      expect(outcomes.single.apiErrorStatus, isNull);
    });

    test('a failed turn carries why', () async {
      // The source the Epic B audit concluded did not exist. It is two fields on
      // an event we were already parsing for cost.
      final outcomes = <TurnOutcome>[];
      final sub = session.turnOutcomes.listen(outcomes.add);
      proc.emit(_result(isError: true, stop: null, terminal: 'error', apiError: 529));
      await settle();
      await sub.cancel();

      expect(outcomes.single.isError, isTrue);
      expect(outcomes.single.terminalReason, 'error');
      expect(outcomes.single.apiErrorStatus, 529);
    });

    test('the phase is already idle when the outcome arrives', () async {
      // A listener reacting to a failure must not find the session still
      // claiming to be answering.
      TurnPhase? phaseAtOutcome;
      final sub = session.turnOutcomes.listen((_) => phaseAtOutcome = session.phase);

      proc.emit(_blockStart('text'));
      await settle();
      proc.emit(_result(isError: true));
      await settle();
      await sub.cancel();

      expect(phaseAtOutcome, TurnPhase.idle);
    });

    test('one event per turn', () async {
      final outcomes = <TurnOutcome>[];
      final sub = session.turnOutcomes.listen(outcomes.add);
      proc.emit(_result());
      await settle();
      proc.emit(_result());
      await settle();
      await sub.cancel();
      expect(outcomes, hasLength(2), reason: 'outcomes are events, not state — each turn reports its own');
    });
  });

  group('parsing', () {
    test('tolerates a result with the fields absent', () async {
      // Older CLIs, and any future one that drops a field, must not throw.
      final outcomes = <TurnOutcome>[];
      final sub = session.turnOutcomes.listen(outcomes.add);
      proc.emit({'type': 'result', 'subtype': 'success'});
      await settle();
      await sub.cancel();

      expect(outcomes.single.isError, isFalse);
      expect(outcomes.single.stopReason, isNull);
      expect(outcomes.single.terminalReason, isNull);
    });

    test('ignores a content_block_start of an unknown type', () async {
      proc.emit({
        'type': 'stream_event',
        'event': {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'tool_use'},
        },
      });
      await settle();
      expect(session.phase, TurnPhase.idle, reason: 'only thinking and text are phases');
    });
  });
}
