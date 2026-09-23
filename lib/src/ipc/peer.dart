/// The pid of the process at the other end of a Unix-domain socket (D-115).
///
/// Linux: `SO_PEERCRED` (`struct ucred`, pid first). macOS: `LOCAL_PEERPID`.
/// Elsewhere, or when the kernel won't say, null — the escalation check then
/// treats the caller as an agent rather than trust it.
library;

import 'dart:io';
import 'dart:typed_data';

// <sys/socket.h>: SOL_SOCKET / SO_PEERCRED on Linux; SOL_LOCAL /
// LOCAL_PEERPID on macOS.
const int _kSolSocket = 1;
const int _kSoPeercred = 17;
const int _kSolLocal = 0;
const int _kLocalPeerpid = 2;

int? peerPid(Socket socket) {
  try {
    if (Platform.isLinux) {
      final raw = socket.getRawOption(RawSocketOption(_kSolSocket, _kSoPeercred, Uint8List(12)));
      return _positive(ByteData.sublistView(raw).getInt32(0, Endian.host));
    }
    if (Platform.isMacOS) {
      final raw = socket.getRawOption(RawSocketOption(_kSolLocal, _kLocalPeerpid, Uint8List(4)));
      return _positive(ByteData.sublistView(raw).getInt32(0, Endian.host));
    }
  } on Object {
    // Not a unix socket, or the platform refused: unknown.
  }
  return null;
}

int? _positive(int v) => v > 0 ? v : null;
