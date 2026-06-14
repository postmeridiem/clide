/// Native PTY on Windows via ConPTY (`CreatePseudoConsole`).
///
/// Mirrors the POSIX [NativePty] lifecycle (see `native_pty.dart`):
/// spawn a child attached to a pseudo-console, surface its output as
/// a byte stream, accept writes / resizes / kills, reap on close.
///
/// The Win32 sequence:
///
///   1. Two anonymous pipes — one ConPTY reads child input from, one
///      it writes rendered VT output to.
///   2. `CreatePseudoConsole(size, inRead, outWrite)` → `HPCON`. The
///      conpty-side ends (`inRead` / `outWrite`) must stay open for
///      the pseudo console's whole lifetime: on current Windows 11
///      the conpty host runs IN-PROCESS and uses these very handles
///      (the old "conhost dups them, close immediately" advice from
///      the EchoCon sample era silently breaks output — the freed
///      handle slot gets recycled and conhost writes land wherever
///      it now points, observed empirically as output appearing on
///      the parent's console).
///   3. `CreateProcessW` with `EXTENDED_STARTUPINFO_PRESENT`, the
///      `HPCON` attached via `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE`,
///      and `STARTF_USESTDHANDLES` with NULL std handles — without
///      that a console parent's std handles leak into the child and
///      its stdout bypasses the conpty entirely (also empirical; the
///      conpty handshake still fires, which makes it look attached).
///   4. A reader isolate blocks on `ReadFile(outRead)`; a waiter
///      isolate blocks on `WaitForSingleObject(hProcess, INFINITE)`.
///      On child exit the waiter reports back and the main isolate
///      calls `ClosePseudoConsole` and closes the conpty-side pipe
///      ends — that breaks the output pipe, so the reader drains
///      whatever is still buffered, sees `ERROR_BROKEN_PIPE`, and
///      sends EOF.
///
/// Requires Windows 10 1809+ (first ConPTY release). All symbols
/// live in kernel32.dll. Errors carry `GetLastError()` in
/// [PtyException.errno] (a Win32 error code, not a POSIX errno).
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'errors.dart';
import 'pty_session.dart';
import 'pty_size.dart';

// -- structs ----------------------------------------------------------------

/// Win32 `COORD` — passed BY VALUE to Create/ResizePseudoConsole.
final class _Coord extends ffi.Struct {
  @ffi.Int16()
  external int x;
  @ffi.Int16()
  external int y;
}

/// Win32 `STARTUPINFOEXW`. Field names follow the Win32 struct so the
/// layout is checkable against `<processthreadsapi.h>`; Dart FFI derives
/// offsets from declaration order + C alignment rules, which match MSVC
/// here (cb is followed by 4 bytes of padding before the first pointer).
final class _StartupInfoExW extends ffi.Struct {
  @ffi.Uint32()
  external int cb;
  external ffi.Pointer<ffi.Void> lpReserved;
  external ffi.Pointer<ffi.Void> lpDesktop;
  external ffi.Pointer<ffi.Void> lpTitle;
  @ffi.Uint32()
  external int dwX;
  @ffi.Uint32()
  external int dwY;
  @ffi.Uint32()
  external int dwXSize;
  @ffi.Uint32()
  external int dwYSize;
  @ffi.Uint32()
  external int dwXCountChars;
  @ffi.Uint32()
  external int dwYCountChars;
  @ffi.Uint32()
  external int dwFillAttribute;
  @ffi.Uint32()
  external int dwFlags;
  @ffi.Uint16()
  external int wShowWindow;
  @ffi.Uint16()
  external int cbReserved2;
  external ffi.Pointer<ffi.Void> lpReserved2;
  external ffi.Pointer<ffi.Void> hStdInput;
  external ffi.Pointer<ffi.Void> hStdOutput;
  external ffi.Pointer<ffi.Void> hStdError;
  external ffi.Pointer<ffi.Void> lpAttributeList;
}

/// Win32 `PROCESS_INFORMATION`.
final class _ProcessInformation extends ffi.Struct {
  external ffi.Pointer<ffi.Void> hProcess;
  external ffi.Pointer<ffi.Void> hThread;
  @ffi.Uint32()
  external int dwProcessId;
  @ffi.Uint32()
  external int dwThreadId;
}

// -- FFI bindings -----------------------------------------------------------

final ffi.DynamicLibrary _k32 = ffi.DynamicLibrary.open('kernel32.dll');

typedef _Handle = ffi.Pointer<ffi.Void>;

final _createPipe = _k32
    .lookupFunction<
      ffi.Int32 Function(ffi.Pointer<_Handle>, ffi.Pointer<_Handle>, ffi.Pointer<ffi.Void>, ffi.Uint32),
      int Function(ffi.Pointer<_Handle>, ffi.Pointer<_Handle>, ffi.Pointer<ffi.Void>, int)
    >('CreatePipe');

final _createPseudoConsole = _k32
    .lookupFunction<
      ffi.Int32 Function(_Coord, _Handle, _Handle, ffi.Uint32, ffi.Pointer<_Handle>),
      int Function(_Coord, _Handle, _Handle, int, ffi.Pointer<_Handle>)
    >('CreatePseudoConsole');

final _resizePseudoConsole = _k32.lookupFunction<ffi.Int32 Function(_Handle, _Coord), int Function(_Handle, _Coord)>('ResizePseudoConsole');

final _closePseudoConsole = _k32.lookupFunction<ffi.Void Function(_Handle), void Function(_Handle)>('ClosePseudoConsole');

final _initAttrList = _k32
    .lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Uint32, ffi.Pointer<ffi.IntPtr>),
      int Function(ffi.Pointer<ffi.Void>, int, int, ffi.Pointer<ffi.IntPtr>)
    >('InitializeProcThreadAttributeList');

final _updateAttr = _k32
    .lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.IntPtr, ffi.Pointer<ffi.Void>, ffi.IntPtr, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>),
      int Function(ffi.Pointer<ffi.Void>, int, int, ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)
    >('UpdateProcThreadAttribute');

final _deleteAttrList = _k32.lookupFunction<ffi.Void Function(ffi.Pointer<ffi.Void>), void Function(ffi.Pointer<ffi.Void>)>('DeleteProcThreadAttributeList');

final _createProcessW = _k32
    .lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<Utf16>,
        ffi.Pointer<Utf16>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Void>,
        ffi.Int32,
        ffi.Uint32,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<Utf16>,
        ffi.Pointer<_StartupInfoExW>,
        ffi.Pointer<_ProcessInformation>,
      ),
      int Function(
        ffi.Pointer<Utf16>,
        ffi.Pointer<Utf16>,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Void>,
        int,
        int,
        ffi.Pointer<ffi.Void>,
        ffi.Pointer<Utf16>,
        ffi.Pointer<_StartupInfoExW>,
        ffi.Pointer<_ProcessInformation>,
      )
    >('CreateProcessW');

final _writeFile = _k32
    .lookupFunction<
      ffi.Int32 Function(_Handle, ffi.Pointer<ffi.Uint8>, ffi.Uint32, ffi.Pointer<ffi.Uint32>, ffi.Pointer<ffi.Void>),
      int Function(_Handle, ffi.Pointer<ffi.Uint8>, int, ffi.Pointer<ffi.Uint32>, ffi.Pointer<ffi.Void>)
    >('WriteFile');

final _closeHandle = _k32.lookupFunction<ffi.Int32 Function(_Handle), int Function(_Handle)>('CloseHandle');

final _getLastError = _k32.lookupFunction<ffi.Uint32 Function(), int Function()>('GetLastError');

final _terminateProcess = _k32.lookupFunction<ffi.Int32 Function(_Handle, ffi.Uint32), int Function(_Handle, int)>('TerminateProcess');

final _getExitCodeProcess = _k32.lookupFunction<ffi.Int32 Function(_Handle, ffi.Pointer<ffi.Uint32>), int Function(_Handle, ffi.Pointer<ffi.Uint32>)>(
  'GetExitCodeProcess',
);

// Constants — duplicated from <processthreadsapi.h> / <winbase.h>.
const int _kExtendedStartupinfoPresent = 0x00080000;
const int _kCreateUnicodeEnvironment = 0x00000400;
const int _kProcThreadAttributePseudoconsole = 0x00020016;
const int _kInfinite = 0xffffffff;
const int _kErrorBrokenPipe = 109;
const int _kStartfUseStdHandles = 0x00000100;

// -- WindowsPty -------------------------------------------------------------

/// A pseudo-terminal backed by ConPTY via Dart FFI.
class WindowsPty implements PtySession {
  WindowsPty._(this._hpc, this._hProcess, this._hThread, this._inWrite, this._outRead, this._conptyInRead, this._conptyOutWrite, this.pid);

  /// HPCON — owned until [close] / child exit.
  ffi.Pointer<ffi.Void> _hpc;
  final ffi.Pointer<ffi.Void> _hProcess;
  final ffi.Pointer<ffi.Void> _hThread;

  /// Our end of the child-stdin pipe (we write, ConPTY reads).
  final ffi.Pointer<ffi.Void> _inWrite;

  /// Our end of the child-stdout pipe (ConPTY writes, we read).
  final ffi.Pointer<ffi.Void> _outRead;

  /// The conpty-side pipe ends. Open for the HPCON's lifetime — the
  /// in-process conpty host uses them directly; released together
  /// with it in [_closeConsole]. Closing our `_conptyOutWrite` copy
  /// is also what finally breaks the pipe for the reader's EOF.
  final ffi.Pointer<ffi.Void> _conptyInRead;
  final ffi.Pointer<ffi.Void> _conptyOutWrite;

  @override
  final int pid;

  final _out = StreamController<Uint8List>.broadcast();
  bool _dead = false;
  bool _handlesReleased = false;

  Future<void>? _readerReady;
  Isolate? _readerIsolate;
  ReceivePort? _readerPort;
  Completer<void>? _readerExited;
  ReceivePort? _waiterPort;

  @override
  Stream<Uint8List> get output => _out.stream;

  @override
  bool get isClosed => _dead;

  /// Spawn a new ConPTY running [executable] with [arguments].
  ///
  /// [environment] must be the complete environment — it becomes the
  /// child's whole environment block. Merge `Platform.environment`
  /// before calling.
  static WindowsPty start({
    required String executable,
    List<String> arguments = const [],
    required int columns,
    required int rows,
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) {
    executable = resolveExecutable(executable, environment);

    // ---- Pipes + pseudo console ---------------------------------------
    final ha = calloc<_Handle>();
    final hb = calloc<_Handle>();
    if (_createPipe(ha, hb, ffi.nullptr, 0) == 0) {
      final err = _getLastError();
      calloc.free(ha);
      calloc.free(hb);
      throw PtyException('CreatePipe', 'stdin pipe creation failed', errno: err);
    }
    final inRead = ha.value;
    final inWrite = hb.value;
    if (_createPipe(ha, hb, ffi.nullptr, 0) == 0) {
      final err = _getLastError();
      _closeHandle(inRead);
      _closeHandle(inWrite);
      calloc.free(ha);
      calloc.free(hb);
      throw PtyException('CreatePipe', 'stdout pipe creation failed', errno: err);
    }
    final outRead = ha.value;
    final outWrite = hb.value;
    calloc.free(ha);
    calloc.free(hb);

    final size = calloc<_Coord>()
      ..ref.x = clampPtyDimension(columns)
      ..ref.y = clampPtyDimension(rows);
    final hpcOut = calloc<_Handle>();
    final hr = _createPseudoConsole(size.ref, inRead, outWrite, 0, hpcOut);
    calloc.free(size);
    if (hr != 0) {
      _closeHandle(inRead);
      _closeHandle(inWrite);
      _closeHandle(outRead);
      _closeHandle(outWrite);
      calloc.free(hpcOut);
      throw PtyException('CreatePseudoConsole', 'HRESULT 0x${(hr & 0xffffffff).toRadixString(16)}');
    }
    final hpc = hpcOut.value;
    calloc.free(hpcOut);
    // inRead / outWrite deliberately stay open — the in-process conpty
    // uses them for its whole lifetime (see the library docstring).
    // _closeConsole() releases them together with the HPCON.

    // ---- Attribute list (attaches the HPCON to the child) -------------
    final sizeOut = calloc<ffi.IntPtr>();
    _initAttrList(ffi.nullptr, 1, 0, sizeOut); // sizing call; "fails" with ERROR_INSUFFICIENT_BUFFER by design
    final attrBytes = sizeOut.value;
    final attrList = calloc<ffi.Uint8>(attrBytes).cast<ffi.Void>();
    void freeAttrs() {
      calloc.free(attrList);
      calloc.free(sizeOut);
    }

    void bail(String op, String message) {
      final err = _getLastError();
      freeAttrs();
      _closePseudoConsole(hpc);
      _closeHandle(inRead);
      _closeHandle(outWrite);
      _closeHandle(inWrite);
      _closeHandle(outRead);
      throw PtyException(op, message, errno: err);
    }

    if (_initAttrList(attrList, 1, 0, sizeOut) == 0) {
      bail('InitializeProcThreadAttributeList', 'attribute list init failed');
    }
    // The HPCON itself is lpValue — the attribute machinery stores the
    // pointer, it does NOT copy through it. Passing a pointer-to-slot
    // here "succeeds" but hands the child a garbage console and ConPTY
    // silently produces no output. (Matches the EchoCon sample.)
    if (_updateAttr(attrList, 0, _kProcThreadAttributePseudoconsole, hpc, ffi.sizeOf<_Handle>(), ffi.nullptr, ffi.nullptr) == 0) {
      _deleteAttrList(attrList);
      bail('UpdateProcThreadAttribute', 'attaching HPCON failed');
    }

    // ---- Marshal command line + environment + cwd ----------------------
    // App name stays null so CreateProcessW does its own first-token
    // parse (which also gives .bat/.cmd their cmd.exe host); the
    // executable is pre-resolved to an absolute path above so no PATH
    // ambiguity is left at this point.
    final cmdLine = [executable, ...arguments].map(quoteArg).join(' ').toNativeUtf16(allocator: malloc);
    final envBlock = composeEnvironmentBlock(environment).toNativeUtf16(allocator: malloc);
    final cwdN = workingDirectory == null ? ffi.nullptr : workingDirectory.toNativeUtf16(allocator: malloc);

    // STARTF_USESTDHANDLES with NULL std handles (calloc zeroes them):
    // the console subsystem then assigns conpty-backed handles at
    // client connect instead of leaking the parent's (docstring §3).
    final si = calloc<_StartupInfoExW>()
      ..ref.cb = ffi.sizeOf<_StartupInfoExW>()
      ..ref.dwFlags = _kStartfUseStdHandles
      ..ref.lpAttributeList = attrList;
    final pi = calloc<_ProcessInformation>();

    final ok = _createProcessW(
      ffi.nullptr,
      cmdLine,
      ffi.nullptr,
      ffi.nullptr,
      0,
      _kExtendedStartupinfoPresent | _kCreateUnicodeEnvironment,
      envBlock.cast(),
      cwdN.cast(),
      si,
      pi,
    );
    final spawnErr = ok == 0 ? _getLastError() : 0;

    _deleteAttrList(attrList);
    freeAttrs();
    malloc.free(cmdLine);
    malloc.free(envBlock);
    if (cwdN != ffi.nullptr) malloc.free(cwdN.cast<ffi.Uint8>());
    calloc.free(si);

    if (ok == 0) {
      calloc.free(pi);
      _closePseudoConsole(hpc);
      _closeHandle(inRead);
      _closeHandle(outWrite);
      _closeHandle(inWrite);
      _closeHandle(outRead);
      throw PtyException('CreateProcessW', 'spawn of $executable failed', errno: spawnErr);
    }

    final hProcess = pi.ref.hProcess;
    final hThread = pi.ref.hThread;
    final childPid = pi.ref.dwProcessId;
    calloc.free(pi);

    final pty = WindowsPty._(hpc, hProcess, hThread, inWrite, outRead, inRead, outWrite, childPid);
    pty._spawnReader();
    pty._spawnWaiter();
    return pty;
  }

  // -- I/O --------------------------------------------------------------

  void _spawnReader() {
    _readerReady = _spawnReaderAsync();
  }

  Future<void> _spawnReaderAsync() async {
    final rp = ReceivePort();
    _readerPort = rp;
    _readerExited = Completer<void>();
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
      _readerIsolate = await Isolate.spawn(_readLoop, (rp.sendPort, _outRead.address));
    } catch (e) {
      _dead = true;
      if (!_out.isClosed) _out.addError(PtyException('reader-spawn', '$e'));
      rp.close();
      _readerPort = null;
      if (!_readerExited!.isCompleted) _readerExited!.complete();
    }
  }

  /// Isolate entry — blocking ReadFile until the ConPTY side closes.
  static void _readLoop((SendPort, int) msg) {
    final (port, handleAddr) = msg;
    final handle = ffi.Pointer<ffi.Void>.fromAddress(handleAddr);
    final k32 = ffi.DynamicLibrary.open('kernel32.dll');
    final readFile = k32
        .lookupFunction<
          ffi.Int32 Function(_Handle, ffi.Pointer<ffi.Uint8>, ffi.Uint32, ffi.Pointer<ffi.Uint32>, ffi.Pointer<ffi.Void>),
          int Function(_Handle, ffi.Pointer<ffi.Uint8>, int, ffi.Pointer<ffi.Uint32>, ffi.Pointer<ffi.Void>)
        >('ReadFile');

    final buf = malloc<ffi.Uint8>(65536);
    final nRead = calloc<ffi.Uint32>();
    try {
      while (true) {
        // Blocks until data, broken pipe (ConPTY closed), or invalid
        // handle (close() already released it).
        final ok = readFile(handle, buf, 65536, nRead, ffi.nullptr);
        if (ok == 0) break;
        final n = nRead.value;
        if (n == 0) break;
        port.send(Uint8List.fromList(buf.asTypedList(n)));
      }
    } finally {
      calloc.free(nRead);
      malloc.free(buf);
    }
    port.send(null);
  }

  /// Watches for child exit so the pseudo console can be torn down —
  /// without ClosePseudoConsole the output pipe never breaks and the
  /// reader would block forever on an exited child.
  void _spawnWaiter() {
    final wp = ReceivePort();
    _waiterPort = wp;
    wp.listen((_) {
      wp.close();
      _waiterPort = null;
      _closeConsole();
    });
    Isolate.spawn(_waitLoop, (wp.sendPort, _hProcess.address)).catchError((Object e) {
      // Fall back to close()-driven teardown; the child just won't be
      // auto-reaped on self-exit.
      wp.close();
      _waiterPort = null;
      return Isolate.current; // satisfies the Future<Isolate> type; unused
    });
  }

  static void _waitLoop((SendPort, int) msg) {
    final (port, handleAddr) = msg;
    final k32 = ffi.DynamicLibrary.open('kernel32.dll');
    final wait = k32.lookupFunction<ffi.Uint32 Function(_Handle, ffi.Uint32), int Function(_Handle, int)>('WaitForSingleObject');
    wait(ffi.Pointer<ffi.Void>.fromAddress(handleAddr), _kInfinite);
    port.send(null);
  }

  @override
  int write(List<int> bytes) {
    if (_dead || bytes.isEmpty) return 0;
    final buf = malloc<ffi.Uint8>(bytes.length);
    final nWritten = calloc<ffi.Uint32>();
    try {
      for (var i = 0; i < bytes.length; i++) {
        buf[i] = bytes[i];
      }
      var written = 0;
      while (written < bytes.length) {
        final ok = _writeFile(_inWrite, buf + written, bytes.length - written, nWritten, ffi.nullptr);
        if (ok == 0) {
          final err = _getLastError();
          if (err == _kErrorBrokenPipe) _dead = true;
          throw PtyException('WriteFile', 'write to ConPTY failed', errno: err);
        }
        if (nWritten.value == 0) break;
        written += nWritten.value;
      }
      return written;
    } finally {
      malloc.free(buf);
      calloc.free(nWritten);
    }
  }

  @override
  void resize({required int cols, required int rows}) {
    if (_dead || _hpc == ffi.nullptr) return;
    final size = calloc<_Coord>()
      ..ref.x = clampPtyDimension(cols)
      ..ref.y = clampPtyDimension(rows);
    _resizePseudoConsole(_hpc, size.ref);
    calloc.free(size);
  }

  /// Windows has no signals — any [signal] terminates the child.
  @override
  bool kill([int? signal]) {
    if (_dead || _handlesReleased) return false;
    return _terminateProcess(_hProcess, 1) != 0;
  }

  /// Close the HPCON and the conpty-side pipe ends, once. With every
  /// write end of the output pipe gone the reader drains what's left
  /// and EOFs.
  void _closeConsole() {
    final hpc = _hpc;
    if (hpc == ffi.nullptr) return;
    _hpc = ffi.nullptr;
    _closePseudoConsole(hpc);
    _closeHandle(_conptyInRead);
    _closeHandle(_conptyOutWrite);
  }

  void _reap() {
    if (_dead) return;
    _dead = true;
    _closeConsole();
    _releaseHandles();
  }

  void _releaseHandles() {
    if (_handlesReleased) return;
    _handlesReleased = true;
    final code = calloc<ffi.Uint32>();
    _getExitCodeProcess(_hProcess, code);
    calloc.free(code);
    _closeHandle(_inWrite);
    _closeHandle(_outRead);
    _closeHandle(_hThread);
    _closeHandle(_hProcess);
  }

  /// Kill the child and release resources.
  ///
  /// Order matters, mirroring the POSIX close(): terminate the child,
  /// break the output pipe (ClosePseudoConsole), wait for the reader
  /// to EOF so nothing touches the handles after we close them.
  @override
  Future<void> close() async {
    if (_dead) return;
    _dead = true;

    await _readerReady;

    _terminateProcess(_hProcess, 1);
    _closeConsole();

    if (_readerExited != null) {
      await _readerExited!.future.timeout(const Duration(milliseconds: 500), onTimeout: () {});
    }

    _readerIsolate?.kill(priority: Isolate.immediate);
    _readerIsolate = null;
    _readerPort?.close();
    _readerPort = null;
    _waiterPort?.close();
    _waiterPort = null;

    _releaseHandles();
    if (!_out.isClosed) await _out.close();
  }

  // -- spawn helpers ------------------------------------------------------

  /// Resolve a bare command name against the environment's PATH +
  /// PATHEXT (mirrors what the POSIX side does with `:`-split PATH —
  /// visible/debuggable resolution instead of CreateProcess magic).
  ///
  /// [exists] overrides the on-disk probe so the resolution logic is
  /// unit-testable off-Windows; production passes the default. Public for
  /// that reason — not part of the backend's external contract.
  static String resolveExecutable(String executable, Map<String, String> environment, {bool Function(String path)? exists}) {
    final fileExists = exists ?? ((String path) => File(path).existsSync());
    final pathext = (environment['PATHEXT'] ?? Platform.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD').split(';').where((e) => e.isNotEmpty).toList();
    final hasKnownExt = pathext.any((e) => executable.toLowerCase().endsWith(e.toLowerCase()));

    Iterable<String> candidates(String base) sync* {
      if (hasKnownExt) {
        yield base;
      } else {
        yield base;
        for (final ext in pathext) {
          yield '$base$ext';
        }
      }
    }

    if (executable.contains('\\') || executable.contains('/')) {
      for (final c in candidates(executable)) {
        if (fileExists(c)) return c;
      }
      return executable;
    }
    final path = environment['PATH'] ?? Platform.environment['PATH'] ?? '';
    for (final dir in path.split(';')) {
      if (dir.isEmpty) continue;
      for (final c in candidates('$dir\\$executable')) {
        if (fileExists(c)) return c;
      }
    }
    return executable;
  }

  /// Quote one argument per MSVCRT command-line parsing rules. Public so the
  /// quoting rules can be unit-tested off-Windows; not an external contract.
  static String quoteArg(String arg) {
    if (arg.isNotEmpty && !arg.contains(RegExp(r'[ \t"\n\v]'))) return arg;
    final b = StringBuffer('"');
    var backslashes = 0;
    for (final ch in arg.runes) {
      final c = String.fromCharCode(ch);
      if (c == r'\') {
        backslashes++;
        continue;
      }
      if (c == '"') {
        b.write(r'\' * (backslashes * 2 + 1));
        b.write('"');
        backslashes = 0;
        continue;
      }
      if (backslashes > 0) {
        b.write(r'\' * backslashes);
        backslashes = 0;
      }
      b.write(c);
    }
    b.write(r'\' * (backslashes * 2));
    b.write('"');
    return b.toString();
  }

  /// Compose the body of a CREATE_UNICODE_ENVIRONMENT block: `K=V\0...\0`
  /// with one trailing NUL, entries sorted case-insensitively by key per
  /// CreateProcess docs. The caller nativizes via `toNativeUtf16`, whose own
  /// terminator completes the required double-NUL ending (which also keeps an
  /// empty environment block valid). Public for unit testing.
  static String composeEnvironmentBlock(Map<String, String> environment) {
    final entries = environment.entries.toList()..sort((a, b) => a.key.toUpperCase().compareTo(b.key.toUpperCase()));
    // NUL via fromCharCode — an inline NUL escape in a string literal
    // is invisible in review and trips up text tooling.
    final nul = String.fromCharCode(0);
    final joined = entries.map((e) => '${e.key}=${e.value}$nul').join();
    return '$joined$nul';
  }
}
