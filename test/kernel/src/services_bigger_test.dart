/// Unit tests for the medium-sized kernel services: DialogRouter,
/// FileServices stub, OsBridge, WindowControls, SchedulerService event
/// surface.
library;

import 'package:clide/kernel/src/dialog.dart';
import 'package:clide/kernel/src/events/bus.dart';
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
  });
}
