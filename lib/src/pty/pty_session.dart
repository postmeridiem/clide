/// Platform-neutral PTY session contract + factory.
///
/// The pane registry (and anything else that spawns PTY children)
/// programs against [PtySession]; [startPtySession] picks the
/// platform backend — `posix_openpt` + `posix_spawn` on Linux/macOS
/// ([NativePty]), ConPTY on Windows ([WindowsPty]). Both backends
/// share the same lifecycle: spawn → byte stream out → write/resize
/// in → EOF on child exit → close() reaps.
library;

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'native_pty.dart';
import 'windows_pty.dart';

abstract interface class PtySession {
  /// OS process id of the spawned child.
  int get pid;

  /// Byte stream of data produced by the child.
  Stream<Uint8List> get output;

  bool get isClosed;

  /// Write bytes to the child's stdin. Returns the bytes written.
  int write(List<int> bytes);

  /// Resize the terminal.
  void resize({required int cols, required int rows});

  /// Signal the child. [signal] is a POSIX signal number; backends
  /// without signals (Windows) treat any value as terminate. Null
  /// means the backend's default hang-up behaviour.
  bool kill([int? signal]);

  /// Kill the child and release resources.
  Future<void> close();
}

/// Spawn a child under a PTY using the platform backend.
///
/// [environment] must be the complete environment — it goes straight
/// to the child. Merge `Platform.environment` before calling.
PtySession startPtySession({
  required String executable,
  List<String> arguments = const [],
  required int columns,
  required int rows,
  String? workingDirectory,
  Map<String, String> environment = const {},
}) {
  if (Platform.isWindows) {
    return WindowsPty.start(
      executable: executable,
      arguments: arguments,
      columns: columns,
      rows: rows,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
  return NativePty.start(
    executable: executable,
    arguments: arguments,
    columns: columns,
    rows: rows,
    workingDirectory: workingDirectory,
    environment: environment,
  );
}
