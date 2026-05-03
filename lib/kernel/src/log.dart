import 'dart:async';
import 'dart:io';

enum LogLevel { trace, debug, info, warn, error }

class LogRecord {
  LogRecord({
    required this.level,
    required this.source,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

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
    final rec = LogRecord(
      level: level,
      source: source,
      message: message,
      timestamp: DateTime.now().toUtc(),
      error: error,
      stackTrace: stackTrace,
    );
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
