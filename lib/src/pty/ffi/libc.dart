/// Raw FFI bindings to the libc functions the PTY wrapper needs.
///
/// `dart:io` covers neither `socketpair(2)`, `recvmsg(2)` with ancillary
/// data, nor read/write on arbitrary file descriptors — the three
/// things the [`ptyc`](../../../ptyc/README.md) fd-transfer protocol
/// requires. FFI is the minimum tool for the job.
///
/// Linux + macOS only for now. Windows is covered by platform checks
/// higher up; when Windows support lands it'll need a parallel binding
/// set against the Win32 API (named pipes instead of unix sockets).
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart' as pkg_ffi;

// ---------------------------------------------------------------------------
// Constants (POSIX / Linux)
// ---------------------------------------------------------------------------

const int afUnix = 1;
const int sockStream = 1;

final int solSocket = Platform.isMacOS ? 0xffff : 1;
final int scmRights = Platform.isMacOS ? 0x01 : 1;

const int fIoNonblock = 0x800; // O_NONBLOCK — 04000 octal
const int fGetFl = 3;
const int fSetFl = 4;

const int tiocswinsz = 0x5414; // Linux x86_64; macOS differs

// ---------------------------------------------------------------------------
// Typedefs
// ---------------------------------------------------------------------------

typedef _SocketpairC = ffi.Int32 Function(
  ffi.Int32 domain,
  ffi.Int32 type,
  ffi.Int32 protocol,
  ffi.Pointer<ffi.Int32> sv,
);
typedef _SocketpairD = int Function(
  int domain,
  int type,
  int protocol,
  ffi.Pointer<ffi.Int32> sv,
);

typedef _RecvmsgC = ffi.IntPtr Function(
  ffi.Int32 sockfd,
  ffi.Pointer<Msghdr> msg,
  ffi.Int32 flags,
);
typedef _RecvmsgD = int Function(
  int sockfd,
  ffi.Pointer<Msghdr> msg,
  int flags,
);

typedef _ReadC = ffi.IntPtr Function(
  ffi.Int32 fd,
  ffi.Pointer<ffi.Uint8> buf,
  ffi.IntPtr count,
);
typedef _ReadD = int Function(
  int fd,
  ffi.Pointer<ffi.Uint8> buf,
  int count,
);

typedef _WriteC = ffi.IntPtr Function(
  ffi.Int32 fd,
  ffi.Pointer<ffi.Uint8> buf,
  ffi.IntPtr count,
);
typedef _WriteD = int Function(
  int fd,
  ffi.Pointer<ffi.Uint8> buf,
  int count,
);

typedef _CloseC = ffi.Int32 Function(ffi.Int32 fd);
typedef _CloseD = int Function(int fd);

typedef _IoctlPtrC = ffi.Int32 Function(
  ffi.Int32 fd,
  ffi.UnsignedLong request,
  ffi.Pointer<Winsize> argp,
);
typedef _IoctlPtrD = int Function(
  int fd,
  int request,
  ffi.Pointer<Winsize> argp,
);

typedef _FcntlIntC = ffi.Int32 Function(
  ffi.Int32 fd,
  ffi.Int32 cmd,
  ffi.Int32 arg,
);
typedef _FcntlIntD = int Function(int fd, int cmd, int arg);

typedef _ErrnoLocationC = ffi.Pointer<ffi.Int32> Function();
typedef _ErrnoLocationD = ffi.Pointer<ffi.Int32> Function();

// ---------------------------------------------------------------------------
// Native structs
// ---------------------------------------------------------------------------

/// POSIX `struct iovec`.
final class Iovec extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> iov_base;
  @ffi.IntPtr()
  external int iov_len;
}

/// POSIX `struct msghdr`. Field layout matches Linux/glibc; macOS is
/// byte-compatible here.
final class Msghdr extends ffi.Struct {
  external ffi.Pointer<ffi.Void> msg_name;
  @ffi.Uint32()
  external int msg_namelen;
  external ffi.Pointer<Iovec> msg_iov;
  @ffi.IntPtr()
  external int msg_iovlen;
  external ffi.Pointer<ffi.Void> msg_control;
  @ffi.IntPtr()
  external int msg_controllen;
  @ffi.Int32()
  external int msg_flags;
}

/// POSIX `struct cmsghdr` prefix. We treat the rest of the control
/// buffer as a raw byte region and compute offsets by hand.
// On Linux, cmsg_len is size_t (8 bytes on 64-bit).
// On macOS, cmsg_len is socklen_t (4 bytes, always).
// Use platform-specific structs.
final class CmsghdrLinux extends ffi.Struct {
  @ffi.IntPtr()
  external int cmsg_len;
  @ffi.Int32()
  external int cmsg_level;
  @ffi.Int32()
  external int cmsg_type;
}

final class CmsghdrDarwin extends ffi.Struct {
  @ffi.Uint32()
  external int cmsg_len;
  @ffi.Int32()
  external int cmsg_level;
  @ffi.Int32()
  external int cmsg_type;
}

// Alias for backward compatibility — callers use Cmsghdr.
typedef Cmsghdr = CmsghdrLinux;

/// POSIX `struct winsize` for `TIOCSWINSZ`.
final class Winsize extends ffi.Struct {
  @ffi.Uint16()
  external int ws_row;
  @ffi.Uint16()
  external int ws_col;
  @ffi.Uint16()
  external int ws_xpixel;
  @ffi.Uint16()
  external int ws_ypixel;
}

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

final _SocketpairD socketpair =
    _libc.lookupFunction<_SocketpairC, _SocketpairD>('socketpair');

final _RecvmsgD recvmsg =
    _libc.lookupFunction<_RecvmsgC, _RecvmsgD>('recvmsg');

final _ReadD read = _libc.lookupFunction<_ReadC, _ReadD>('read');

final _WriteD write = _libc.lookupFunction<_WriteC, _WriteD>('write');

final _CloseD close = _libc.lookupFunction<_CloseC, _CloseD>('close');

final _IoctlPtrD ioctlWinsize =
    _libc.lookupFunction<_IoctlPtrC, _IoctlPtrD>('ioctl');

final _FcntlIntD fcntlInt =
    _libc.lookupFunction<_FcntlIntC, _FcntlIntD>('fcntl');

/// Resolve `errno` through the platform-appropriate thread-local
/// accessor. glibc exposes `__errno_location`, musl the same, macOS
/// uses `__error`.
int get errno {
  try {
    final fn = _libc.lookupFunction<_ErrnoLocationC, _ErrnoLocationD>(
      '__errno_location',
    );
    return fn().value;
  } on ArgumentError {
    // Fall through to macOS-style.
  }
  final fn = _libc.lookupFunction<_ErrnoLocationC, _ErrnoLocationD>(
    '__error',
  );
  return fn().value;
}

// ---------------------------------------------------------------------------
// Convenience — scoped allocations
// ---------------------------------------------------------------------------

/// Allocate a typed native block, run [action], free. Frees even if
/// [action] throws.
T withBuffer<T>(int bytes, T Function(ffi.Pointer<ffi.Uint8>) action) {
  final p = pkg_ffi.calloc<ffi.Uint8>(bytes);
  try {
    return action(p);
  } finally {
    pkg_ffi.calloc.free(p);
  }
}

/// Set [fd] non-blocking. Returns whether the flag was changed.
bool setNonBlocking(int fd) {
  final flags = fcntlInt(fd, fGetFl, 0);
  if (flags < 0) return false;
  if ((flags & fIoNonblock) != 0) return false;
  fcntlInt(fd, fSetFl, flags | fIoNonblock);
  return true;
}

/// Apply `TIOCSWINSZ` to the master PTY fd.
int setWinsize(int fd, int cols, int rows) {
  final ws = pkg_ffi.calloc<Winsize>();
  try {
    ws.ref.ws_col = cols;
    ws.ref.ws_row = rows;
    return ioctlWinsize(fd, tiocswinsz, ws);
  } finally {
    pkg_ffi.calloc.free(ws);
  }
}
