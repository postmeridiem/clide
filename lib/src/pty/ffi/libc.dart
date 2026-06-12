/// Raw FFI bindings to the libc symbols the PTY layer still needs.
///
/// `dart:io` doesn't expose `socketpair`, `close` on raw fds, `errno`,
/// or the `poll()` event bits — FFI is the minimum tool for the job.
/// The fd-passing-era surface that used to live here (recvmsg + the
/// msghdr/cmsghdr/iovec structs, read/write, ioctl/winsize, fcntl
/// non-blocking helpers) had no callers since the daemon dissolution
/// (D-56) and was removed in the T-385 dead-code sweep; `NativePty`
/// binds its own symbols.
///
/// Linux + macOS only for now. Windows is covered by platform checks
/// higher up; when Windows support lands it'll need a parallel binding
/// set against the Win32 API (named pipes instead of unix sockets).
library;

// File-wide analyzer exception, with reason — see CLAUDE.md
// no-lint-suppression rule. This is the textbook FFI-binding case
// where the lint works against the file's purpose:
//
// * `library_private_types_in_public_api` — the C / Dart function-
//   signature typedefs (`_SocketpairC`, `_SocketpairD`, etc.) are
//   implementation details consumed only by the public
//   `lookupFunction<...>()` calls in this file. Promoting them to
//   public would just add noise to the import surface.
//
// ignore_for_file: library_private_types_in_public_api

import 'dart:ffi' as ffi;

// ---------------------------------------------------------------------------
// Constants (POSIX — identical numeric values on Linux + macOS for the
// entries we touch)
// ---------------------------------------------------------------------------

// poll() event bits.
const int pollin = 0x0001;
const int pollerr = 0x0008;
const int pollhup = 0x0010;
const int pollnval = 0x0020;
const int pollAnyErr = pollerr | pollhup | pollnval;

// Signal numbers used from the PTY layer.
const int sighup = 1;
const int sigwinch = 28;

// ---------------------------------------------------------------------------
// Typedefs
// ---------------------------------------------------------------------------

typedef _SocketpairC = ffi.Int32 Function(ffi.Int32 domain, ffi.Int32 type, ffi.Int32 protocol, ffi.Pointer<ffi.Int32> sv);
typedef _SocketpairD = int Function(int domain, int type, int protocol, ffi.Pointer<ffi.Int32> sv);

typedef _CloseC = ffi.Int32 Function(ffi.Int32 fd);
typedef _CloseD = int Function(int fd);

typedef _ErrnoLocationC = ffi.Pointer<ffi.Int32> Function();
typedef _ErrnoLocationD = ffi.Pointer<ffi.Int32> Function();

// ---------------------------------------------------------------------------
// Library handle + lazy-resolved function pointers
// ---------------------------------------------------------------------------

final ffi.DynamicLibrary _libc = _openLibc();

ffi.DynamicLibrary _openLibc() {
  // `DynamicLibrary.process()` resolves against symbols already linked
  // into the host process, which covers both Linux (libc symbols are
  // always available via ld.so) and macOS.
  return ffi.DynamicLibrary.process();
}

final _SocketpairD socketpair = _libc.lookupFunction<_SocketpairC, _SocketpairD>('socketpair');

final _CloseD close = _libc.lookupFunction<_CloseC, _CloseD>('close');

/// Resolve `errno` through the platform-appropriate thread-local
/// accessor. glibc exposes `__errno_location`, musl the same, macOS
/// uses `__error`.
int get errno {
  try {
    final fn = _libc.lookupFunction<_ErrnoLocationC, _ErrnoLocationD>('__errno_location');
    return fn().value;
  } on ArgumentError {
    // Fall through to macOS-style.
  }
  final fn = _libc.lookupFunction<_ErrnoLocationC, _ErrnoLocationD>('__error');
  return fn().value;
}
