/// Web stub for the PTY backend (T-438 web fence, D-100).
///
/// The web/WASM target has no PTY — spawning a child under a pseudo-terminal is
/// desktop-only (it needs `dart:ffi`). [pty_session.dart] selects this when
/// `dart.library.ffi` is absent, keeping [NativePty]/[WindowsPty] out of the
/// wasm graph. The web build is a UI/e2e surface, not a functional desktop
/// replacement, so a terminal is never spawned there; calling this is a bug.
library;

import 'pty_log.dart';
import 'pty_session.dart';

PtySession startPtyBackend({
  required String executable,
  List<String> arguments = const [],
  required int columns,
  required int rows,
  String? workingDirectory,
  Map<String, String> environment = const {},
  PtyLog log = PtyLog.none,
}) => throw UnsupportedError('PTY sessions are not available on the web target.');
