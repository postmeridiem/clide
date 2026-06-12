/// DaemonTransport (T-331): the seam between the local app and its
/// backend. The UI's [DaemonClient] talks JSON-lines through a
/// [DaemonTransport] instead of a hard-coded unix-socket connect, so a
/// remote transport (SSH-tunnelled agent socket or ssh-exec channel,
/// T-329/Q-23) can slot in without touching the client's correlation,
/// reconnect, or event-forwarding logic.
///
/// The wire protocol is unchanged either way: one JSON envelope
/// (IpcRequest/IpcResponse/IpcEvent, see envelope.dart) per line.
///
/// Kept Flutter-free — this file runs under plain `dart test`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// How the app reaches its backend. Implementations own endpoint
/// resolution + connection establishment; the caller owns retry policy
/// (the client's backoff loop calls [open] again after a failure).
abstract interface class DaemonTransport {
  /// Stable, human-readable endpoint description — the unix socket path
  /// locally, a `ssh://host/path` form remotely. Used for logs, status
  /// surfaces, and same-endpoint reconnect short-circuits.
  String get endpoint;

  /// Establish one connection. Throws on failure (caller retries).
  Future<DaemonConnection> open();
}

/// One live backend connection carrying JSON-lines both ways.
abstract interface class DaemonConnection {
  /// Incoming lines, one JSON envelope each. Done/error signals the
  /// connection dropped.
  Stream<String> get lines;

  /// Send one JSON envelope line (the newline is appended here).
  void writeLine(String line);

  Future<void> close();
}

/// Today's path: connect to the workspace-derived unix domain socket
/// (D-70) the in-process IpcServer is bound to.
class LocalSocketTransport implements DaemonTransport {
  LocalSocketTransport(this.socketPath);

  final String socketPath;

  @override
  String get endpoint => socketPath;

  @override
  Future<DaemonConnection> open() async {
    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    return _SocketConnection(await Socket.connect(addr, 0));
  }
}

class _SocketConnection implements DaemonConnection {
  _SocketConnection(this._socket);

  final Socket _socket;

  @override
  Stream<String> get lines => _socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());

  @override
  void writeLine(String line) => _socket.writeln(line);

  @override
  Future<void> close() => _socket.close();
}
