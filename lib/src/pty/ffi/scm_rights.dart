/// Receive a single file descriptor over a unix socket via
/// `SCM_RIGHTS` ancillary data.
///
/// Pairs with `ptyc`'s `send_fd()`: the peer sends one byte of payload
/// plus the fd in cmsg; this function reads both and returns the fd.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart' as pkg_ffi;

import '../errors.dart';
import 'libc.dart' as libc;

/// Blocks on [socketFd] waiting for a single-byte payload carrying a
/// fd over `SCM_RIGHTS`. Returns the received fd on success.
///
/// Throws a [PlatformException] if `recvmsg` fails or the peer sends
/// no ancillary data.
int recvFd(int socketFd) {
  // Layout: one-byte payload buffer + CMSG_SPACE(sizeof(int)) control
  // buffer. `CMSG_SPACE` is just `ALIGN(sizeof(cmsghdr)) + ALIGN(data)`
  // — for a single int that's 16 + 4 rounded up to 8 = 24 on 64-bit,
  // but we over-allocate to 32 to be safe across platforms.
  const payloadLen = 1;
  const controlLen = 32;

  final payload = pkg_ffi.calloc<ffi.Uint8>(payloadLen);
  final control = pkg_ffi.calloc<ffi.Uint8>(controlLen);
  final iov = pkg_ffi.calloc<libc.Iovec>();
  final msg = pkg_ffi.calloc<libc.Msghdr>();

  try {
    iov.ref.iov_base = payload;
    iov.ref.iov_len = payloadLen;

    msg.ref.msg_name = ffi.nullptr;
    msg.ref.msg_namelen = 0;
    msg.ref.msg_iov = iov;
    msg.ref.msg_iovlen = 1;
    msg.ref.msg_control = control.cast();
    msg.ref.msg_controllen = controlLen;
    msg.ref.msg_flags = 0;

    int received;
    while (true) {
      received = libc.recvmsg(socketFd, msg, 0);
      if (received >= 0) break;
      final err = libc.errno;
      if (err == 4 /* EINTR */) continue;
      throw PtyException('recvmsg', 'recvmsg failed', errno: err);
    }

    if (received == 0 || msg.ref.msg_controllen < 16) {
      throw const PtyException(
        'recvmsg',
        'peer closed without sending ancillary data',
      );
    }

    // Parse the first cmsghdr out of the control buffer. On macOS,
    // cmsg_len is socklen_t (4 bytes); on Linux it's size_t (8 bytes).
    int cmsgLevel, cmsgType, dataOffset;
    if (Platform.isMacOS) {
      final hdr = control.cast<libc.CmsghdrDarwin>().ref;
      cmsgLevel = hdr.cmsg_level;
      cmsgType = hdr.cmsg_type;
      dataOffset = ffi.sizeOf<libc.CmsghdrDarwin>();
    } else {
      final hdr = control.cast<libc.CmsghdrLinux>().ref;
      cmsgLevel = hdr.cmsg_level;
      cmsgType = hdr.cmsg_type;
      dataOffset = ffi.sizeOf<libc.CmsghdrLinux>();
    }

    if (cmsgLevel != libc.solSocket || cmsgType != libc.scmRights) {
      throw PtyException(
        'recvmsg',
        'unexpected cmsg level=$cmsgLevel type=$cmsgType',
      );
    }

    final fdPtr = (control + dataOffset).cast<ffi.Int32>();
    return fdPtr.value;
  } finally {
    pkg_ffi.calloc.free(msg);
    pkg_ffi.calloc.free(iov);
    pkg_ffi.calloc.free(control);
    pkg_ffi.calloc.free(payload);
  }
}
