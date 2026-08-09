import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/clide_companion/src/companion_channel.dart';
import 'package:clide/builtin/clide_companion/src/load_adapter.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:test/test.dart';

/// Minimal fake so the adapter can be driven without a real `claude` binary.
///
/// Busy is driven through the session's own path — `send()` raises it, a
/// `result` event clears it — rather than through a test-only setter. T-538 says
/// not to add API to `StreamJsonSession` for the companion's benefit, and that
/// applies to test seams too: a fake that can force the flag would stop proving
/// the adapter reacts to the real one.
class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> kill() async {}

  /// Push a line as though claude had written it.
  void emit(Map<String, Object?> event) => _ctl.add(jsonEncode(event));
}

void main() {
  late MessageBus bus;
  late List<Message> published;
  late StreamSubscription<Message> sub;
  late _FakeProc proc;

  ClaudeSessionOrchestrator orchestrator() =>
      ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc = _FakeProc());

  setUp(() {
    bus = MessageBus();
    published = [];
    sub = bus.subscribe(publisher: clideCompanionPublisher, channel: companionLoadChannel).listen(published.add);
  });

  tearDown(() async {
    await sub.cancel();
    bus.dispose();
  });

  /// Let the bus and the session's streams deliver — publishing is synchronous,
  /// delivery is not.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<ManagedSession> spawnPrimary(ClaudeSessionOrchestrator orch) =>
      orch.spawn(const SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));

  group('with no session', () {
    test('publishes not-busy rather than staying silent', () async {
      // No session is a normal state: clide boots without one and the strip
      // renders throughout. Silence would leave the previous session's weather
      // on screen indefinitely.
      CompanionLoadAdapter(messages: bus).start(orchestrator());
      await settle();

      expect(published, hasLength(1));
      expect(published.single.data['busy'], isFalse);
      expect(published.single.data['busySinceMs'], isNull);
    });

    test('a null orchestrator is not an error either', () async {
      CompanionLoadAdapter(messages: bus).start(null);
      await settle();
      expect(published.single.data['busy'], isFalse);
    });
  });

  group('busy edges', () {
    test('a rising edge publishes busy with a stamped start', () async {
      final at = DateTime.utc(2026, 8, 9, 12, 30);
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus, now: () => at)..start(orch);
      final managed = await spawnPrimary(orch);
      await settle();
      published.clear();

      managed.session.send('do the thing');
      await settle();

      expect(published, isNotEmpty);
      expect(published.last.data['busy'], isTrue);
      expect(published.last.data['busySinceMs'], at.millisecondsSinceEpoch, reason: 'the adapter stamps the turn start; nothing upstream records one');
      adapter.dispose();
    });

    test('a falling edge clears the start', () async {
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus)..start(orch);
      final managed = await spawnPrimary(orch);
      await settle();

      managed.session.send('do the thing');
      await settle();
      proc.emit(const {'type': 'result'});
      await settle();

      expect(published.last.data['busy'], isFalse);
      expect(published.last.data['busySinceMs'], isNull, reason: 'an idle session has no turn in progress');
      adapter.dispose();
    });

    test('the start instant survives a rebind mid-turn', () async {
      // The counter must not restart because something unrelated caused a
      // rebind — the orchestrator notifies on show/hide/mute too.
      var tick = DateTime.utc(2026, 8, 9, 12, 0);
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus, now: () => tick)..start(orch);
      final managed = await spawnPrimary(orch);
      await settle();

      managed.session.send('a long one');
      await settle();
      final started = published.last.data['busySinceMs'];
      expect(started, isNotNull);

      tick = tick.add(const Duration(minutes: 5));
      orch.hide('primary');
      orch.show('primary');
      await settle();

      final busyMessages = published.where((m) => m.data['busy'] == true).toList();
      expect(busyMessages.last.data['busySinceMs'], started, reason: 'the turn restarted its clock on a rebind');
      adapter.dispose();
    });
  });

  group('rebinding', () {
    test('does not double-subscribe', () async {
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus)..start(orch);
      final managed = await spawnPrimary(orch);
      await settle();

      orch.hide('primary');
      orch.show('primary');
      await settle();
      published.clear();

      managed.session.send('once');
      await settle();

      expect(published.where((m) => m.data['busy'] == true), hasLength(1), reason: 'a rebind left an old subscription live');
      adapter.dispose();
    });

    test('a session going away publishes not-busy', () async {
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus)..start(orch);
      final managed = await spawnPrimary(orch);
      managed.session.send('mid-turn');
      await settle();
      published.clear();

      await orch.close('primary');
      await settle();

      expect(published.last.data['busy'], isFalse, reason: 'the weather must clear when the session it described is gone');
      adapter.dispose();
    });
  });

  group('quiet by default', () {
    test('an unchanged state is not republished', () async {
      // The orchestrator notifies often. Republishing on every notification
      // would wake every companion surface for nothing.
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus)..start(orch);
      await spawnPrimary(orch);
      await settle();
      published.clear();

      orch.hide('primary');
      orch.show('primary');
      await settle();

      expect(published, isEmpty);
      adapter.dispose();
    });
  });

  group('teardown', () {
    test('disposing stops publishing', () async {
      final orch = orchestrator();
      final adapter = CompanionLoadAdapter(messages: bus)..start(orch);
      final managed = await spawnPrimary(orch);
      await settle();
      adapter.dispose();
      published.clear();

      managed.session.send('after dispose');
      await settle();
      expect(published, isEmpty);
    });
  });
}
