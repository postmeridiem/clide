/// FFI fd-inheritance probe for the testmode harness (T-438 web fence, D-100).
///
/// Desktop-only — [test_app.dart] selects [fd_check_stub.dart] on web so the
/// `dart:ffi` / `package:ffi` / libc imports stay out of the wasm graph.
library;

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as pkg_ffi;

import 'src/pty/ffi/libc.dart' as libc;

/// Probe whether `Process.start` inherits socket fds (the macOS question the
/// testmode harness answers). Returns a human-readable result line.
Future<String> fdInheritanceCheck() async {
  final sv = pkg_ffi.calloc<ffi.Int32>(2);
  libc.socketpair(1, 1, 0, sv); // AF_UNIX, SOCK_STREAM
  final parent = sv[0];
  final child = sv[1];
  pkg_ffi.calloc.free(sv);
  final proc = await Process.start('/tmp/checkfd', [], environment: {...Platform.environment, 'PTYC_SOCK_FD': '$child'});
  final stderr = await proc.stderr.transform(utf8.decoder).join();
  final exit = await proc.exitCode;
  libc.close(parent);
  libc.close(child);
  return 'exit=$exit stderr=${stderr.trim()}';
}
