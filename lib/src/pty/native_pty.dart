/// Native PTY via forkpty() — replaces the ptyc helper binary.
///
/// Uses Dart FFI to call forkpty() directly. The master fd stays
/// in-process (no socketpair, no SCM_RIGHTS). The reader isolate
/// uses poll() for clean shutdown.
///
/// Based on the pty-spike proof-of-concept. Platform-aware:
///   macOS: forkpty in libSystem (DynamicLibrary.process)
///   Linux: forkpty in libutil.so.1
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// -- structs ----------------------------------------------------------------

final class _Winsize extends ffi.Struct {
  @ffi.Uint16()
  external int wsRow;
  @ffi.Uint16()
  external int wsCol;
  @ffi.Uint16()
  external int wsXpixel;
  @ffi.Uint16()
  external int wsYpixel;
}

final class _Pollfd extends ffi.Struct {
  @ffi.Int32()
  external int fd;
  @ffi.Int16()
  external int events;
  @ffi.Int16()
  external int revents;
}

// -- FFI bindings -----------------------------------------------------------

final ffi.DynamicLibrary _dl = _openLib();

ffi.DynamicLibrary _openLib() {
  if (Platform.isMacOS) return ffi.DynamicLibrary.process();
  // Linux: forkpty lives in libutil
  return ffi.DynamicLibrary.open('libutil.so.1');
}

final _forkpty = _dl.lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Char>,
        ffi.Pointer<ffi.Void>, ffi.Pointer<_Winsize>),
    int Function(ffi.Pointer<ffi.Int32>, ffi.Pointer<ffi.Char>,
        ffi.Pointer<ffi.Void>, ffi.Pointer<_Winsize>)>('forkpty');

final _execve = _dl.lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Char>,
        ffi.Pointer<ffi.Pointer<ffi.Char>>, ffi.Pointer<ffi.Pointer<ffi.Char>>),
    int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Pointer<ffi.Char>>,
        ffi.Pointer<ffi.Pointer<ffi.Char>>)>('execve');

final _nativeWrite = ffi.DynamicLibrary.process().lookupFunction<
    ffi.IntPtr Function(ffi.Int32, ffi.Pointer<ffi.Void>, ffi.IntPtr),
    int Function(int, ffi.Pointer<ffi.Void>, int)>('write');

final _nativeClose = ffi.DynamicLibrary.process()
    .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>('close');

final _ioctl = ffi.DynamicLibrary.process().lookupFunction<
    ffi.Int32 Function(ffi.Int32, ffi.UnsignedLong, ffi.Pointer<_Winsize>),
    int Function(int, int, ffi.Pointer<_Winsize>)>('ioctl');

final _nativeKill = ffi.DynamicLibrary.process().lookupFunction<
    ffi.Int32 Function(ffi.Int32, ffi.Int32), int Function(int, int)>('kill');

final _waitpid = ffi.DynamicLibrary.process().lookupFunction<
    ffi.Int32 Function(ffi.Int32, ffi.Pointer<ffi.Int32>, ffi.Int32),
    int Function(int, ffi.Pointer<ffi.Int32>, int)>('waitpid');

final _chdir = ffi.DynamicLibrary.process().lookupFunction<
    ffi.Int32 Function(ffi.Pointer<ffi.Char>),
    int Function(ffi.Pointer<ffi.Char>)>('chdir');

final _exit_ = ffi.DynamicLibrary.process().lookupFunction<
    ffi.Void Function(ffi.Int32), void Function(int)>('_exit');

final int _kTiocsWinsz = Platform.isMacOS ? 0x80087467 : 0x5414;
const _kSighup = 1;
const _kWnohang = 1;

// -- NativePty --------------------------------------------------------------

/// A pseudo-terminal backed by forkpty() via Dart FFI.
///
/// Drop-in replacement for the old ptyc-based PtySession.
class NativePty {
  final int _fd;
  final int pid;
  final _out = StreamController<Uint8List>.broadcast();
  bool _dead = false;

  NativePty._(this._fd, this.pid);

  /// Byte stream of data produced by the child.
  Stream<Uint8List> get output => _out.stream;

  bool get isClosed => _dead;

  /// Spawn a new PTY running [executable] with [arguments].
  ///
  /// [environment] must be the complete environment — it goes straight
  /// to execve's envp. Merge Platform.environment before calling.
  static NativePty start({
    required String executable,
    List<String> arguments = const ['-l'],
    required int columns,
    required int rows,
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) {
    // Resolve bare command names via PATH (execve doesn't search PATH).
    if (!executable.contains('/')) {
      final path = environment['PATH'] ?? Platform.environment['PATH'] ?? '';
      for (final dir in path.split(':')) {
        if (dir.isEmpty) continue;
        final candidate = '$dir/$executable';
        if (File(candidate).existsSync()) {
          executable = candidate;
          break;
        }
      }
    }

    // Force-resolve FFI functions that run in the child process.
    // Top-level finals are lazy; touching them here ensures the FFI
    // trampolines are compiled before fork() clones the process.
    final execve = _execve;
    final chdir = _chdir;
    final exit = _exit_;

    // Allocate ALL native memory before fork.
    final shellN = executable.toNativeUtf8(allocator: malloc).cast<ffi.Char>();

    final allArgs = [executable, ...arguments];
    final argvN = malloc<ffi.Pointer<ffi.Char>>(allArgs.length + 1);
    for (var i = 0; i < allArgs.length; i++) {
      argvN[i] = allArgs[i].toNativeUtf8(allocator: malloc).cast();
    }
    argvN[allArgs.length] = ffi.nullptr;

    final envList = environment.entries.toList();
    final envpN = malloc<ffi.Pointer<ffi.Char>>(envList.length + 1);
    for (var i = 0; i < envList.length; i++) {
      envpN[i] = '${envList[i].key}=${envList[i].value}'
          .toNativeUtf8(allocator: malloc)
          .cast();
    }
    envpN[envList.length] = ffi.nullptr;

    final wdN = (workingDirectory ?? '/')
        .toNativeUtf8(allocator: malloc)
        .cast<ffi.Char>();
    final fdOut = calloc<ffi.Int32>();
    final ws = calloc<_Winsize>()
      ..ref.wsRow = rows
      ..ref.wsCol = columns;

    // Fork.
    final pid = _forkpty(fdOut, ffi.nullptr, ffi.nullptr, ws);

    if (pid == -1) {
      _freeAll(shellN, argvN, allArgs.length, envpN, envList.length, wdN,
          fdOut, ws);
      throw StateError('forkpty() failed');
    }

    if (pid == 0) {
      // CHILD — only pre-resolved FFI calls, no Dart heap.
      chdir(wdN);
      execve(shellN, argvN, envpN);
      exit(1);
    }

    // PARENT
    final fd = fdOut.value;
    _freeAll(shellN, argvN, allArgs.length, envpN, envList.length, wdN,
        fdOut, ws);

    final pty = NativePty._(fd, pid);
    pty._spawnReader();
    return pty;
  }

  static void _freeAll(
    ffi.Pointer shell,
    ffi.Pointer<ffi.Pointer<ffi.Char>> argv, int argc,
    ffi.Pointer<ffi.Pointer<ffi.Char>> envp, int envc,
    ffi.Pointer wd, ffi.Pointer fdOut, ffi.Pointer ws,
  ) {
    malloc.free(shell);
    for (var i = 0; i < argc; i++) malloc.free(argv[i]);
    malloc.free(argv);
    for (var i = 0; i < envc; i++) malloc.free(envp[i]);
    malloc.free(envp);
    malloc.free(wd);
    calloc.free(fdOut);
    calloc.free(ws);
  }

  // -- I/O ------------------------------------------------------------------

  void _spawnReader() async {
    final rp = ReceivePort();
    await Isolate.spawn(_readLoop, (rp.sendPort, _fd));
    rp.listen((msg) {
      if (msg == null) {
        if (!_out.isClosed) _out.close();
        rp.close();
        _reap();
      } else {
        if (!_out.isClosed) _out.add(msg as Uint8List);
      }
    });
  }

  /// Isolate entry — polls then reads until EOF/error/fd-closed.
  static void _readLoop((SendPort, int) msg) {
    final (port, fd) = msg;
    final dl = ffi.DynamicLibrary.process();
    final rd = dl.lookupFunction<
        ffi.IntPtr Function(ffi.Int32, ffi.Pointer<ffi.Void>, ffi.IntPtr),
        int Function(int, ffi.Pointer<ffi.Void>, int)>('read');
    final poll = dl.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<_Pollfd>, ffi.Uint32, ffi.Int32),
        int Function(ffi.Pointer<_Pollfd>, int, int)>('poll');

    final buf = malloc<ffi.Uint8>(65536);
    final pfd = calloc<_Pollfd>();
    pfd.ref.fd = fd;
    pfd.ref.events = 0x0001; // POLLIN

    try {
      while (true) {
        final ready = poll(pfd, 1, 100);
        if (ready < 0) break;
        if (ready == 0) continue;
        if (pfd.ref.revents & 0x0038 != 0 && pfd.ref.revents & 0x0001 == 0) {
          break;
        }
        final n = rd(fd, buf.cast(), 65536);
        if (n <= 0) break;
        port.send(Uint8List.fromList(buf.asTypedList(n)));
      }
    } finally {
      calloc.free(pfd);
      malloc.free(buf);
    }
    port.send(null);
  }

  /// Write bytes to the child's stdin.
  int write(List<int> bytes) {
    if (_dead || bytes.isEmpty) return 0;
    final buf = malloc<ffi.Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) buf[i] = bytes[i];
    final n = _nativeWrite(_fd, buf.cast(), bytes.length);
    malloc.free(buf);
    return n;
  }

  /// Resize the terminal.
  void resize({required int cols, required int rows}) {
    if (_dead) return;
    final ws = calloc<_Winsize>()
      ..ref.wsRow = rows
      ..ref.wsCol = cols;
    final rc = _ioctl(_fd, _kTiocsWinsz, ws);
    calloc.free(ws);
    print('[pty-resize] fd=$_fd cols=$cols rows=$rows ioctl=$rc pid=$pid');
    // Explicitly signal the child to re-query its terminal size.
    _nativeKill(pid, 28); // SIGWINCH = 28 on macOS/Linux
  }

  /// Send a signal to the child.
  bool kill([int signal = _kSighup]) {
    if (_dead) return false;
    return _nativeKill(pid, signal) == 0;
  }

  void _reap() {
    if (_dead) return;
    _dead = true;
    final s = calloc<ffi.Int32>();
    _waitpid(pid, s, _kWnohang);
    calloc.free(s);
  }

  /// Kill the child and release resources.
  Future<void> close() async {
    if (_dead) return;
    _dead = true;
    _nativeClose(_fd);
    _nativeKill(pid, _kSighup);
    _nativeKill(pid, 9);
    final s = calloc<ffi.Int32>();
    _waitpid(pid, s, 0);
    calloc.free(s);
    if (!_out.isClosed) await _out.close();
  }
}
