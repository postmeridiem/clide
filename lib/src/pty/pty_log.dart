/// Breadcrumb logging for the PTY backends (T-434, under the T-425 epic).
///
/// The Windows freeze hypothesis is a wedged FFI call — a reader isolate
/// blocked forever in `ReadFile`, a waiter stuck in `WaitForSingleObject`,
/// `Isolate.kill` unable to interrupt either (dart-lang/sdk#46680). To NAME
/// the wedge after a power-cycle, each backend drops a breadcrumb before and
/// after every risky syscall. There are two delivery paths because the
/// reader/waiter run in SPAWNED isolates that cannot see the main isolate's
/// [Logger] — only sendable values cross `Isolate.spawn`:
///
///   - Main isolate → [PtyLog.crumb], a callback the kernel wires to its
///     Logger (source `pty`/`conpty`, an eager FileLogSink source, so each
///     crumb is fsynced).
///   - Spawned isolates → [IsolateCrumbFile], opened from a plain file path
///     (sendable) so the isolate writes with its OWN append handle and
///     flushSync per line. That is the whole point: a reader wedged in
///     `ReadFile` leaves its last "ReadFile enter" crumb on disk even though
///     the main isolate (and its Logger) may be frozen too.
///
/// Default is fully no-op: callers that pass nothing ([PtyLog.none]) get
/// exactly today's behaviour and zero I/O. Everything swallows its own errors
/// — a logging failure must never perturb the PTY it is observing.
library;

import 'dart:convert';
import 'dart:io';

/// Main-isolate breadcrumb hook handed to a PTY backend.
class PtyLog {
  const PtyLog({this.onCrumb, this.crumbPath, this.verbose = false});

  /// Called on the main isolate for each lifecycle/syscall breadcrumb. The
  /// kernel wires this to `(m) => logger.trace('pty', m)`.
  final void Function(String message)? onCrumb;

  /// File path the SPAWNED reader/waiter isolates open for their own crumbs.
  /// A String (not a closure/Logger) so it survives `Isolate.spawn`. Null
  /// disables isolate crumbs.
  final String? crumbPath;

  /// When true, the high-frequency per-syscall crumbs fire too (debug/trace
  /// level). When false, only low-frequency lifecycle crumbs are written, so
  /// production wiring stays cheap.
  final bool verbose;

  /// The no-op default — zero I/O, today's behaviour.
  static const none = PtyLog();

  /// Emit a main-isolate breadcrumb. Never throws.
  void crumb(String message) {
    final cb = onCrumb;
    if (cb == null) return;
    try {
      cb(message);
    } catch (_) {}
  }
}

/// An append-only breadcrumb file for use INSIDE a spawned isolate, where no
/// [Logger] is reachable. Opens [path] once and flushSync per line so a wedge
/// leaves its last crumb on disk. Bounded: truncates back to empty once it
/// passes [capBytes] (we only ever need the tail before a wedge), so a chatty
/// session can't grow it without limit. Every operation swallows its own error.
class IsolateCrumbFile {
  IsolateCrumbFile(String? path, this.source, {int capBytes = 256 * 1024}) : _capBytes = capBytes {
    if (path == null) return;
    try {
      final f = File(path);
      // Create the parent dir ourselves — a standalone caller (the soak probe)
      // may point us at a dir nothing else has made yet. In the app the
      // FileLogSink already created logDirectory(), so this is a no-op there.
      f.parent.createSync(recursive: true);
      final raf = f.openSync(mode: FileMode.append);
      _raf = raf;
      _size = raf.lengthSync();
    } catch (_) {
      _raf = null; // a disk problem must never perturb the reader/waiter
    }
  }

  final String source;
  final int _capBytes;
  RandomAccessFile? _raf;
  int _size = 0;

  bool get enabled => _raf != null;

  /// Append one breadcrumb line, fsynced immediately.
  void crumb(String message) {
    final raf = _raf;
    if (raf == null) return;
    try {
      if (_size >= _capBytes) {
        // Reset to empty: truncate AND rewind. truncateSync alone leaves the
        // write position at the old high-water mark, so the next write would
        // land past the hole and the file would keep growing (sparse) instead
        // of shrinking — rewind to 0 so we actually reclaim the space.
        raf.truncateSync(0);
        raf.setPositionSync(0);
        _size = 0;
      }
      final bytes = utf8.encode('${DateTime.now().toUtc().toIso8601String()} [$source] $message\n');
      raf.writeFromSync(bytes);
      raf.flushSync();
      _size += bytes.length;
    } catch (_) {}
  }

  void close() {
    try {
      _raf?.flushSync();
      _raf?.closeSync();
    } catch (_) {}
    _raf = null;
  }
}
