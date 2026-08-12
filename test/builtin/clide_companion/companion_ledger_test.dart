import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_ledger.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _Proc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) {}
  @override
  Future<void> kill() async {
    if (!_ctl.isClosed) await _ctl.close();
  }

  void emit(Map<String, Object?> ev) {
    if (!_ctl.isClosed) _ctl.add(jsonEncode(ev));
  }

  /// A completed turn. [cumulativeCost] is what the wire reports — a session
  /// running total, not this turn's cost.
  void turn({int input = 10, int output = 100, int cacheWrite = 0, int cacheRead = 1000, int thinking = 0, required double cumulativeCost}) {
    if (thinking > 0) {
      emit({
        'type': 'stream_event',
        'event': {
          'type': 'message_delta',
          'usage': {
            'output_tokens': output,
            'output_tokens_details': {'thinking_tokens': thinking},
          },
        },
      });
    }
    emit({
      'type': 'result',
      'subtype': 'success',
      'is_error': false,
      'total_cost_usd': cumulativeCost,
      'usage': {'input_tokens': input, 'output_tokens': output, 'cache_creation_input_tokens': cacheWrite, 'cache_read_input_tokens': cacheRead},
    });
  }
}

/// T-556 — what Clide has spent this run.
///
/// The interesting property is not the arithmetic; it is the *boundary*. He is
/// restarted routinely — a `/clear` on the primary, a language change, an edited
/// brief — and a total that reset with the process would answer a question
/// nobody has.
void main() {
  late ClaudeSessionOrchestrator orch;
  late CompanionLedger ledger;
  final procs = <_Proc>[];

  Future<_Proc> spawnCompanion({String sessionId = 'c1'}) async {
    await orch.spawn(
      SpawnSpec(
        id: kCompanionSessionId,
        role: 'companion',
        sessionId: sessionId,
        cwd: '/repo',
        visible: false,
        profile: SessionProfile.companion,
        systemPrompt: 'You are Clide.',
      ),
    );
    return procs.last;
  }

  setUp(() {
    procs.clear();
    orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async {
        final p = _Proc();
        procs.add(p);
        return p;
      },
    );
    ledger = CompanionLedger(
      reader: SessionReader(sessionId: kCompanionSessionId, orchestrator: orch),
    )..start();
  });

  tearDown(() {
    ledger.dispose();
    orch.dispose();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('starts empty, and says so rather than showing zeros', () {
    expect(ledger.isEmpty, isTrue);
    expect(ledger.turns, 0);
    expect(ledger.total.totalTokens, 0);
  });

  test('accumulates the split across turns', () async {
    final proc = await spawnCompanion();
    proc.turn(input: 10, output: 103, cacheWrite: 16440, cacheRead: 19021, thinking: 96, cumulativeCost: 0.0353071);
    await settle();
    proc.turn(input: 10, output: 44, cacheWrite: 146, cacheRead: 35461, thinking: 37, cumulativeCost: 0.0393752);
    await settle();

    expect(ledger.turns, 2);
    expect(ledger.total.inputTokens, 20);
    expect(ledger.total.outputTokens, 147);
    expect(ledger.total.cacheCreationTokens, 16586);
    expect(ledger.total.cacheReadTokens, 54482);
    expect(ledger.total.thinkingTokens, 133);
    // Those four figures are exactly what the same session's cumulative
    // `modelUsage` reported in the probe — the ledger and the wire agree.
    expect(ledger.total.totalTokens, 71235);
    expect(ledger.total.costUsd, closeTo(0.0393752, 1e-9), reason: 'the summed deltas equal the session cumulative');
  });

  test('thinking is a subset of output, never an addition to it', () async {
    final proc = await spawnCompanion();
    proc.turn(output: 103, thinking: 96, cumulativeCost: 0.01);
    await settle();
    expect(ledger.total.spokenTokens, 7);
    expect(ledger.total.thinkingTokens + ledger.total.spokenTokens, ledger.total.outputTokens);
  });

  test('survives his session being replaced — the run is the boundary, not the process', () async {
    final first = await spawnCompanion(sessionId: 'c1');
    first.turn(output: 100, cacheRead: 1000, cumulativeCost: 0.02);
    await settle();
    expect(ledger.turns, 1);

    // What a /clear on the primary, a locale change or an edited brief does.
    await orch.close(kCompanionSessionId);
    await settle();
    final second = await spawnCompanion(sessionId: 'c2');
    await settle();

    // The fresh process starts its own cumulative cost at zero. The ledger must
    // add to what it already had rather than following the new session down.
    second.turn(output: 50, cacheRead: 500, cumulativeCost: 0.005);
    await settle();

    expect(ledger.turns, 2, reason: 'a restart is invisible to the ledger');
    expect(ledger.total.outputTokens, 150);
    expect(ledger.total.costUsd, closeTo(0.025, 1e-9), reason: 'the restarted session adds, it does not reset');
  });

  test('notifies its listeners once per turn', () async {
    var notifications = 0;
    ledger.addListener(() => notifications++);
    final proc = await spawnCompanion();
    proc.turn(cumulativeCost: 0.01);
    await settle();
    proc.turn(cumulativeCost: 0.02);
    await settle();
    expect(notifications, 2);
  });

  test('counts a silent turn — choosing not to speak still costs', () async {
    // The trigger admits a turn, he decides there is nothing worth saying, and
    // the tokens are spent regardless. That spend is exactly what this surface
    // exists to expose.
    final proc = await spawnCompanion();
    proc.turn(output: 12, thinking: 12, cumulativeCost: 0.004);
    await settle();

    expect(ledger.turns, 1);
    expect(ledger.total.spokenTokens, 0);
    expect(ledger.total.thinkingTokens, 12);
  });
}
