import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

LogRecord _rec(LogLevel level, String src, String msg, {Object? error, StackTrace? stack}) =>
    LogRecord(level: level, source: src, message: msg, timestamp: DateTime.utc(2026, 6, 15, 12), error: error, stackTrace: stack);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('clide-filelog-'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File active() => File('${dir.path}${Platform.pathSeparator}clide.log');
  File archive(int i) => File('${dir.path}${Platform.pathSeparator}clide.$i.log');

  group('FileLogSink', () {
    test('appends one JSON line per record with the expected shape', () async {
      final sink = FileLogSink(dir: dir, startFlushTimer: false);
      sink(_rec(LogLevel.info, 'boot', 'hello'));
      sink(_rec(LogLevel.warn, 'pty', 'spawned', error: 'note'));
      await sink.close();

      final lines = active().readAsLinesSync();
      expect(lines, hasLength(2));

      final a = jsonDecode(lines[0]) as Map<String, Object?>;
      expect(a['lvl'], 'info');
      expect(a['src'], 'boot');
      expect(a['msg'], 'hello');
      expect(a['ts'], '2026-06-15T12:00:00.000Z');
      expect(a.containsKey('err'), isFalse);

      final b = jsonDecode(lines[1]) as Map<String, Object?>;
      expect(b['lvl'], 'warn');
      expect(b['err'], 'note');
    });

    test('encodes error + stack trace fields when present', () async {
      final sink = FileLogSink(dir: dir, startFlushTimer: false);
      final st = StackTrace.current;
      sink(_rec(LogLevel.error, 'ffi', 'boom', error: 'EBADF', stack: st));
      await sink.close();

      final rec = jsonDecode(active().readAsLinesSync().single) as Map<String, Object?>;
      expect(rec['err'], 'EBADF');
      expect(rec['stack'], st.toString());
    });

    test('creates the log directory if it does not exist', () async {
      final nested = Directory('${dir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b');
      final sink = FileLogSink(dir: nested, startFlushTimer: false);
      sink(_rec(LogLevel.info, 's', 'm'));
      await sink.close();
      expect(File('${nested.path}${Platform.pathSeparator}clide.log').existsSync(), isTrue);
    });

    test('rotates past maxBytes and caps archives at maxFiles', () async {
      // ~80-byte lines, 100-byte cap → a rotation every couple of records.
      final sink = FileLogSink(dir: dir, maxBytes: 100, maxFiles: 2, startFlushTimer: false);
      for (var i = 0; i < 6; i++) {
        sink(_rec(LogLevel.info, 's', 'msg$i'));
      }
      await sink.close();

      expect(active().existsSync(), isTrue);
      expect(archive(1).existsSync(), isTrue);
      // maxFiles=2 keeps active + .1 only — .2 must never appear.
      expect(archive(2).existsSync(), isFalse);
      // The newest record is in the active file.
      expect(active().readAsStringSync(), contains('msg5'));
    });

    test('append mode preserves an existing log across sink restarts', () async {
      final first = FileLogSink(dir: dir, startFlushTimer: false);
      first(_rec(LogLevel.info, 's', 'before'));
      await first.close();

      final second = FileLogSink(dir: dir, startFlushTimer: false);
      second(_rec(LogLevel.info, 's', 'after'));
      await second.close();

      final lines = active().readAsLinesSync();
      expect(lines, hasLength(2));
      expect((jsonDecode(lines[0]) as Map)['msg'], 'before');
      expect((jsonDecode(lines[1]) as Map)['msg'], 'after');
    });

    test('close cancels the flush timer cleanly (no pending-timer leak)', () async {
      final sink = FileLogSink(dir: dir, flushInterval: const Duration(milliseconds: 10));
      sink(_rec(LogLevel.info, 's', 'm'));
      await sink.close();
      // Reaching here without the test runner flagging a pending timer is the
      // assertion; also confirm a post-close write is a no-op, not a throw.
      sink(_rec(LogLevel.info, 's', 'after-close'));
      expect(active().readAsLinesSync(), hasLength(1));
    });

    test('activePath points at the live file', () {
      final sink = FileLogSink(dir: dir, startFlushTimer: false);
      expect(sink.activePath, active().path);
    });
  });
}
