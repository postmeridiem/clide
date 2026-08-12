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

  group('turn usage (T-556)', () {
    // Numbers below are the real ones from the two-turn probe recorded in the
    // spike (§9). Using the measured pair rather than round invented figures is
    // the point: it is what proves the cost is differenced and not summed.
    Map<String, Object?> resultWithUsage({
      required int input,
      required int output,
      required int cacheWrite,
      required int cacheRead,
      required double cumulativeCost,
    }) => {
      'type': 'result',
      'subtype': 'success',
      'is_error': false,
      'total_cost_usd': cumulativeCost,
      'usage': {'input_tokens': input, 'output_tokens': output, 'cache_creation_input_tokens': cacheWrite, 'cache_read_input_tokens': cacheRead},
    };

    Map<String, Object?> messageDelta(int thinking) => {
      'type': 'stream_event',
      'event': {
        'type': 'message_delta',
        'usage': {
          'output_tokens': 103,
          'output_tokens_details': {'thinking_tokens': thinking},
        },
      },
    };

    test('a turn reports its own split, with thinking from the message_delta', () async {
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);

      proc.emit(messageDelta(96));
      await settle();
      proc.emit(resultWithUsage(input: 10, output: 103, cacheWrite: 16440, cacheRead: 19021, cumulativeCost: 0.0353071));
      await settle();
      await sub.cancel();

      expect(seen, hasLength(1));
      final u = seen.single;
      expect(u.inputTokens, 10);
      expect(u.outputTokens, 103);
      expect(u.cacheCreationTokens, 16440);
      expect(u.cacheReadTokens, 19021);
      // Not on the result event at all — only the message_delta carries it.
      expect(u.thinkingTokens, 96);
      expect(u.spokenTokens, 7, reason: '96 of 103 output tokens went on thinking');
      expect(u.costUsd, closeTo(0.0353071, 1e-9));
    });

    test('cost is differenced, because total_cost_usd is cumulative', () async {
      // The measured pair. A session that summed these would report $0.075 for
      // two turns that actually cost $0.039.
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);

      proc.emit(resultWithUsage(input: 10, output: 103, cacheWrite: 16440, cacheRead: 19021, cumulativeCost: 0.0353071));
      await settle();
      proc.emit(resultWithUsage(input: 10, output: 44, cacheWrite: 146, cacheRead: 35461, cumulativeCost: 0.0393752));
      await settle();
      await sub.cancel();

      expect(seen, hasLength(2));
      expect(seen.first.costUsd, closeTo(0.0353071, 1e-9), reason: 'first turn pays the session start');
      expect(seen.last.costUsd, closeTo(0.0040681, 1e-9), reason: 'steady-state comment, not another full session start');
      expect(seen.first.costUsd + seen.last.costUsd, closeTo(0.0393752, 1e-9), reason: 'the deltas must re-sum to the cumulative figure');
    });

    test('thinking does not leak from one turn into the next', () async {
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);

      proc.emit(messageDelta(96));
      await settle();
      proc.emit(resultWithUsage(input: 10, output: 103, cacheWrite: 16440, cacheRead: 19021, cumulativeCost: 0.0353071));
      await settle();
      proc.emit(resultWithUsage(input: 10, output: 44, cacheWrite: 146, cacheRead: 35461, cumulativeCost: 0.0393752));
      await settle();
      await sub.cancel();

      expect(seen.first.thinkingTokens, 96);
      expect(seen.last.thinkingTokens, 0, reason: 'the bank is emptied at each turn boundary');
    });

    test('several message_deltas in one turn accumulate', () async {
      // A turn with more than one assistant message — each delta carries its own
      // message's count, so they add rather than overwrite.
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);

      proc.emit(messageDelta(96));
      await settle();
      proc.emit(messageDelta(37));
      await settle();
      proc.emit(resultWithUsage(input: 10, output: 147, cacheWrite: 0, cacheRead: 100, cumulativeCost: 0.01));
      await settle();
      await sub.cancel();

      expect(seen.single.thinkingTokens, 133);
    });

    test('a failed turn still reports what it spent', () async {
      // A turn that errored spent its tokens. A ledger that only counted
      // successes would understate exactly when it matters most.
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);
      proc.emit({
        'type': 'result',
        'subtype': 'error',
        'is_error': true,
        'total_cost_usd': 0.002,
        'usage': {'input_tokens': 5, 'output_tokens': 2, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 90},
      });
      await settle();
      await sub.cancel();

      expect(seen.single.totalTokens, 97);
      expect(seen.single.costUsd, closeTo(0.002, 1e-9));
    });

    test('a result carrying no usage reports nothing', () async {
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);
      proc.emit({'type': 'result', 'subtype': 'success'});
      await settle();
      await sub.cancel();
      expect(seen, isEmpty, reason: 'an empty ledger entry is noise, not data');
    });

    test('a cost that goes backwards is treated as a fresh count, never negative', () async {
      // Defensive: a replaced session or a reset counter must not subtract from
      // the running total.
      final seen = <TurnUsage>[];
      final sub = session.turnUsage.listen(seen.add);
      proc.emit(resultWithUsage(input: 1, output: 1, cacheWrite: 0, cacheRead: 0, cumulativeCost: 0.05));
      await settle();
      proc.emit(resultWithUsage(input: 1, output: 1, cacheWrite: 0, cacheRead: 0, cumulativeCost: 0.01));
      await settle();
      await sub.cancel();

      expect(seen.last.costUsd, closeTo(0.01, 1e-9));
      expect(seen.every((u) => u.costUsd >= 0), isTrue);
    });

    test('adding deltas sums every field', () {
      const a = TurnUsage(inputTokens: 1, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, thinkingTokens: 1, costUsd: 0.5);
      const b = TurnUsage(inputTokens: 10, outputTokens: 20, cacheCreationTokens: 30, cacheReadTokens: 40, thinkingTokens: 10, costUsd: 0.25);
      final sum = a + b;
      expect(sum.inputTokens, 11);
      expect(sum.outputTokens, 22);
      expect(sum.cacheCreationTokens, 33);
      expect(sum.cacheReadTokens, 44);
      expect(sum.thinkingTokens, 11);
      expect(sum.costUsd, closeTo(0.75, 1e-9));
      expect(sum.totalTokens, 110);
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
