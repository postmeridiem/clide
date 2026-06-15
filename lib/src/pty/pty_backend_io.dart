/// Desktop PTY backend selection (T-438 web fence, D-100).
///
/// [pty_session.dart] imports this only when `dart.library.ffi` is available;
/// the web build gets [pty_backend_web.dart] instead, so the FFI-backed
/// [NativePty]/[WindowsPty] never enter the wasm compile graph.
library;

import 'dart:io' show Platform;

import 'native_pty.dart';
import 'pty_log.dart';
import 'pty_session.dart';
import 'windows_pty.dart';

/// Spawn a PTY child using the platform backend — ConPTY on Windows
/// ([WindowsPty]), `posix_openpt` + `posix_spawn` elsewhere ([NativePty]).
PtySession startPtyBackend({
  required String executable,
  List<String> arguments = const [],
  required int columns,
  required int rows,
  String? workingDirectory,
  Map<String, String> environment = const {},
  PtyLog log = PtyLog.none,
}) {
  if (Platform.isWindows) {
    return WindowsPty.start(
      executable: executable,
      arguments: arguments,
      columns: columns,
      rows: rows,
      workingDirectory: workingDirectory,
      environment: environment,
      log: log,
    );
  }
  return NativePty.start(
    executable: executable,
    arguments: arguments,
    columns: columns,
    rows: rows,
    workingDirectory: workingDirectory,
    environment: environment,
    log: log,
  );
}
