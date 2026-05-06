/// Map POSIX errno values to IPC error envelopes with actionable
/// messages. Used by command handlers that wrap syscall-backed work
/// (PTY spawn, file open) so the client can distinguish "binary not
/// found" from "permission denied" from "system limit hit" instead
/// of seeing the same generic `tool_error: foo failed`.
library;

import 'envelope.dart';
import 'schema_v1.dart';

/// Selected POSIX errno values we map specially. Others fall through
/// to a generic toolError. Values match Linux glibc and macOS Darwin
/// (the two platforms that share the same numbers for these entries).
abstract class PosixErrno {
  static const int eperm = 1;
  static const int enoent = 2;
  static const int esrch = 3;
  static const int eio = 5;
  static const int ebadf = 9;
  static const int eagain = 11;
  static const int enomem = 12;
  static const int eacces = 13;
  static const int eexist = 17;
  static const int enotdir = 20;
  static const int eisdir = 21;
  static const int emfile = 24;
  static const int enfile = 23;
  static const int epipe = 32;
}

/// Build an [IpcError] from a POSIX [errno] for an operation [op]
/// (e.g. `pane.spawn`, `editor.open`) on optional [target] (a path,
/// command name, etc.). The returned error uses `notFound`,
/// `userError`, or `toolError` based on what's actionable.
IpcError errnoToIpcError({
  required int errno,
  required String op,
  String? target,
  String? raw,
}) {
  final what = target != null ? ' ($target)' : '';
  switch (errno) {
    case PosixErrno.enoent:
      return IpcError(
        code: IpcExitCode.notFound,
        kind: IpcErrorKind.notFound,
        message: '$op: not found$what',
      );
    case PosixErrno.eacces:
    case PosixErrno.eperm:
      return IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: '$op: permission denied$what',
        hint: 'check file permissions or run with appropriate access',
      );
    case PosixErrno.eisdir:
      return IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: '$op: is a directory$what',
      );
    case PosixErrno.enotdir:
      return IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: '$op: not a directory$what',
      );
    case PosixErrno.eexist:
      return IpcError(
        code: IpcExitCode.conflict,
        kind: IpcErrorKind.conflict,
        message: '$op: already exists$what',
      );
    case PosixErrno.emfile:
    case PosixErrno.enfile:
      return IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: '$op: too many open files',
        hint: 'system or per-process file descriptor limit reached',
      );
    case PosixErrno.enomem:
      return IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: '$op: out of memory',
      );
    case PosixErrno.eagain:
      return IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: '$op: resource temporarily unavailable',
        hint: 'retry may succeed',
      );
    default:
      return IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: '$op failed${raw != null ? ': $raw' : ' (errno=$errno)'}',
      );
  }
}
