/// Crash-diagnostic watchdog (T-435, under the T-425 observability epic).
///
/// The Windows freeze leaves no evidence partly because it is a *whole-process*
/// stall: a main-isolate `Timer` heartbeat would freeze WITH the main isolate
/// and tell us nothing. So the watchdog runs in a DEDICATED isolate that:
///
///   - appends + fsyncs a heartbeat every ~500ms, so the last heartbeat on disk
///     bounds a freeze to ~500ms ("it was alive at T, dead by T+0.5s"); and
///   - every ~2s samples this process's resource counts — threads, open
///     handles/fds, child/ConPTY-host processes, RSS — and appends + fsyncs
///     them. A monotonically climbing child/thread/handle count is the leak
///     signature the soak couldn't reproduce on CI but a real freeze would show.
///
/// Output is JSON-lines in `logDirectory()/clide-watchdog.log`, matching
/// [FileLogSink] so it greps/parses the same way, bounded by the same
/// truncate-on-cap scheme as [IsolateCrumbFile]. Everything is synchronous and
/// swallows its own errors — the watchdog must never add a second hang or take
/// the app down.
///
/// Flutter-free (dart:io / dart:isolate / dart:convert + a thin FFI sampler on
/// Windows) so the entry point is `Isolate.spawn`-able and it unit-tests under
/// `dart test`.
library;

import 'dart:convert';
import 'dart:io';

import 'watchdog_windows.dart';

/// One resource sample of the current process. A field of `-1` means "not
/// available on this platform or the probe failed" — never an error.
class ResourceSample {
  const ResourceSample({this.threads = -1, this.handles = -1, this.children = -1, this.rssBytes = -1});

  /// Live OS thread count (culprit #2: blocked-FFI isolate threads piling up).
  final int threads;

  /// Open handle count (Windows) / open fd count (POSIX).
  final int handles;

  /// Child / ConPTY-host process count (the orphan-accumulation leak signature).
  final int children;

  /// Resident set size in bytes.
  final int rssBytes;

  Map<String, Object?> toJson() => {
    if (threads >= 0) 'threads': threads,
    if (handles >= 0) 'handles': handles,
    if (children >= 0) 'children': children,
    if (rssBytes >= 0) 'rssMB': (rssBytes / (1024 * 1024)).round(),
  };
}

/// Samples the CURRENT process's resource counts. Cheap, synchronous, never
/// throws (returns `-1` fields on failure).
abstract class ResourceSampler {
  ResourceSample sample();

  /// The backend for the running OS — `/proc` on POSIX, a thin Win32 FFI
  /// snapshot on Windows.
  static ResourceSampler forPlatform() => Platform.isWindows ? WindowsResourceSampler() : PosixResourceSampler();
}

/// POSIX sampler — reads `/proc/self`. Runs (and is tested) on the Linux CI box.
class PosixResourceSampler implements ResourceSampler {
  @override
  ResourceSample sample() => ResourceSample(threads: _threads(), handles: _fdCount(), children: _childCount(), rssBytes: _rss());

  int _threads() {
    try {
      for (final line in File('/proc/self/status').readAsLinesSync()) {
        if (line.startsWith('Threads:')) return int.parse(line.split(RegExp(r'\s+'))[1]);
      }
    } catch (_) {}
    return -1;
  }

  int _fdCount() {
    try {
      return Directory('/proc/self/fd').listSync().length;
    } catch (_) {
      return -1;
    }
  }

  int _childCount() {
    // Sum each thread's direct-children list (`/proc/<pid>/task/<tid>/children`,
    // Linux 5.3+). Best-effort: absent file / old kernel → 0 from that thread.
    try {
      var n = 0;
      for (final task in Directory('/proc/self/task').listSync()) {
        final f = File('${task.path}/children');
        if (!f.existsSync()) continue;
        final s = f.readAsStringSync().trim();
        if (s.isNotEmpty) n += s.split(RegExp(r'\s+')).length;
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  int _rss() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return -1;
    }
  }
}

/// The watchdog's on-disk writer: bounded, synchronously-fsynced JSON-lines
/// (heartbeats + samples). Separated from the loop so it unit-tests in
/// isolation. Mirrors [IsolateCrumbFile]'s truncate-on-cap bound.
class WatchdogFile {
  WatchdogFile(String? path, {int capBytes = 256 * 1024}) : _capBytes = capBytes {
    if (path == null) return;
    try {
      final f = File(path);
      f.parent.createSync(recursive: true);
      final raf = f.openSync(mode: FileMode.append);
      _raf = raf;
      _size = raf.lengthSync();
    } catch (_) {
      _raf = null;
    }
  }

  final int _capBytes;
  RandomAccessFile? _raf;
  int _size = 0;

  bool get enabled => _raf != null;

  void heartbeat() => _write({'ts': _now(), 'evt': 'hb'});

  void sample(ResourceSample s) => _write({'ts': _now(), 'evt': 'sample', 'pid': pid, ...s.toJson()});

  String _now() => DateTime.now().toUtc().toIso8601String();

  void _write(Map<String, Object?> json) {
    final raf = _raf;
    if (raf == null) return;
    try {
      if (_size >= _capBytes) {
        raf.truncateSync(0);
        raf.setPositionSync(0);
        _size = 0;
      }
      final bytes = utf8.encode('${jsonEncode(json)}\n');
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

/// The watchdog loop. Extracted from [watchdogEntry] so a test can bound it
/// with [maxTicks]; production passes null and the loop runs until the isolate
/// is killed at shutdown. Heartbeats fire every [hbIntervalMs], samples every
/// [sampleIntervalMs]; a short sleep between keeps the cadence without spinning.
void runWatchdog(WatchdogFile file, ResourceSampler sampler, {required int hbIntervalMs, required int sampleIntervalMs, int? maxTicks}) {
  if (!file.enabled) return;
  final sw = Stopwatch()..start();
  // Seed both "last" markers a full interval in the past so the first tick
  // emits an immediate heartbeat + sample (a baseline at startup).
  var lastHb = -hbIntervalMs;
  var lastSample = -sampleIntervalMs;
  var ticks = 0;
  while (maxTicks == null || ticks < maxTicks) {
    final e = sw.elapsedMilliseconds;
    if (e - lastHb >= hbIntervalMs) {
      file.heartbeat();
      lastHb = e;
    }
    if (e - lastSample >= sampleIntervalMs) {
      file.sample(sampler.sample());
      lastSample = e;
    }
    ticks++;
    if (maxTicks != null && ticks >= maxTicks) break;
    sleep(const Duration(milliseconds: 25));
  }
  file.close();
}

/// Top-level entry for `Isolate.spawn`. Args are a sendable tuple — the log
/// path (not a Logger; isolates can't share one) and the two intervals in ms.
void watchdogEntry((String, int, int) msg) {
  final (logPath, hbMs, sampleMs) = msg;
  runWatchdog(WatchdogFile(logPath), ResourceSampler.forPlatform(), hbIntervalMs: hbMs, sampleIntervalMs: sampleMs);
}
