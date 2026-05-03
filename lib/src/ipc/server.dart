import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/ipc/envelope.dart';

typedef RequestDispatcher = Future<IpcResponse> Function(IpcRequest request);

/// Unix-socket JSON-lines server. Each connection is an independent
/// bidirectional line-framed stream: client writes requests, daemon
/// writes responses + events on the same socket.
class DaemonServer {
  DaemonServer({
    required this.socketPath,
    required this.dispatch,
  });

  final String socketPath;
  final RequestDispatcher dispatch;

  ServerSocket? _server;
  final Set<Socket> _clients = {};

  /// Broadcast [event] to every currently-connected client.
  ///
  /// Future tuning: per-client subsystem/id filter (`tail --filter
  /// pane:p_7`). For Tier 1 every client sees everything. Sockets
  /// that error on write are silently dropped; the client's read side
  /// will notice the close.
  void broadcast(IpcEvent event) {
    final line = event.encode();
    for (final c in List<Socket>.from(_clients)) {
      try {
        c.writeln(line);
      } catch (_) {
        _clients.remove(c);
      }
    }
  }

  Future<void> start() async {
    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    try {
      _server = await ServerSocket.bind(addr, 0);
    } on SocketException {
      // stale socket from a prior crash — unlink and retry once
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
      resp = await dispatch(msg);
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
    client.writeln(resp.encode());
  }
}
