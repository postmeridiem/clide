import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/session_load.dart';
import 'package:clide/builtin/clide_companion/src/strip_host.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) {}

  @override
  Future<void> kill() async {}

  /// End the turn the way the CLI does. Nothing here forces session state
  /// directly — the `result` event runs the same path production takes.
  void endTurn() => _ctl.add(jsonEncode({'type': 'result', 'is_error': false, 'stop_reason': 'end_turn'}));
}

/// The strip reads the primary session directly now (T-561) — no bus channel,
/// no adapter — so these drive a real orchestrator instead of publishing
/// messages at it. The behaviours asserted are the ones T-538/T-539 established
/// and which had to survive the collapse.
void main() {
  late KernelFixture f;
  late _FakeProc proc;

  ClaudeSessionOrchestrator orchestrator() =>
      ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc = _FakeProc());

  setUp(() async {
    f = await KernelFixture.create();
    activeSessionOrchestrator = orchestrator();
  });

  tearDown(() async {
    activeSessionOrchestrator = null;
    await f.dispose();
  });

  Future<ManagedSession> spawnPrimary() => activeSessionOrchestrator!.spawn(const SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo'));

  Widget host() => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: const MediaQuery(
          data: MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: 400,
              child: Column(
                children: [
                  Expanded(child: SizedBox()),
                  ClideStripHost(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  ClideFace face(WidgetTester tester) => tester.widget<ClideFace>(find.byType(ClideFace));

  /// Two pumps and a tick. The second pump is where the load event lands; the
  /// tick drains the conversation controller's zero-duration debounce, which a
  /// bare `pump()` schedules but does not fire.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('the weather reaches the face', () {
    testWidgets('a busy session raises the load', (tester) async {
      final managed = await spawnPrimary();
      await tester.pumpWidget(host());
      await settle(tester);

      managed.session.send('do the thing');
      await settle(tester);

      expect(face(tester).load, SessionLoad.working);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an idle session is calm, not absent', (tester) async {
      // A session that exists but is doing nothing still drips, so the surface
      // reads as alive rather than dead.
      await spawnPrimary();
      await tester.pumpWidget(host());
      await settle(tester);
      expect(face(tester).load, SessionLoad.calm);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no session at all is absent', (tester) async {
      // The behaviour the deleted adapter existed to guarantee: nothing bound
      // must not leave the previous session's weather on screen.
      await tester.pumpWidget(host());
      await settle(tester);
      expect(face(tester).load, SessionLoad.absent);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a session appearing after the strip is picked up', (tester) async {
      // The case the ask/answer handshake was invented for. The reader follows
      // the orchestrator, so mounting order no longer matters.
      await tester.pumpWidget(host());
      await settle(tester);
      expect(face(tester).load, SessionLoad.absent);

      final managed = await spawnPrimary();
      await settle(tester);
      managed.session.send('now');
      await settle(tester);

      expect(face(tester).load, SessionLoad.working, reason: 'the strip never noticed the session arrive');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the elapsed counter', () {
    testWidgets('runs from the session\'s stamp, not from when the widget noticed', (tester) async {
      // The stamp lives on the session now (T-561). A strip mounting mid-turn
      // gets the real start, where one timing it itself would report zero.
      final managed = await spawnPrimary();
      managed.session.send('started before the strip existed');
      // Real elapsed time, off the fake clock: the session stamps `busySince`
      // with a real `DateTime.now()`, so a fake-clock advance would not move it.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

      await tester.pumpWidget(host());
      await settle(tester);

      final busyFor = face(tester).busyFor;
      expect(busyFor, isNotNull, reason: 'a strip mounting mid-turn should show the turn already running');
      expect(busyFor!, greaterThan(Duration.zero));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('clears when the turn ends rather than freezing', (tester) async {
      final managed = await spawnPrimary();
      await tester.pumpWidget(host());
      await settle(tester);

      managed.session.send('a turn');
      await settle(tester);
      expect(face(tester).busyFor, isNotNull);

      proc.endTurn();
      await settle(tester);
      expect(face(tester).busyFor, isNull, reason: 'a counter left on screen reads as a turn still running');
      expect(face(tester).load, SessionLoad.calm);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('no bus involvement', () {
    testWidgets('the strip publishes nothing to read the session', (tester) async {
      // The collapse's point: load never spanned surfaces, so it should not
      // touch the bus at all now.
      final seen = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'clide.companion').listen(seen.add);
      addTearDown(sub.cancel);

      final managed = await spawnPrimary();
      await tester.pumpWidget(host());
      await settle(tester);
      managed.session.send('work');
      await settle(tester);

      expect(seen.where((m) => m.channel.startsWith('companion.load')), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
