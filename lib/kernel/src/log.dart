import 'dart:async';
import 'dart:io';

enum LogLevel { trace, debug, info, warn, error }

class LogRecord {
  LogRecord({required this.level, required this.source, required this.message, required this.timestamp, this.error, this.stackTrace});

  final LogLevel level;
  final String source;
  final String message;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final lv = level.name.toUpperCase().padRight(5);
    final buf = StringBuffer('${timestamp.toIso8601String()} $lv [$source] $message');
    if (error != null) buf.write(' | error=$error');
    return buf.toString();
  }
}

typedef LogSink = void Function(LogRecord);

class Logger {
  Logger({this.minLevel = LogLevel.info, List<LogSink>? sinks}) : _sinks = List<LogSink>.from(sinks ?? <LogSink>[stderrSink]);

  LogLevel minLevel;
  final List<LogSink> _sinks;
  final StreamController<LogRecord> _stream = StreamController<LogRecord>.broadcast();

  Stream<LogRecord> get records => _stream.stream;

  void addSink(LogSink sink) => _sinks.add(sink);

  void trace(String source, String message) => _emit(LogLevel.trace, source, message);
  void debug(String source, String message) => _emit(LogLevel.debug, source, message);
  void info(String source, String message) => _emit(LogLevel.info, source, message);
  void warn(String source, String message, {Object? error}) => _emit(LogLevel.warn, source, message, error: error);
  void error(String source, String message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LogLevel.error, source, message, error: error, stackTrace: stackTrace);

  void _emit(LogLevel level, String source, String message, {Object? error, StackTrace? stackTrace}) {
    if (level.index < minLevel.index) return;
    final rec = LogRecord(level: level, source: source, message: message, timestamp: DateTime.now().toUtc(), error: error, stackTrace: stackTrace);
    for (final sink in _sinks) {
      try {
        sink(rec);
      } catch (_) {
        // a broken sink must not kill logging
      }
    }
    if (!_stream.isClosed) _stream.add(rec);
  }

  Future<void> dispose() => _stream.close();
}

void stderrSink(LogRecord r) {
  stderr.writeln(r);
  if (r.stackTrace != null) stderr.writeln(r.stackTrace);
}

/// Parse a level name (case-insensitive, trimmed) to a [LogLevel], or null if
/// it is absent/blank/unknown — so an invalid source falls through to the next
/// one in [resolveLogLevel] rather than crashing the boot.
LogLevel? parseLogLevel(String? name) {
  if (name == null) return null;
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return null;
  for (final l in LogLevel.values) {
    if (l.name == n) return l;
  }
  return null;
}

/// Resolve the effective [Logger.minLevel] at boot — the dev/prod verbosity
/// toggle (T-425). Highest precedence first:
///
///   1. `--dart-define=CLIDE_LOG=<level>` (baked into the build)
///   2. the `CLIDE_LOG` environment variable
///   3. the `app.log.level` setting
///   4. a build-mode default: `warn` in release (a shipped app stays quiet),
///      `info` in debug.
///
/// Each named source is parsed leniently; an unknown name is skipped, not
/// fatal. The build-mode flag is passed in (rather than read here) to keep
/// this Flutter-free — `main.dart` supplies `kReleaseMode`.
LogLevel resolveLogLevel({required bool isRelease, String? dartDefine, String? envVar, String? settingValue}) {
  return parseLogLevel(dartDefine) ?? parseLogLevel(envVar) ?? parseLogLevel(settingValue) ?? (isRelease ? LogLevel.warn : LogLevel.info);
}
