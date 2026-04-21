/// IPC wire schema version.
///
/// Bumped when the envelope shape changes in a non-backwards-compatible
/// way. The daemon and app both carry this constant and reject messages
/// whose `v:` doesn't match.
const int ipcSchemaVersion = 1;

abstract class IpcExitCode {
  static const int ok = 0;
  static const int userError = 1;
  static const int toolError = 2;
  static const int notFound = 3;
  static const int conflict = 4;
}

abstract class IpcErrorKind {
  static const String userError = 'user_error';
  static const String toolError = 'tool_error';
  static const String notFound = 'not_found';
  static const String conflict = 'conflict';
}
