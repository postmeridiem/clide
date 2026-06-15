// coverage:ignore-file
//
// Windows-only resource sampler for the watchdog (T-435). All of it is Win32
// FFI through kernel32/psapi, so it cannot execute on the Linux CI runner that
// produces the coverage report (PosixResourceSampler is used there). It is
// validated only when the app actually runs on Windows — which is acceptable
// because it is a DIAGNOSTIC that reads, never mutates, and is exhaustively
// defensive: every probe is wrapped so any failure yields a `-1` field rather
// than an exception, and the toolhelp snapshot handle is always closed. A
// missing sample is fine; a sampler that throws or leaks would not be.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show ProcessInfo;

import 'package:ffi/ffi.dart';

import 'watchdog.dart';

const int _kTh32csSnapprocess = 0x00000002;

final ffi.DynamicLibrary _k32 = ffi.DynamicLibrary.open('kernel32.dll');
final ffi.DynamicLibrary _psapi = ffi.DynamicLibrary.open('psapi.dll');

final _getCurrentProcess = _k32.lookupFunction<ffi.Pointer<ffi.Void> Function(), ffi.Pointer<ffi.Void> Function()>('GetCurrentProcess');
final _getCurrentProcessId = _k32.lookupFunction<ffi.Uint32 Function(), int Function()>('GetCurrentProcessId');
final _createToolhelp32Snapshot = _k32.lookupFunction<ffi.Pointer<ffi.Void> Function(ffi.Uint32, ffi.Uint32), ffi.Pointer<ffi.Void> Function(int, int)>(
  'CreateToolhelp32Snapshot',
);
final _process32First = _k32
    .lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_ProcessEntry32>), int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_ProcessEntry32>)>(
      'Process32First',
    );
final _process32Next = _k32
    .lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_ProcessEntry32>), int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<_ProcessEntry32>)>(
      'Process32Next',
    );
final _closeHandle = _k32.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>('CloseHandle');
final _getProcessHandleCount = _psapi
    .lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Uint32>), int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Uint32>)>(
      'GetProcessHandleCount',
    );

/// Win32 `PROCESSENTRY32` (ANSI). szExeFile is `CHAR[MAX_PATH]`.
final class _ProcessEntry32 extends ffi.Struct {
  @ffi.Uint32()
  external int dwSize;
  @ffi.Uint32()
  external int cntUsage;
  @ffi.Uint32()
  external int th32ProcessID;
  @ffi.IntPtr()
  external int th32DefaultHeapID;
  @ffi.Uint32()
  external int th32ModuleID;
  @ffi.Uint32()
  external int cntThreads;
  @ffi.Uint32()
  external int th32ParentProcessID;
  @ffi.Int32()
  external int pcPriClassBase;
  @ffi.Uint32()
  external int dwFlags;
  @ffi.Array<ffi.Uint8>(260)
  external ffi.Array<ffi.Uint8> szExeFile;
}

/// Samples the current process via a single toolhelp snapshot (thread count +
/// ConPTY-host children) plus GetProcessHandleCount and ProcessInfo.currentRss.
class WindowsResourceSampler implements ResourceSampler {
  @override
  ResourceSample sample() {
    final (threads, children) = _snapshotThreadsAndHosts();
    return ResourceSample(threads: threads, children: children, handles: _handleCount(), rssBytes: _rss());
  }

  /// One toolhelp snapshot → (this process's thread count, count of its direct
  /// conhost/OpenConsole children). Both `-1`/unavailable on any failure.
  (int, int) _snapshotThreadsAndHosts() {
    var threads = -1;
    var conhosts = 0;
    var sawAny = false;
    ffi.Pointer<ffi.Void>? snap;
    final entry = calloc<_ProcessEntry32>();
    try {
      final myPid = _getCurrentProcessId();
      snap = _createToolhelp32Snapshot(_kTh32csSnapprocess, 0);
      entry.ref.dwSize = ffi.sizeOf<_ProcessEntry32>();
      var ok = _process32First(snap, entry);
      while (ok != 0) {
        sawAny = true;
        if (entry.ref.th32ProcessID == myPid) threads = entry.ref.cntThreads;
        if (entry.ref.th32ParentProcessID == myPid) {
          final name = _exeName(entry.ref.szExeFile).toLowerCase();
          if (name == 'conhost.exe' || name == 'openconsole.exe') conhosts++;
        }
        ok = _process32Next(snap, entry);
      }
    } catch (_) {
      // any FFI failure → unavailable, not a crash
    } finally {
      if (snap != null) {
        try {
          _closeHandle(snap);
        } catch (_) {}
      }
      calloc.free(entry);
    }
    return (threads, sawAny ? conhosts : -1);
  }

  int _handleCount() {
    final out = calloc<ffi.Uint32>();
    try {
      final ok = _getProcessHandleCount(_getCurrentProcess(), out);
      return ok != 0 ? out.value : -1;
    } catch (_) {
      return -1;
    } finally {
      calloc.free(out);
    }
  }

  int _rss() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return -1;
    }
  }

  String _exeName(ffi.Array<ffi.Uint8> arr) {
    final bytes = <int>[];
    for (var i = 0; i < 260; i++) {
      final b = arr[i];
      if (b == 0) break;
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }
}
