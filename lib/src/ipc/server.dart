import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/ipc/envelope.dart';

typedef RequestDispatcher = Future<IpcResponse> Function(IpcRequest request);

/// Default per-request timeout. A handler that doesn't return within
/// this window gets a `tool_error` response so the connection's read
/// pipeline isn't blocked indefinitely. Long-running commands (git
/// pull/push, large pql queries) can override per-command later.
const Duration _kDefaultRequestTimeout = Duration(seconds: 60);

/// Unix-socket JSON-lines server. Each connection is an independent
/// bidirectional line-framed stream: client writes requests, daemon
/// writes responses + events on the same socket.
class DaemonServer {
  DaemonServer({
    required this.socketPath,
    required this.dispatch,
    Duration requestTimeout = _kDefaultRequestTimeout,
  }) : _requestTimeout = requestTimeout;

  final String socketPath;
  final RequestDispatcher dispatch;
  final Duration _requestTimeout;

  ServerSocket? _server;
  final Set<Socket> _clients = {};

  /// Broadcast [event] to every currently-connected client. Sockets
  /// that error on write are dropped — the client's read side will
  /// notice the close. Errors are logged so silent event loss is
  /// debuggable.
  void broadcast(IpcEvent event) {
    final line = event.encode();
    for (final c in List<Socket>.from(_clients)) {
      try {
        c.writeln(line);
      } catch (e) {
        stderr.writeln('clide daemon: broadcast write failed (${event.subsystem}.${event.kind}): $e');
        _clients.remove(c);
      }
    }
  }

  Future<void> start() async {
    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    try {
      _server = await ServerSocket.bind(addr, 0);
    } on SocketException {
      // Either a stale socket from a prior crash, or a live daemon.
      // Probe by trying to connect — if a live peer answers, refuse
      // to start so we don't rip its socket out.
      try {
        final probe = await Socket.connect(addr, 0)
            .timeout(const Duration(milliseconds: 200));
        await probe.close();
        throw StateError('clide daemon already running at $socketPath');
      } on TimeoutException {
        // No one answered — proceed to unlink and rebind.
      } on SocketException {
        // No one listening — proceed to unlink and rebind.
      }
      try {
        await File(socketPath).delete();
      } catch (_) {}
      _server = await ServerSocket.bind(addr, 0);
    }
    stderr.writeln('clide daemon listening on $socketPath');
    _server!.listen(_handleClient, onError: (e) {
      stderr.writeln('clide daemon accept error: $e');
    });
  }

  Future<void> stop() async {
    for (final c in List<Socket>.from(_clients)) {
      await c.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    try {
      await File(socketPath).delete();
    } catch (_) {}
  }

  void _handleClient(Socket client) {
    _clients.add(client);
    client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) => _handleLine(client, line),
          onDone: () => _clients.remove(client),
          onError: (Object e) {
            stderr.writeln('clide daemon client error: $e');
            _clients.remove(client);
          },
          cancelOnError: true,
        );
  }

  Future<void> _handleLine(Socket client, String line) async {
    if (line.isEmpty) return;
    IpcMessage? msg;
    try {
      msg = IpcMessage.decode(line);
    } on FormatException catch (e) {
      stderr.writeln('clide daemon: bad line from client: $e');
      return;
    }
    if (msg is! IpcRequest) return;
    IpcResponse resp;
    try {
      resp = await dispatch(msg).timeout(_requestTimeout);
    } on TimeoutException {
      stderr.writeln('clide daemon: dispatch timeout for ${msg.cmd} (${_requestTimeout.inSeconds}s)');
      resp = IpcResponse.err(
        id: msg.id,
        error: IpcError(
          code: 2,
          kind: 'tool_error',
          message: 'request timed out after ${_requestTimeout.inSeconds}s: ${msg.cmd}',
        ),
      );
    } catch (e, st) {
      stderr.writeln('clide daemon: dispatch error for ${msg.cmd}: $e\n$st');
      resp = IpcResponse.err(
        id: msg.id,
        error: IpcError(
          code: 2,
          kind: 'tool_error',
          message: 'dispatch failed: $e',
        ),
      );
    }
    try {
      client.writeln(resp.encode());
    } catch (e) {
      // Client disconnected mid-dispatch — drop it so future events
      // don't try to write to a dead socket.
      stderr.writeln('clide daemon: response write failed (${msg.cmd}): $e');
      _clients.remove(client);
    }
  }
}
