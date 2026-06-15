import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSampler implements ResourceSampler {
  const _FakeSampler();
  @override
  ResourceSample sample() => const ResourceSample(threads: 7, handles: 42, children: 1, rssBytes: 100 * 1024 * 1024);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('clide-wd-'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  String path() => '${dir.path}${Platform.pathSeparator}wd.log';

  group('ResourceSample', () {
    test('toJson omits unavailable (-1) fields and converts RSS to MB', () {
      expect(const ResourceSample(threads: 5, rssBytes: 2 * 1024 * 1024).toJson(), {'threads': 5, 'rssMB': 2});
      expect(const ResourceSample().toJson(), isEmpty);
      expect(const ResourceSample(handles: 9, children: 0).toJson(), {'handles': 9, 'children': 0});
    });
  });

  group('ResourceSampler.forPlatform', () {
    test('returns the POSIX sampler off Windows', () {
      if (Platform.isWindows) return;
      expect(ResourceSampler.forPlatform(), isA<PosixResourceSampler>());
    });
  });

  group('PosixResourceSampler', () {
    test('reads real /proc counts for this process', () {
      if (!Platform.isLinux) return;
      final s = PosixResourceSampler().sample();
      expect(s.threads, greaterThan(0));
      expect(s.handles, greaterThan(0)); // at least stdio fds
      expect(s.rssBytes, greaterThan(0));
      expect(s.children, greaterThanOrEqualTo(0));
    });
  });

  group('WatchdogFile', () {
    test('heartbeat + sample write tagged JSON lines', () {
      WatchdogFile(path())
        ..heartbeat()
        ..sample(const ResourceSample(threads: 12, handles: 200, children: 0, rssBytes: 50 * 1024 * 1024))
        ..close();

      final lines = File(path()).readAsLinesSync();
      expect(lines, hasLength(2));
      expect((jsonDecode(lines[0]) as Map)['evt'], 'hb');
      final s = jsonDecode(lines[1]) as Map;
      expect(s['evt'], 'sample');
      expect(s['threads'], 12);
      expect(s['rssMB'], 50);
      expect(s['pid'], isA<int>());
    });

    test('null path → disabled, writes are no-ops', () {
      final f = WatchdogFile(null);
      expect(f.enabled, isFalse);
      f
        ..heartbeat()
        ..sample(const ResourceSample())
        ..close();
    });

    test('bounded by the size cap', () {
      final f = WatchdogFile(path(), capBytes: 200);
      for (var i = 0; i < 100; i++) {
        f.heartbeat();
      }
      f.close();
      expect(File(path()).lengthSync(), lessThan(400));
    });
  });

  group('runWatchdog', () {
    test('emits an immediate heartbeat + sample on the first tick', () {
      runWatchdog(WatchdogFile(path()), const _FakeSampler(), hbIntervalMs: 0, sampleIntervalMs: 0, maxTicks: 1);

      final lines = File(path()).readAsLinesSync();
      expect(lines, hasLength(2));
      expect((jsonDecode(lines[0]) as Map)['evt'], 'hb');
      final s = jsonDecode(lines[1]) as Map;
      expect(s['evt'], 'sample');
      expect(s['threads'], 7);
      expect(s['handles'], 42);
      expect(s['children'], 1);
      expect(s['rssMB'], 100);
    });

    test('is a no-op when the file is disabled', () {
      expect(() => runWatchdog(WatchdogFile(null), const _FakeSampler(), hbIntervalMs: 0, sampleIntervalMs: 0, maxTicks: 5), returnsNormally);
    });
  });
}
