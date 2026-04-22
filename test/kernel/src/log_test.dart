import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logger', () {
    test('respects minLevel — lower-level messages drop silently', () {
      final out = <LogRecord>[];
      final log = Logger(
        minLevel: LogLevel.warn,
        sinks: [out.add],
      );
      log.debug('s', 'dropped');
      log.info('s', 'dropped');
      log.warn('s', 'kept');
      log.error('s', 'kept');
      expect(out.map((r) => r.message), ['kept', 'kept']);
    });

    test('minLevel is mutable post-construction', () {
      final out = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.error, sinks: [out.add]);
      log.info('s', 'dropped');
      log.minLevel = LogLevel.info;
      log.info('s', 'kept');
      expect(out.map((r) => r.message), ['kept']);
    });

    test('error + stack trace propagate to sinks', () {
      final out = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.debug, sinks: [out.add]);
      final st = StackTrace.current;
      log.error('s', 'boom', error: 'e', stackTrace: st);
      expect(out, hasLength(1));
      expect(out.first.level, LogLevel.error);
      expect(out.first.error, 'e');
      expect(out.first.stackTrace, st);
    });

    test('broken sink does not kill the logger', () {
      final good = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.info, sinks: [
        (_) => throw StateError('bad sink'),
        good.add,
      ]);
      log.info('s', 'still delivered');
      expect(good, hasLength(1));
    });

    test('records stream for subscribers', () async {
      final log = Logger(minLevel: LogLevel.info);
      final out = <LogRecord>[];
      final sub = log.records.listen(out.add);
      log.info('s', 'm1');
      log.info('s', 'm2');
      await Future<void>.delayed(Duration.zero);
      expect(out.map((r) => r.message), ['m1', 'm2']);
      await sub.cancel();
      await log.dispose();
    });

    test('addSink appends without replacing', () {
      final a = <LogRecord>[];
      final b = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.info, sinks: [a.add]);
      log.addSink(b.add);
      log.info('s', 'hello');
      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });
  });
}
