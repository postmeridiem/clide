/// Crash-survivable [LogSink] (T-425).
///
/// Every other sink in clide is volatile: [stderrSink] dies with the console,
/// the [LogRing] dies with the process. The Windows freeze that motivated this
/// (a hard power-cycle, no dumps, no logs) left no evidence for exactly that
/// reason. [FileLogSink] is the durable tail: it appends each [LogRecord] as
/// one JSON line to a size-rotated file under a persistent per-platform log
/// dir, and — crucially — fsyncs the records most likely to immediately
/// precede a crash, so the last breadcrumb is on disk before the box dies.
///
/// Design choices that matter for a CRASH logger:
///   - Synchronous I/O only. No async buffering / no IOSink — a hard death
///     between an `await` and its flush would lose the tail, which is the one
///     thing this sink exists to keep.
///   - Tiered flush. `warn`/`error` and records from inherently-risky sources
///     (pty/ffi/conpty/watchdog) `flushSync` immediately. High-volume
///     `info`/`debug` write through to the OS (surviving a process crash) and
///     are fsynced on a low-frequency timer — enough to bound power-loss to a
///     couple of seconds without an fsync per line.
///   - Never throws. A disk-full / permission error must not take logging — or
///     the app — down; every operation swallows its own failure.
///
/// Flutter-free (only `dart:io`/`dart:async`/`dart:convert` + [LogRecord]) so
/// it unit-tests under `dart test` against a temp dir, and so the PTY/FFI
/// layer (also Flutter-free) can route breadcrumbs through it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log.dart';

class FileLogSink {
  FileLogSink({
    required Directory dir,
    String baseName = 'clide',
    int maxBytes = 5 * 1024 * 1024,
    int maxFiles = 5,
    Set<String> eagerSources = const {'pty', 'ffi', 'conpty', 'watchdog'},
    LogLevel eagerLevel = LogLevel.warn,
    Duration flushInterval = const Duration(seconds: 2),
    bool startFlushTimer = true,
  }) : _dir = dir,
       _baseName = baseName,
       _maxBytes = maxBytes,
       _maxFiles = maxFiles < 1 ? 1 : maxFiles,
       _eagerSources = eagerSources,
       _eagerLevel = eagerLevel {
    _open();
    if (startFlushTimer && flushInterval > Duration.zero) {
      _timer = Timer.periodic(flushInterval, (_) => _flush());
    }
  }

  final Directory _dir;
  final String _baseName;
  final int _maxBytes;
  final int _maxFiles;
  final Set<String> _eagerSources;
  final LogLevel _eagerLevel;

  RandomAccessFile? _raf;
  int _size = 0;
  bool _dirty = false;
  Timer? _timer;

  String get _sep => Platform.pathSeparator;
  File get _active => File('${_dir.path}$_sep$_baseName.log');
  File _archive(int i) => File('${_dir.path}$_sep$_baseName.$i.log');

  /// The active log file's path — handy for the caller to surface (e.g. an
  /// "open log folder" affordance) or to add to a CI artifact upload.
  String get activePath => _active.path;

  void _open() {
    try {
      _dir.createSync(recursive: true);
      final f = _active;
      _size = f.existsSync() ? f.lengthSync() : 0;
      _raf = f.openSync(mode: FileMode.append);
    } catch (_) {
      _raf = null; // a disk problem must never kill logging
    }
  }

  /// The [LogSink] entry point: `logger.addSink(fileSink.call)`.
  void call(LogRecord r) {
    if (_raf == null) return;
    try {
      final bytes = utf8.encode('${jsonEncode(_encode(r))}\n');
      // Rotate BEFORE writing when this line would push the file past the cap,
      // so the newest entries always live in the active file (and a single
      // oversized line still lands rather than spinning rotations on an empty
      // file).
      if (_size > 0 && _size + bytes.length > _maxBytes) _rotate();
      final raf = _raf;
      if (raf == null) return;
      raf.writeFromSync(bytes);
      _size += bytes.length;
      _dirty = true;
      if (r.level.index >= _eagerLevel.index || _eagerSources.contains(r.source)) {
        raf.flushSync();
        _dirty = false;
      }
    } catch (_) {
      // swallow — a logging failure must never propagate to the app
    }
  }

  Map<String, Object?> _encode(LogRecord r) => {
    'ts': r.timestamp.toIso8601String(),
    'lvl': r.level.name,
    'src': r.source,
    'msg': r.message,
    if (r.error != null) 'err': r.error.toString(),
    if (r.stackTrace != null) 'stack': r.stackTrace.toString(),
  };

  void _flush() {
    if (!_dirty) return;
    try {
      _raf?.flushSync();
      _dirty = false;
    } catch (_) {}
  }

  /// Roll `<base>.log` → `<base>.1.log`, shifting older archives up and
  /// dropping the oldest past [maxFiles]. With `maxFiles == 1` the active file
  /// is simply truncated (no archives kept).
  void _rotate() {
    try {
      _raf?.flushSync();
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
    try {
      if (_maxFiles <= 1) {
        if (_active.existsSync()) _active.deleteSync();
      } else {
        final oldest = _archive(_maxFiles - 1);
        if (oldest.existsSync()) oldest.deleteSync();
        for (var i = _maxFiles - 2; i >= 1; i--) {
          final src = _archive(i);
          if (src.existsSync()) src.renameSync(_archive(i + 1).path);
        }
        if (_active.existsSync()) _active.renameSync(_archive(1).path);
      }
    } catch (_) {}
    _size = 0;
    _open();
  }

  /// Flush + close. Call on orderly shutdown; a crash is covered by the eager
  /// fsync above, not by this.
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    try {
      _raf?.flushSync();
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
  }
}
