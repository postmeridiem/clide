/// [PtySession] — high-level PTY lifecycle.
///
/// Spawns `ptyc` with the given argv/cwd/env, receives the master fd
/// via `SCM_RIGHTS`, and exposes:
///
///   - [output] — a broadcast stream of bytes read from the child.
///   - [write] — send bytes to the child's stdin.
///   - [resize] — change the child's window size.
///   - [kill] — send a signal to the child.
///   - [close] — close the master fd and stop reading.
///
/// Reading happens in a background isolate that loops on blocking
/// `read(fd)` calls and posts bytes to the main isolate via a
/// [ReceivePort]. Closing the fd from the main isolate causes `read()`
/// to return EBADF; the isolate sees that and exits.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as pkg_ffi;

import 'env.dart';
import 'errors.dart';
import 'ffi/libc.dart' as libc;
import 'ffi/scm_rights.dart' as scm;

class _RecvFdArgs {
  const _RecvFdArgs(this.socketFd, this.sendPort);
  final int socketFd;
  final SendPort sendPort;
}

/// A running PTY child plus its master-fd plumbing.
class PtySession {
  PtySession._({
    required this.pid,
    required int masterFd,
  }) : _masterFd = masterFd {
    _startReader();
  }

  /// The spawned child's PID (not ptyc's — ptyc has already exited).
  final int pid;

  int _masterFd;

  final _outputCtrl = StreamController<Uint8List>.broadcast();
  final _readerExited = Completer<void>();
  Isolate? _readerIsolate;
  ReceivePort? _readerPort;

  /// Broadcast stream of raw bytes from the child's stdout/stderr.
  Stream<Uint8List> get output => _outputCtrl.stream;

  /// Whether the session is still alive.
  bool get isClosed => _masterFd < 0;

  /// Spawn a child under a PTY.
  ///
  /// [argv] must be non-empty; [argv[0]] is resolved via PATH. [env]
  /// is merged onto the parent process env via [mergePtyEnv] so
  /// terminal children inherit `HOME` / `USER` while clide's
  /// true-colour defaults still take effect.
  ///
  /// [ptycPath] defaults to looking for `ptyc` on PATH; dev setups
  /// that haven't `make install`'d the helper can point at the
  /// development build under `ptyc/bin/ptyc`.
  static Future<PtySession> spawn({
    required List<String> argv,
    String? cwd,
    Map<String, String>? env,
    int cols = 80,
    int rows = 24,
    String ptycPath = 'ptyc',
  }) async {
    if (argv.isEmpty) {
      throw ArgumentError.value(argv, 'argv', 'must be non-empty');
    }

    // socketpair for the fd transfer.
    final sv = pkg_ffi.calloc<ffi.Int32>(2);
    int parentSock = -1;
    int childSock = -1;
    Process? proc;
    try {
      final rc = libc.socketpair(libc.afUnix, libc.sockStream, 0, sv);
      if (rc < 0) {
        throw PtyException('socketpair', 'socketpair failed', errno: libc.errno);
      }
      parentSock = sv[0];
      childSock = sv[1];

      // Build the JSON request for ptyc.
      final req = _buildRequest(
        argv: argv,
        cwd: cwd,
        env: mergePtyEnv(
          processEnv: Platform.environment,
          overrides: env,
        ),
        cols: cols,
        rows: rows,
      );

      // Launch ptyc. We pass childSock to it via PTYC_SOCK_FD so ptyc
      // reads it from env rather than having to place it at fd 3
      // specifically — Dart's Process.start doesn't give us fine
      // control over child fd layout.
      proc = await Process.start(
        ptycPath,
        const [],
        environment: {
          ...Platform.environment,
          'PTYC_SOCK_FD': childSock.toString(),
        },
        // Inherit the socket fd into the child. Dart exposes this via
        // a private API in recent versions; until it lands we rely on
        // default behaviour (Process.start doesn't close arbitrary
        // fds inherited from the parent's open-fd set).
        mode: ProcessStartMode.normal,
      );

      // Send the request and close stdin so ptyc sees EOF.
      proc.stdin.add(req);
      await proc.stdin.close();

      // Receive the master fd over the parent side of the socketpair.
      // recvFd blocks until ptyc sends — run in a child isolate so the
      // calling isolate's event loop stays responsive.
      final masterFd = await _recvFdAsync(parentSock);

      // Apply initial winsize (ptyc already did this, but doing it
      // again from Dart confirms the wire + gives a place to call it
      // when resize() lands).
      libc.setWinsize(masterFd, cols, rows);

      // Drain ptyc's stdout to parse the success envelope. We don't
      // strictly need it — the fd arriving is proof-of-life — but
      // draining avoids a PIPE accumulating.
      final stdoutLine = await proc.stdout
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 5));
      final pid = _extractPid(stdoutLine);

      final code = await proc.exitCode;
      if (code != 0) {
        final stderr = await proc.stderr.transform(const Utf8Decoder()).join();
        libc.close(masterFd);
        throw PtyException('ptyc', 'ptyc exited with code $code: $stderr');
      }

      return PtySession._(pid: pid, masterFd: masterFd);
    } finally {
      // parent keeps its own fd until the session is closed; ptyc-side
      // fd is released either way (ptyc has exited by now).
      if (childSock >= 0) libc.close(childSock);
      pkg_ffi.calloc.free(sv);
    }
  }

  /// Send bytes to the child's stdin.
  int write(List<int> bytes) {
    if (isClosed) return 0;
    final buf = pkg_ffi.calloc<ffi.Uint8>(bytes.length);
    try {
      for (var i = 0; i < bytes.length; i++) {
        buf[i] = bytes[i];
      }
      return libc.write(_masterFd, buf, bytes.length);
    } finally {
      pkg_ffi.calloc.free(buf);
    }
  }

  /// Resize the child's terminal.
  void resize({required int cols, required int rows}) {
    if (isClosed) return;
    libc.setWinsize(_masterFd, cols, rows);
  }

  /// Send a signal to the child. Uses `Process.killPid` for now; a
  /// future pass can deliver signals via the PTY's foreground process
  /// group so Ctrl-C from the UI works naturally.
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return Process.killPid(pid, signal);
  }

  /// Close the session. Signals the child, waits briefly for the
  /// reader isolate to see EOF on the master fd (natural wakeup), and
  /// then closes + force-kills whatever's still around.
  ///
  /// Ordering matters: closing the master fd alone does **not** unblock
  /// a `read()` already in flight on Linux — the blocked syscall holds
  /// a reference to the kernel file. Killing the child causes the PTY
  /// to return EOF on master, which is the clean way to wake the
  /// reader. See D-005 notes; a belt-and-braces `poll()` + self-pipe
  /// wake path is possible but not worth the FFI surface at Tier 1.
  Future<void> close() async {
    if (isClosed) return;
    final fd = _masterFd;
    _masterFd = -1;

    // 1. Ask the child nicely so the shell can run its exit traps.
    try {
      Process.killPid(pid, ProcessSignal.sigterm);
    } catch (_) {
      // Already gone — fine.
    }

    // 2. Give the reader isolate up to ~500ms to see EOF and signal
    //    back via its 'eof' message (set by the existing listener,
    //    which completes _readerExited).
    await _readerExited.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {},
    );

    // 3. Belt and braces: SIGKILL the child, close the master, and
    //    force-kill the isolate regardless. Any still-pending read()
    //    returns on close via EIO; future reads return EBADF.
    try {
      Process.killPid(pid, ProcessSignal.sigkill);
    } catch (_) {}
    libc.close(fd);
    _readerPort?.close();
    _readerIsolate?.kill(priority: Isolate.immediate);
    _readerPort = null;
    _readerIsolate = null;

    if (!_outputCtrl.isClosed) await _outputCtrl.close();
  }

  /// Run recvFd in a child isolate so the blocking FFI call doesn't
  /// stall the calling isolate's event loop.
  static Future<int> _recvFdAsync(int socketFd) async {
    final port = ReceivePort();
    final iso = await Isolate.spawn(_recvFdEntry, _RecvFdArgs(socketFd, port.sendPort));
    final result = await port.first;
    iso.kill(priority: Isolate.immediate);
    port.close();
    if (result is int) return result;
    throw PtyException('recvFd', '$result');
  }

  static void _recvFdEntry(_RecvFdArgs args) {
    try {
      final fd = scm.recvFd(args.socketFd);
      args.sendPort.send(fd);
    } catch (e) {
      args.sendPort.send('error: $e');
    }
  }

  // ---------------------------------------------------------------- //

  void _startReader() {
    final port = ReceivePort();
    _readerPort = port;

    port.listen((dynamic msg) {
      if (msg is Uint8List) {
        if (!_outputCtrl.isClosed) _outputCtrl.add(msg);
      } else if (msg == 'eof') {
        if (!_readerExited.isCompleted) _readerExited.complete();
      }
    });

    Isolate.spawn<_ReaderArgs>(
      _readerEntrypoint,
      _ReaderArgs(fd: _masterFd, sendPort: port.sendPort),
    ).then((iso) => _readerIsolate = iso);
  }

  // -- request builder ------------------------------------------------------

  static List<int> _buildRequest({
    required List<String> argv,
    required String? cwd,
    required Map<String, String> env,
    required int cols,
    required int rows,
  }) {
    // Minimal JSON emitter — our request never contains non-ASCII,
    // so we only need to escape ", \, and the standard control chars.
    final sb = StringBuffer('{');
    sb.write('"argv":[');
    for (var i = 0; i < argv.length; i++) {
      if (i > 0) sb.write(',');
      sb.write(_json(argv[i]));
    }
    sb.write(']');
    if (cwd != null) {
      sb.write(',"cwd":${_json(cwd)}');
    }
    sb.write(',"env":{');
    var first = true;
    env.forEach((k, v) {
      if (!first) sb.write(',');
      first = false;
      sb.write('${_json(k)}:${_json(v)}');
    });
    sb.write('}');
    sb.write(',"cols":$cols,"rows":$rows');
    sb.write('}');
    return utf8.encode(sb.toString());
  }

  static String _json(String s) {
    final b = StringBuffer('"');
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      switch (c) {
        case 0x22: b.write(r'\"'); break;
        case 0x5c: b.write(r'\\'); break;
        case 0x08: b.write(r'\b'); break;
        case 0x09: b.write(r'\t'); break;
        case 0x0a: b.write(r'\n'); break;
        case 0x0c: b.write(r'\f'); break;
        case 0x0d: b.write(r'\r'); break;
        default:
          if (c < 0x20) {
            b.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
          } else {
            b.writeCharCode(c);
          }
      }
    }
    b.write('"');
    return b.toString();
  }

  static int _extractPid(String json) {
    // Narrow regex is enough — ptyc's success envelope is known-shape.
    final m = RegExp(r'"pid"\s*:\s*(\d+)').firstMatch(json);
    if (m == null) {
      throw PtyException('ptyc', 'no pid in ptyc response: $json');
    }
    return int.parse(m.group(1)!);
  }
}

// ---------------------------------------------------------------------------
// Reader isolate
// ---------------------------------------------------------------------------

class _ReaderArgs {
  const _ReaderArgs({required this.fd, required this.sendPort});
  final int fd;
  final SendPort sendPort;
}

/// Runs in a separate isolate. Loops on blocking `read(fd)` and posts
/// each chunk back to the main isolate as a `Uint8List`. Exits on
/// EOF, close, or error.
void _readerEntrypoint(_ReaderArgs args) {
  const chunk = 4096;
  final buf = pkg_ffi.calloc<ffi.Uint8>(chunk);
  try {
    while (true) {
      final n = libc.read(args.fd, buf, chunk);
      if (n > 0) {
        final bytes = Uint8List(n);
        for (var i = 0; i < n; i++) {
          bytes[i] = buf[i];
        }
        args.sendPort.send(bytes);
      } else if (n == 0) {
        // child closed pty → EOF
        args.sendPort.send('eof');
        return;
      } else {
        final err = libc.errno;
        if (err == 4 /* EINTR */) continue;
        // 9=EBADF (fd closed from main), 5=EIO (child exited on
        // Linux). Either way, we're done.
        args.sendPort.send('eof');
        return;
      }
    }
  } finally {
    pkg_ffi.calloc.free(buf);
  }
}

