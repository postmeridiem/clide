/// Error type for the PTY subsystem. Flutter-free — `dart:io`'s
/// `OSError` + `ProcessException` don't quite fit (we're a mix of
/// syscall-level and subprocess-level failures), and we can't pull
/// `PlatformException` from `package:flutter/services.dart` since the
/// core library stays Flutter-free per D-005.
library;

/// A PTY operation failed. [op] identifies the step (`recvmsg`,
/// `socketpair`, `ptyc`, etc.); [errno] is POSIX errno when the
/// failure came from a syscall, otherwise `null`.
class PtyException implements Exception {
  const PtyException(this.op, this.message, {this.errno});

  final String op;
  final String message;
  final int? errno;

  @override
  String toString() {
    final suffix = errno != null ? ' (errno=$errno)' : '';
    return 'PtyException($op): $message$suffix';
  }
}
