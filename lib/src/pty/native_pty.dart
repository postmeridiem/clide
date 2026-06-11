/// Native PTY via posix_openpt() + posix_spawn().
///
/// Originally used `forkpty()`, which calls `fork()` underneath. `fork()`
/// in a multithreaded process is unsafe: only the calling thread survives
/// in the child, but libc locks (notably `malloc`) held by other threads
/// remain "locked forever." With the multi-threaded Dart VM as the
/// parent, ~5% of spawns deadlocked in the child before `execve` (see
/// T-96).
///
/// `posix_spawn()` uses `vfork()` on glibc/musl/macOS, which keeps the
/// parent suspended until `execve` completes — no Dart code runs in the
/// child, so the lock-deadlock window is closed. The pty is created via
/// the POSIX-standard `posix_openpt` / `grantpt` / `unlockpt` /
/// `ptsname` sequence instead of the BSD `forkpty` wrapper.
///
/// All symbols live in libc (resolved via `DynamicLibrary.process()`).
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'errors.dart';
import '../ipc/errno_mapping.dart' show PosixErrno;
import 'ffi/libc.dart' as libc;

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

final ffi.DynamicLibrary _dl = ffi.DynamicLibrary.process();

// pty open/setup (POSIX).
final _posixOpenpt = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>('posix_openpt');
final _grantpt = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>('grantpt');
final _unlockpt = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>('unlockpt');
final _ptsname = _dl.lookupFunction<ffi.Pointer<Utf8> Function(ffi.Int32), ffi.Pointer<Utf8> Function(int)>('ptsname');

// posix_spawn family. The attr + file_actions structs are opaque to us
// and platform-sized — we allocate a generous fixed buffer (8 KiB, far
// larger than any documented platform layout) and pass it as Pointer<Void>.
// init() writes the real layout into our memory; destroy() releases any
// internal nested allocations.
final _posixSpawn = _dl
    .lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<ffi.Int32>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Pointer<Utf8>>,
        ffi.Pointer<ffi.Pointer<Utf8>>,
      ),
      int Function(
        ffi.Pointer<ffi.Int32>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Pointer<Utf8>>,
        ffi.Pointer<ffi.Pointer<Utf8>>,
      )
    >('posix_spawn');

final _spawnattrInit = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>('posix_spawnattr_init');
final _spawnattrDestroy = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>('posix_spawnattr_destroy');
final _spawnattrSetflags = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int16), int Function(ffi.Pointer<ffi.Void>, int)>(
  'posix_spawnattr_setflags',
);

final _faInit = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>('posix_spawn_file_actions_init');
final _faDestroy = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>('posix_spawn_file_actions_destroy');
final _faAddopen = _dl
    .lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<Utf8>, ffi.Int32, ffi.Uint32),
      int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<Utf8>, int, int)
    >('posix_spawn_file_actions_addopen');
final _faAdddup2 = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Int32), int Function(ffi.Pointer<ffi.Void>, int, int)>(
  'posix_spawn_file_actions_adddup2',
);
final _faAddclose = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32), int Function(ffi.Pointer<ffi.Void>, int)>(
  'posix_spawn_file_actions_addclose',
);
// glibc 2.29+ / macOS 10.15+. Both ship the `_np` suffix.
final _faAddchdir = _dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>), int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>)>(
  'posix_spawn_file_actions_addchdir_np',
);

// libc primitives shared with the reader isolate / lifecycle.
final _nativeWrite = _dl.lookupFunction<ffi.IntPtr Function(ffi.Int32, ffi.Pointer<ffi.Void>, ffi.IntPtr), int Function(int, ffi.Pointer<ffi.Void>, int)>(
  'write',
);
final _nativeClose = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>('close');
final _ioctl = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32, ffi.UnsignedLong, ffi.Pointer<_Winsize>), int Function(int, int, ffi.Pointer<_Winsize>)>(
  'ioctl',
);
final _nativeKill = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32, ffi.Int32), int Function(int, int)>('kill');
final _waitpid = _dl.lookupFunction<ffi.Int32 Function(ffi.Int32, ffi.Pointer<ffi.Int32>, ffi.Int32), int Function(int, ffi.Pointer<ffi.Int32>, int)>(
  'waitpid',
);

// Constants — all duplicated from <fcntl.h>, <sys/ioctl.h>, <spawn.h>.
final int _kTiocsWinsz = Platform.isMacOS ? 0x80087467 : 0x5414;
const int _kORdwr = 0x0002;
final int _kONoctty = Platform.isMacOS ? 0x20000 : 0x0100;
// POSIX_SPAWN_SETSID — glibc 2.26+ (0x80), macOS 10.15+ (0x400).
final int _kSpawnSetsid = Platform.isMacOS ? 0x400 : 0x80;
// Opaque struct buffer size: ample headroom above every documented
// platform layout (glibc posix_spawnattr_t is 336 B; macOS even smaller).
const int _kSpawnStructBytes = 8192;

const _kWnohang = 1;

// -- NativePty --------------------------------------------------------------

/// A pseudo-terminal backed by forkpty() via Dart FFI.
class NativePty {
  final int _fd;
  final int pid;
  final _out = StreamController<Uint8List>.broadcast();
  bool _dead = false;

  /// Tracks the reader isolate's spawn — close() awaits this before
  /// tearing down so we never race a still-spawning isolate.
  Future<void>? _readerReady;
  Isolate? _readerIsolate;
  ReceivePort? _readerPort;
  Completer<void>? _readerExited;

  NativePty._(this._fd, this.pid);

  /// Byte stream of data produced by the child.
  Stream<Uint8List> get output => _out.stream;

  bool get isClosed => _dead;

  /// Spawn a new PTY running [executable] with [arguments].
  ///
  /// [environment] must be the complete environment — it goes straight
  /// to the spawn's envp. Merge `Platform.environment` before calling.
  ///
  /// Uses `posix_openpt` + `posix_spawn` (via libc's `vfork`-backed
  /// implementation) so no Dart code runs between fork and execve —
  /// see the library docstring and T-96.
  static NativePty start({
    required String executable,
    List<String> arguments = const ['-l'],
    required int columns,
    required int rows,
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) {
    // Resolve bare command names via PATH (posix_spawn requires an absolute
    // or relative path — posix_spawnp would search PATH for us but we want
    // resolution to be visible/debuggable from Dart).
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

    // ---- Open the pty master ------------------------------------------
    final masterFd = _posixOpenpt(_kORdwr | _kONoctty);
    if (masterFd < 0) {
      throw PtyException('posix_openpt', 'posix_openpt failed', errno: libc.errno);
    }
    if (_grantpt(masterFd) != 0) {
      final err = libc.errno;
      _nativeClose(masterFd);
      throw PtyException('grantpt', 'grantpt failed', errno: err);
    }
    if (_unlockpt(masterFd) != 0) {
      final err = libc.errno;
      _nativeClose(masterFd);
      throw PtyException('unlockpt', 'unlockpt failed', errno: err);
    }
    final slavePtr = _ptsname(masterFd);
    if (slavePtr == ffi.nullptr) {
      _nativeClose(masterFd);
      throw PtyException('ptsname', 'ptsname returned null');
    }
    // ptsname returns a pointer into a static (or thread-local) libc
    // buffer; copy to a Dart-owned native string before any other libc
    // call that might overwrite it.
    final slavePath = slavePtr.toDartString().toNativeUtf8(allocator: malloc);

    // ---- Marshal argv + envp -----------------------------------------
    final exeN = executable.toNativeUtf8(allocator: malloc);
    final allArgs = [executable, ...arguments];
    final argvN = malloc<ffi.Pointer<Utf8>>(allArgs.length + 1);
    for (var i = 0; i < allArgs.length; i++) {
      argvN[i] = allArgs[i].toNativeUtf8(allocator: malloc);
    }
    argvN[allArgs.length] = ffi.nullptr;

    final envList = environment.entries.toList();
    final envpN = malloc<ffi.Pointer<Utf8>>(envList.length + 1);
    for (var i = 0; i < envList.length; i++) {
      envpN[i] = '${envList[i].key}=${envList[i].value}'.toNativeUtf8(allocator: malloc);
    }
    envpN[envList.length] = ffi.nullptr;

    final wdN = workingDirectory == null ? ffi.nullptr : workingDirectory.toNativeUtf8(allocator: malloc);

    // ---- Build file_actions ------------------------------------------
    // Allocate as Uint8 so calloc treats it as a byte buffer; cast to
    // Pointer<Void> when handing off to the FFI calls.
    final fa = calloc<ffi.Uint8>(_kSpawnStructBytes).cast<ffi.Void>();
    final attr = calloc<ffi.Uint8>(_kSpawnStructBytes).cast<ffi.Void>();
    final pidOut = calloc<ffi.Int32>();

    void freeAllInputs() {
      malloc.free(exeN);
      for (var i = 0; i < allArgs.length; i++) {
        malloc.free(argvN[i]);
      }
      malloc.free(argvN);
      for (var i = 0; i < envList.length; i++) {
        malloc.free(envpN[i]);
      }
      malloc.free(envpN);
      if (wdN != ffi.nullptr) malloc.free(wdN);
      malloc.free(slavePath);
      calloc.free(fa);
      calloc.free(attr);
      calloc.free(pidOut);
    }

    if (_faInit(fa) != 0) {
      final err = libc.errno;
      _nativeClose(masterFd);
      freeAllInputs();
      throw PtyException('spawn_fa_init', 'posix_spawn_file_actions_init failed', errno: err);
    }
    if (_spawnattrInit(attr) != 0) {
      final err = libc.errno;
      _faDestroy(fa);
      _nativeClose(masterFd);
      freeAllInputs();
      throw PtyException('spawnattr_init', 'posix_spawnattr_init failed', errno: err);
    }

    int rc = 0;
    rc |= _spawnattrSetflags(attr, _kSpawnSetsid);
    // Open the slave on fd 0 WITHOUT O_NOCTTY so it becomes the child's
    // controlling tty (the child is a fresh session leader courtesy of
    // POSIX_SPAWN_SETSID).
    rc |= _faAddopen(fa, 0, slavePath, _kORdwr, 0);
    rc |= _faAdddup2(fa, 0, 1);
    rc |= _faAdddup2(fa, 0, 2);
    // Don't leak the master fd into the child.
    rc |= _faAddclose(fa, masterFd);
    if (wdN != ffi.nullptr) {
      rc |= _faAddchdir(fa, wdN);
    }
    if (rc != 0) {
      _faDestroy(fa);
      _spawnattrDestroy(attr);
      _nativeClose(masterFd);
      freeAllInputs();
      throw PtyException('spawn_fa_setup', 'failed to compose posix_spawn actions', errno: libc.errno);
    }

    // ---- Spawn -------------------------------------------------------
    final spawnRc = _posixSpawn(pidOut, exeN, fa, attr, argvN, envpN);
    final pid = pidOut.value;

    _faDestroy(fa);
    _spawnattrDestroy(attr);

    if (spawnRc != 0) {
      // posix_spawn returns the errno directly (does NOT set errno).
      _nativeClose(masterFd);
      freeAllInputs();
      throw PtyException('posix_spawn', 'posix_spawn failed', errno: spawnRc);
    }

    // ---- Set initial winsize on the master ---------------------------
    final ws = calloc<_Winsize>()
      ..ref.wsRow = rows
      ..ref.wsCol = columns;
    _ioctl(masterFd, _kTiocsWinsz, ws);
    calloc.free(ws);

    freeAllInputs();

    final pty = NativePty._(masterFd, pid);
    pty._spawnReader();
    return pty;
  }

  // -- I/O ------------------------------------------------------------------

  void _spawnReader() {
    _readerReady = _spawnReaderAsync();
  }

  Future<void> _spawnReaderAsync() async {
    final rp = ReceivePort();
    _readerPort = rp;
    _readerExited = Completer<void>();
    // Register the listener BEFORE spawning the isolate. ReceivePort buffers
    // messages until a listener attaches, but registering first removes any
    // ambiguity if the listen() call ever moves further away from spawn (and
    // sidesteps a real race we saw 1-in-10 in CI where output never arrived).
    rp.listen((msg) {
      if (msg == null) {
        if (!_out.isClosed) _out.close();
        rp.close();
        _readerPort = null;
        if (!_readerExited!.isCompleted) _readerExited!.complete();
        _reap();
      } else {
        if (!_out.isClosed) _out.add(msg as Uint8List);
      }
    });
    try {
      _readerIsolate = await Isolate.spawn(_readLoop, (rp.sendPort, _fd));
    } catch (e) {
      // Surface the spawn failure instead of leaving the PTY in a
      // half-alive state where output never flows but isClosed=false.
      _dead = true;
      if (!_out.isClosed) _out.addError(PtyException('reader-spawn', '$e'));
      rp.close();
      _readerPort = null;
      if (!_readerExited!.isCompleted) _readerExited!.complete();
      return;
    }
  }

  /// Isolate entry — polls then reads until EOF/error/fd-closed.
  static void _readLoop((SendPort, int) msg) {
    final (port, fd) = msg;
    final dl = ffi.DynamicLibrary.process();
    final rd = dl.lookupFunction<ffi.IntPtr Function(ffi.Int32, ffi.Pointer<ffi.Void>, ffi.IntPtr), int Function(int, ffi.Pointer<ffi.Void>, int)>('read');
    final poll = dl.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Pollfd>, ffi.Uint32, ffi.Int32), int Function(ffi.Pointer<_Pollfd>, int, int)>('poll');

    final buf = malloc<ffi.Uint8>(65536);
    final pfd = calloc<_Pollfd>();
    pfd.ref.fd = fd;
    pfd.ref.events = libc.pollin;

    try {
      while (true) {
        final ready = poll(pfd, 1, 100);
        if (ready < 0) break;
        if (ready == 0) continue;
        // Slave closed (POLLHUP / POLLERR / POLLNVAL) with no buffered
        // bytes left to read — caller loop exits and we send EOF.
        if (pfd.ref.revents & libc.pollAnyErr != 0 && pfd.ref.revents & libc.pollin == 0) {
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

  /// Write bytes to the child's stdin. Loops on short writes; throws
  /// [PtyException] (with errno) on failure. Returns the total bytes
  /// written, which is always [bytes.length] on success.
  int write(List<int> bytes) {
    if (_dead || bytes.isEmpty) return 0;
    final buf = malloc<ffi.Uint8>(bytes.length);
    try {
      for (var i = 0; i < bytes.length; i++) {
        buf[i] = bytes[i];
      }
      var written = 0;
      while (written < bytes.length) {
        final n = _nativeWrite(_fd, (buf + written).cast(), bytes.length - written);
        if (n < 0) {
          final err = libc.errno;
          if (err == PosixErrno.eintr) continue;
          if (err == PosixErrno.ebadf || err == PosixErrno.epipe) _dead = true;
          throw PtyException('write', 'write to PTY failed', errno: err);
        }
        if (n == 0) break;
        written += n;
      }
      return written;
    } finally {
      malloc.free(buf);
    }
  }

  /// Resize the terminal. Silently no-ops if the fd is already
  /// closed; flips [_dead] on EBADF so subsequent calls short-circuit.
  void resize({required int cols, required int rows}) {
    if (_dead) return;
    final ws = calloc<_Winsize>()
      ..ref.wsRow = rows
      ..ref.wsCol = cols;
    final rc = _ioctl(_fd, _kTiocsWinsz, ws);
    calloc.free(ws);
    if (rc < 0 && libc.errno == PosixErrno.ebadf) {
      _dead = true;
      return;
    }
    // Explicitly signal the child to re-query its terminal size.
    _nativeKill(pid, libc.sigwinch);
  }

  /// Send a signal to the child.
  bool kill([int signal = libc.sighup]) {
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
  ///
  /// Order matters: kill the child first so its slave PTY closes,
  /// causing the master fd to return EOF. The reader isolate sees
  /// EOF and exits cleanly. Only then do we close the master fd —
  /// closing it before the isolate exits creates a window where the
  /// fd number could be reused and the isolate would briefly poll
  /// the wrong file.
  Future<void> close() async {
    if (_dead) return;
    _dead = true;

    // Make sure the reader is fully spawned before we tear it down —
    // otherwise close() racing with start() leaves an orphan isolate.
    await _readerReady;

    _nativeKill(pid, libc.sighup);
    _nativeKill(pid, 9);

    // Wait for the isolate to send `null` (EOF) — confirms it has
    // exited its poll loop and won't touch the fd again.
    if (_readerExited != null) {
      await _readerExited!.future.timeout(const Duration(milliseconds: 500), onTimeout: () {});
    }

    _nativeClose(_fd);
    _readerIsolate?.kill(priority: Isolate.immediate);
    _readerIsolate = null;
    _readerPort?.close();
    _readerPort = null;

    final s = calloc<ffi.Int32>();
    _waitpid(pid, s, 0);
    calloc.free(s);
    if (!_out.isClosed) await _out.close();
  }
}
