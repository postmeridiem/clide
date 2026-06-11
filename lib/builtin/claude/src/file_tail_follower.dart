/// Read-only file follower for the Bash live-tail sub-card (T-325).
///
/// clide can't see a running Bash command's stdout (Claude Code owns the
/// process), so to "watch the same output" we open our OWN read-only follower
/// on the file the command tails. This never spawns a process and never
/// touches Claude's command — it just reads the file as it grows, like
/// `tail -f`, and hands new bytes to [onData].
///
/// Pure dart:io/dart:async (no Flutter) so it's unit-testable. Polls rather
/// than using a watcher so it works uniformly across platforms and survives
/// truncation/rotation (size shrinking → re-read from the top).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class FileTailFollower {
  FileTailFollower(this.path, {required this.onData, this.tailBytes = 16384, this.interval = const Duration(milliseconds: 300)});

  /// Absolute path of the file to follow.
  final String path;

  /// New bytes appended since the last read (or the initial tail window).
  final void Function(Uint8List bytes) onData;

  /// On first read, start this many bytes from the end (a `tail -c` window)
  /// rather than dumping the whole file.
  final int tailBytes;

  final Duration interval;

  int _pos = 0;
  bool _primed = false;
  bool _stopped = false;
  Timer? _timer;

  /// Begin following: emit the initial tail window, then poll for growth.
  Future<void> start() async {
    await pollOnce();
    if (_stopped) return;
    _timer = Timer.periodic(interval, (_) => pollOnce());
  }

  /// One read cycle. Public so tests can drive it deterministically without
  /// waiting on the timer. Reads any bytes appended since the last position
  /// (or, on the first call, the trailing [tailBytes]); resets to the top if
  /// the file shrank (truncated/rotated).
  Future<void> pollOnce() async {
    if (_stopped) return;
    final file = File(path);
    if (!await file.exists()) return; // not created yet — keep waiting
    final length = await file.length();

    if (!_primed) {
      _pos = length > tailBytes ? length - tailBytes : 0;
      _primed = true;
    } else if (length < _pos) {
      _pos = 0; // truncated / rotated → re-read from the top
    }
    if (length <= _pos) return;

    final raf = await file.open();
    try {
      await raf.setPosition(_pos);
      final bytes = await raf.read(length - _pos);
      _pos = length;
      if (!_stopped && bytes.isNotEmpty) onData(Uint8List.fromList(bytes));
    } finally {
      await raf.close();
    }
  }

  /// Stop following and release the timer. Idempotent.
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
