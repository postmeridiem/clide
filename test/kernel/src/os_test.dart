import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/os.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OsBridge bridge(OsProcessRunner run) => OsBridge(log: Logger(), events: DaemonBus(), run: run);

  group('openURL', () {
    test('runs the platform open command with the url and returns true on exit 0', () async {
      final calls = <List<String>>[];
      final os = bridge((exe, args) async {
        calls.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      });
      expect(await os.openURL('https://example.com'), isTrue);
      expect(calls.single.last, 'https://example.com');
      expect(calls.single.first, isNotEmpty); // xdg-open / open / start
    });

    test('returns false on a non-zero exit', () async {
      expect(await bridge((_, _) async => ProcessResult(0, 1, '', 'nope')).openURL('x'), isFalse);
    });

    test('returns false (never throws) when the runner fails', () async {
      expect(await bridge((_, _) async => throw 'boom').openURL('x'), isFalse);
    });
  });

  group('reveal', () {
    test('runs the platform reveal command and returns true on exit 0', () async {
      final calls = <List<String>>[];
      final os = bridge((exe, args) async {
        calls.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      });
      expect(await os.reveal('/tmp/some/file.txt'), isTrue);
      expect(calls.single.first, isNotEmpty);
    });

    test('returns false (never throws) when the runner fails', () async {
      expect(await bridge((_, _) async => throw 'x').reveal('/tmp/x'), isFalse);
    });
  });

  test('fire emits an OS lifecycle event', () async {
    final bus = DaemonBus();
    final seen = <OsLifecycleEvent>[];
    final sub = bus.on<OsLifecycleEvent>().listen(seen.add);
    OsBridge(log: Logger(), events: bus).fire('resume');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.single.kind, 'resume');
    expect(seen.single.subsystem, 'os');
  });
}
