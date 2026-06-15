import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logger', () {
    test('respects minLevel — lower-level messages drop silently', () {
      final out = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.warn, sinks: [out.add]);
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
      final log = Logger(minLevel: LogLevel.info, sinks: [(_) => throw StateError('bad sink'), good.add]);
      log.info('s', 'still delivered');
      expect(good, hasLength(1));
    });

    test('records stream for subscribers', () async {
      final log = Logger(minLevel: LogLevel.info);
      final out = <LogRecord>[];
      final sub = log.records.listen(out.add);
      log.info('s', 'm1');
      log.info('s', 'm2');
      await pumpEventQueue();
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

    test('trace records emit at minLevel.trace + are filtered above it', () {
      final got = <LogRecord>[];
      final log = Logger(minLevel: LogLevel.trace, sinks: [got.add]);
      log.trace('s', 'low-level detail');
      expect(got, hasLength(1));
      expect(got.first.level, LogLevel.trace);
      // Same call at info-level is filtered.
      got.clear();
      final filtered = Logger(minLevel: LogLevel.info, sinks: [got.add]);
      filtered.trace('s', 'still detail');
      expect(got, isEmpty);
    });
  });

  group('parseLogLevel', () {
    test('parses each level name case-insensitively, trimmed', () {
      for (final l in LogLevel.values) {
        expect(parseLogLevel(l.name), l);
        expect(parseLogLevel(l.name.toUpperCase()), l);
        expect(parseLogLevel('  ${l.name}  '), l);
      }
    });

    test('null / blank / unknown → null', () {
      expect(parseLogLevel(null), isNull);
      expect(parseLogLevel(''), isNull);
      expect(parseLogLevel('   '), isNull);
      expect(parseLogLevel('verbose'), isNull);
    });
  });

  group('resolveLogLevel (dev/prod verbosity toggle)', () {
    test('build-mode default when no source is set: warn release / info debug', () {
      expect(resolveLogLevel(isRelease: true), LogLevel.warn);
      expect(resolveLogLevel(isRelease: false), LogLevel.info);
    });

    test('precedence: dartDefine > env > setting > default', () {
      // setting only
      expect(resolveLogLevel(isRelease: true, settingValue: 'debug'), LogLevel.debug);
      // env beats setting
      expect(resolveLogLevel(isRelease: true, envVar: 'error', settingValue: 'debug'), LogLevel.error);
      // dartDefine beats both
      expect(resolveLogLevel(isRelease: false, dartDefine: 'trace', envVar: 'error', settingValue: 'debug'), LogLevel.trace);
    });

    test('an unknown/blank higher source falls through to the next', () {
      // empty dart-define (the String.fromEnvironment default) is skipped
      expect(resolveLogLevel(isRelease: true, dartDefine: '', envVar: 'info'), LogLevel.info);
      // garbage env falls through to the setting
      expect(resolveLogLevel(isRelease: true, envVar: 'loud', settingValue: 'warn'), LogLevel.warn);
      // all invalid → build-mode default
      expect(resolveLogLevel(isRelease: false, dartDefine: 'x', envVar: 'y', settingValue: 'z'), LogLevel.info);
    });
  });
}
