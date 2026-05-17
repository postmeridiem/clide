/// Unit tests for the medium-sized kernel services: DialogRouter,
/// FileServices stub, OsBridge, WindowControls, SchedulerService event
/// surface.
library;

import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/files.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/kernel/src/scheduler.dart';
import 'package:clide/kernel/src/window_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DialogRouter', () {
    test('show returns a Future that completes on dismiss(value)', () async {
      final r = DialogRouter();
      final f = r.show<String>((ctx, dismiss) => const SizedBox());
      expect(r.isOpen, isTrue);
      r.dismiss('picked');
      expect(await f, 'picked');
      expect(r.isOpen, isFalse);
    });

    test('show queues additional dialogs and serves them FIFO on dismiss', () async {
      final r = DialogRouter();
      final f1 = r.show<String>((ctx, dismiss) => const SizedBox());
      final f2 = r.show<String>((ctx, dismiss) => const SizedBox());
      r.dismiss('first');
      expect(await f1, 'first');
      expect(r.isOpen, isTrue);
      r.dismiss('second');
      expect(await f2, 'second');
    });

    test('dismiss with no current dialog is a no-op', () {
      final r = DialogRouter();
      r.dismiss('nothing-to-dismiss'); // must not throw
      expect(r.isOpen, isFalse);
    });

    test('dismiss notifies listeners', () {
      final r = DialogRouter();
      var calls = 0;
      r.addListener(() => calls++);
      r.show<int>((ctx, _) => const SizedBox()); // open
      expect(calls, 1);
      r.dismiss(1); // close
      expect(calls, 2);
    });

    test('current getter exposes the active builder while open', () {
      final r = DialogRouter();
      expect(r.current, isNull);
      r.show<int>((ctx, _) => const SizedBox());
      expect(r.current, isNotNull);
      r.dismiss();
      expect(r.current, isNull);
    });

    testWidgets('DialogHost renders the child + the dialog over a backdrop', (tester) async {
      final r = DialogRouter();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: DialogHost(
          router: r,
          child: const ColoredBox(color: Color(0xFF111111), child: SizedBox.expand()),
        ),
      ));
      await tester.pump();
      // No dialog open yet — backdrop + modal not present.
      expect(find.byType(GestureDetector), findsNothing);
      // Open one.
      final future = r.show<String>((ctx, dismiss) {
        return GestureDetector(
          onTap: () => dismiss('inner'),
          child: const SizedBox(width: 100, height: 100),
        );
      });
      await tester.pump();
      // Backdrop + inner-wrapper + my own each add a GestureDetector.
      expect(find.byType(GestureDetector), findsAtLeast(2));
      // Dismiss programmatically — the future completes with null.
      r.dismiss();
      final result = await future;
      expect(result, isNull);
      // After dismiss, no GestureDetector remains.
      await tester.pump();
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('FileServices stub', () {
    test('pickOpen / pickSave / pickDirectory all throw UnimplementedError', () async {
      final f = FileServices(DaemonBus());
      expect(() => f.pickOpen(), throwsA(isA<UnimplementedError>()));
      expect(() => f.pickSave(), throwsA(isA<UnimplementedError>()));
      expect(() => f.pickDirectory(), throwsA(isA<UnimplementedError>()));
    });

    test('notifyDropped emits a FilesDropped event with paths + slot', () async {
      final bus = DaemonBus();
      final f = FileServices(bus);
      final got = bus.on<FilesDropped>().first;
      f.notifyDropped(paths: ['/a.txt', '/b.txt'], slot: Slots.workspace);
      final e = await got.timeout(const Duration(seconds: 1));
      expect(e.paths, ['/a.txt', '/b.txt']);
      expect(e.slot, Slots.workspace);
      expect(e.subsystem, 'files');
      expect(e.kind, 'dropped');
      expect(e.payload()['slot'], Slots.workspace.value);
    });
  });

  group('OsBridge', () {
    // openURL / reveal aren't exercised end-to-end here — they spawn
    // real xdg-open / open / explorer processes, which on a desktop
    // session surface a system error dialog ("Could not read file …")
    // even when the URL is bogus. We're not in a sandbox that swallows
    // those, so the test would visibly nag the user. Coverage of the
    // command-shape branches is good enough via `fire` + the platform-
    // dispatch (left to integration tests where a real OS dispatcher
    // is wanted).

    test('fire emits an OsLifecycleEvent on the bus', () async {
      final bus = DaemonBus();
      final bridge = OsBridge(log: Logger(minLevel: LogLevel.error), events: bus);
      final got = bus.on<OsLifecycleEvent>().first;
      bridge.fire('resumed');
      final e = await got.timeout(const Duration(seconds: 1));
      expect(e.kind, 'resumed');
      expect(e.subsystem, 'os');
    });
  });

  group('WindowControls', () {
    test('setStyle flips style and notifies; same-value is a no-op', () {
      final wc = WindowControls();
      var calls = 0;
      wc.addListener(() => calls++);
      wc.setStyle(ChromeStyle.prompt);
      expect(wc.style, ChromeStyle.prompt);
      expect(calls, 1);
      wc.setStyle(ChromeStyle.prompt);
      expect(calls, 1); // unchanged
    });

    testWidgets('platform-channel methods are MissingPlugin-safe', (tester) async {
      final wc = WindowControls();
      // Pre-register a handler that throws MissingPluginException for
      // every call, exercising each method's catch clause.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async => throw MissingPluginException(),
      );
      await wc.startResize(ResizeEdge.bottomRight);
      await wc.startDrag();
      await wc.minimize();
      await wc.toggleMaximize();
      await wc.close();
      expect(await wc.isMaximized(), isFalse);
    });

    testWidgets('isMaximized returns the channel result when present', (tester) async {
      final wc = WindowControls();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('clide/window'),
        (call) async => call.method == 'isMaximized' ? true : null,
      );
      expect(await wc.isMaximized(), isTrue);
    });
  });

  group('SchedulerService — event surface', () {
    test('SchedulerTier interval values are non-zero', () {
      for (final t in SchedulerTier.values) {
        expect(t.interval.inMilliseconds, greaterThan(0));
      }
    });

    test('SchedulerTick payload encodes the tier name', () {
      const tick = SchedulerTick(tier: SchedulerTier.oneMinute);
      expect(tick.subsystem, 'scheduler');
      expect(tick.kind, 'tick');
      expect(tick.payload()['tier'], 'oneMinute');
    });

    test('start / dispose can be called without throwing', () {
      final s = SchedulerService(DaemonBus());
      s.start();
      s.dispose();
    });

    test('ProjectOpened triggers the initial-cycle ticks', () async {
      final bus = DaemonBus();
      final s = SchedulerService(bus);
      addTearDown(s.dispose);
      s.start();
      final ticks = <SchedulerTier>[];
      final sub = bus.on<SchedulerTick>().listen((e) => ticks.add(e.tier));
      addTearDown(sub.cancel);
      bus.emit(const ProjectOpened(path: '/tmp/x'));
      // The first stagger is 0 ms; pump to flush it onto the queue.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ticks, isNotEmpty);
    });

    test('ProjectClosed stops the ticker without throwing', () async {
      final bus = DaemonBus();
      final s = SchedulerService(bus);
      addTearDown(s.dispose);
      s.start();
      bus.emit(const ProjectOpened(path: '/tmp/x'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bus.emit(const ProjectClosed());
      // Smoke — no throw.
    });

    test('dispose immediately after ProjectOpened awaits the in-flight spawn (T-106)', () async {
      // Race window: ProjectOpened triggers _startTicker which calls
      // `Isolate.spawn(...)`; if dispose lands before the spawn future
      // resolves, the old code left _isolate=null and the just-spawned
      // ticker leaked forever. Now dispose awaits _isolateReady before
      // killing.
      final bus = DaemonBus();
      final s = SchedulerService(bus);
      s.start();
      bus.emit(const ProjectOpened(path: '/tmp/x'));
      // Don't wait for the spawn to settle — dispose must do that itself.
      await s.dispose();
      // No throw, no leaked isolate (test runner would flag a lingering
      // isolate by failing to exit cleanly). Reaching this line is the
      // assertion.
    });
  });
}
