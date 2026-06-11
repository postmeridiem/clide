/// Tests for the sidebar pick-up handler (T-327/T-339): a live session accepts
/// the prompt and a not-yet-started ticket advances to in_progress; with no live
/// session nothing is injected and the ticket is untouched.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/ticket_pick_up.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

class _FakeProc implements StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];
  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) => writes.add(line);
  @override
  Future<void> kill() async {}
}

void main() {
  late ClaudeSessionOrchestrator orch;
  late FakeDaemonClient ipc;
  late MessageBus messages;
  late List<Map<String, Object?>> statusCalls;
  late List<Message> changed;
  late StreamSubscription<Message> changedSub;

  setUp(() {
    orch = ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => _FakeProc());
    ipc = FakeDaemonClient(log: Logger(), events: DaemonBus());
    messages = MessageBus();
    statusCalls = [];
    ipc.stub('pql.tickets.status', (args) async {
      statusCalls.add(args);
      return IpcResponse.ok(id: '', data: const {'ok': true});
    });
    changed = [];
    changedSub = messages.subscribe(publisher: 'builtin.tickets', channel: 'changed').listen(changed.add);
  });

  tearDown(() async {
    await changedSub.cancel();
    orch.dispose();
    messages.dispose();
    ipc.dispose();
  });

  Map<String, Object?> payload({String status = 'ready'}) => {'id': 'T-9', 'prompt': 'pick this up', 'status': status};

  test('accepted: a live session injects the prompt and starts the ticket (T-339)', () async {
    await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));

    final accepted = await applyTicketPickUp(payload(), orchestrator: orch, ipc: ipc, messages: messages);
    await Future<void>.delayed(Duration.zero); // let the bus deliver 'changed'

    expect(accepted, isTrue);
    expect(statusCalls, hasLength(1));
    expect(statusCalls.single['ids'], ['T-9']);
    expect(statusCalls.single['status'], 'in_progress');
    expect(changed.single.data['id'], 'T-9');
  });

  test('no live session: nothing injected, ticket untouched (T-339)', () async {
    // Orchestrator has no sessions → quiet no-op.
    final accepted = await applyTicketPickUp(payload(), orchestrator: orch, ipc: ipc, messages: messages);
    await Future<void>.delayed(Duration.zero);

    expect(accepted, isFalse);
    expect(statusCalls, isEmpty);
    expect(changed, isEmpty);
  });

  test('already started: injects but does not move the status backwards (T-339)', () async {
    await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));

    final accepted = await applyTicketPickUp(
      payload(status: 'in_progress'),
      orchestrator: orch,
      ipc: ipc,
      messages: messages,
    );
    await Future<void>.delayed(Duration.zero);

    expect(accepted, isTrue); // prompt still delivered
    expect(statusCalls, isEmpty); // but no transition
    expect(changed, isEmpty);
  });

  test('a backlog ticket is also startable', () async {
    await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));
    await applyTicketPickUp(
      payload(status: 'backlog'),
      orchestrator: orch,
      ipc: ipc,
      messages: messages,
    );
    expect(statusCalls, hasLength(1));
  });

  test('an empty prompt is ignored entirely', () async {
    await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));
    final accepted = await applyTicketPickUp({'id': 'T-9', 'prompt': '', 'status': 'ready'}, orchestrator: orch, ipc: ipc, messages: messages);
    expect(accepted, isFalse);
    expect(statusCalls, isEmpty);
  });
}
