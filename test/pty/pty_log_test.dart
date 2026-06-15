// Unit tests for the PTY breadcrumb plumbing (T-434). Pure callback + file I/O
// (no real PTY), so this is NOT tagged `pty` — it runs in the coverage pool.
import 'dart:io';

import 'package:clide/src/pty/pty_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PtyLog', () {
    test('none is a no-op — crumb does nothing and never throws', () {
      expect(() => PtyLog.none.crumb('x'), returnsNormally);
      expect(PtyLog.none.onCrumb, isNull);
      expect(PtyLog.none.crumbPath, isNull);
      expect(PtyLog.none.verbose, isFalse);
    });

    test('crumb forwards messages to onCrumb', () {
      final got = <String>[];
      final log = PtyLog(onCrumb: got.add);
      log.crumb('a');
      log.crumb('b');
      expect(got, ['a', 'b']);
    });

    test('crumb swallows an exception thrown by onCrumb', () {
      final log = PtyLog(onCrumb: (_) => throw StateError('boom'));
      expect(() => log.crumb('x'), returnsNormally);
    });
  });

  group('IsolateCrumbFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('clide-crumb-'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    String path() => '${dir.path}${Platform.pathSeparator}crumbs.log';

    test('null path → disabled, crumb is a no-op', () {
      final c = IsolateCrumbFile(null, 'pty.reader');
      expect(c.enabled, isFalse);
      expect(() => c.crumb('x'), returnsNormally);
      c.close();
    });

    test('creates a missing parent directory (standalone soak probe case)', () {
      final nested = '${dir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b${Platform.pathSeparator}crumbs.log';
      final c = IsolateCrumbFile(nested, 'conpty.reader')..crumb('ReadFile enter');
      c.close();
      expect(File(nested).existsSync(), isTrue);
      expect(File(nested).readAsStringSync(), contains('ReadFile enter'));
    });

    test('writes one tagged, timestamped line per crumb', () {
      final c = IsolateCrumbFile(path(), 'pty.reader');
      expect(c.enabled, isTrue);
      c.crumb('ReadFile enter');
      c.crumb('ReadFile -> ok=1 n=12');
      c.close();

      final lines = File(path()).readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], contains('[pty.reader] ReadFile enter'));
      expect(lines[1], contains('[pty.reader] ReadFile -> ok=1 n=12'));
      // ISO-8601 UTC timestamp prefix.
      expect(lines[0], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
    });

    test('appends across reopen (each isolate opens its own handle)', () {
      IsolateCrumbFile(path(), 'conpty.reader')
        ..crumb('reader started')
        ..close();
      IsolateCrumbFile(path(), 'conpty.waiter')
        ..crumb('waiter started')
        ..close();

      final lines = File(path()).readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], contains('[conpty.reader] reader started'));
      expect(lines[1], contains('[conpty.waiter] waiter started'));
    });

    test('truncates back to empty past the cap, keeping the tail bounded', () {
      final c = IsolateCrumbFile(path(), 's', capBytes: 200);
      for (var i = 0; i < 50; i++) {
        c.crumb('breadcrumb line number $i with some padding');
      }
      c.crumb('LAST');
      c.close();

      final bytes = File(path()).lengthSync();
      // Bounded: cap + at most one over-cap line, never the full 50 lines.
      expect(bytes, lessThan(400));
      // The most recent crumb survived the wrap.
      expect(File(path()).readAsStringSync(), contains('LAST'));
    });

    test('close is idempotent and post-close crumbs are no-ops', () {
      final c = IsolateCrumbFile(path(), 's')..crumb('one');
      c.close();
      c.close();
      c.crumb('after-close');
      expect(File(path()).readAsLinesSync(), hasLength(1));
    });
  });
}
