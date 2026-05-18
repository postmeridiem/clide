import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/paths.dart';
import 'package:clide/src/ipc/schema_v1.dart';

/// Unix-domain IPC server for the running Flutter app.
///
/// First slice of T-99 (D-56 path a). One server per workspace —
/// the socket path is derived from the workspace root per D-70. File
/// perms gate access per D-71 (`0600` socket, `0700` parent). The
/// server's accept loop is multi-connection; dispatch through the
/// supplied [DaemonDispatcher] is serial on the main isolate per
/// D-72. Per-handler isolate offload is the dispatcher / handler's
/// concern, not this layer's.
class IpcServer {
  IpcServer({required this.dispatcher, required this.workspaceRoot, required this.log});

  final DaemonDispatcher dispatcher;
  final String workspaceRoot;
  final Logger log;

  ServerSocket? _socket;
  String? _socketPath;
  final List<Socket> _clients = [];
  StreamSubscription<Socket>? _accepts;

  String get socketPath => _socketPath ?? workspaceSocketPath(workspaceRoot);
  bool get isRunning => _socket != null;

  /// Bind the socket and start accepting connections. Idempotent —
  /// a second [start] on the same instance is a no-op.
  ///
  /// Stale sockets left from a crashed previous clide are detected
  /// and unlinked before binding. If a *live* clide is already
  /// listening on the path the bind throws — the caller is the
  /// stale-vs-live arbiter (per D-72 there's one server per
  /// workspace; a colliding live process means a real conflict).
  Future<void> start() async {
    if (isRunning) return;
    final path = workspaceSocketPath(workspaceRoot);
    await _prepareParentDir(path);
    await _unlinkStale(path);
    final socket = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    try {
      await _chmod(path, 0x180); // 0o600
    } catch (e, st) {
      // chmod failure is fatal — D-71 says perms are the gate.
      await socket.close();
      log.error('ipc', 'chmod 0600 failed on $path', error: e, stackTrace: st);
      rethrow;
    }
    _socket = socket;
    _socketPath = path;
    _accepts = socket.listen(_onClient, onError: (Object e, StackTrace st) {
      log.error('ipc', 'accept loop error', error: e, stackTrace: st);
    });
    log.info('ipc', 'IPC server listening at $path');
  }

  /// Close the listening socket, kill any in-flight client
  /// connections, and remove the socket file from disk.
  Future<void> stop() async {
    final s = _socket;
    final path = _socketPath;
    if (s == null) return;
    _socket = null;
    _socketPath = null;
    await _accepts?.cancel();
    _accepts = null;
    for (final c in List<Socket>.from(_clients)) {
      try {
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    await s.close();
    if (path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (e) {
        log.warn('ipc', 'failed to unlink $path: $e');
      }
    }
  }

  void _onClient(Socket client) {
    _clients.add(client);
    final buffer = StringBuffer();
    late StreamSubscription<List<int>> sub;
    sub = client.listen(
      (chunk) async {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        var idx = buffer.toString().indexOf('\n');
        while (idx >= 0) {
          final raw = buffer.toString().substring(0, idx);
          // Trim consumed bytes by rebuilding the buffer with the
          // tail — StringBuffer can't slice in place.
          final tail = buffer.toString().substring(idx + 1);
          buffer.clear();
          buffer.write(tail);
          await _handleLine(client, raw);
          idx = buffer.toString().indexOf('\n');
        }
      },
      onError: (Object e, StackTrace st) {
        log.warn('ipc', 'client read error: $e');
      },
      onDone: () {
        _clients.remove(client);
        sub.cancel();
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleLine(Socket client, String line) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    IpcResponse response;
    try {
      final msg = IpcMessage.decode(trimmed);
      if (msg is! IpcRequest) {
        response = IpcResponse.err(
          id: '',
          error: IpcError(
            code: IpcExitCode.userError,
            kind: IpcErrorKind.userError,
            message: 'expected request, got ${msg.runtimeType}',
          ),
        );
      } else {
        response = await dispatcher.dispatch(msg);
      }
    } on FormatException catch (e) {
      response = IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'malformed request: ${e.message}',
        ),
      );
    } catch (e, st) {
      log.error('ipc', 'dispatch threw', error: e, stackTrace: st);
      response = IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'internal error: $e',
        ),
      );
    }
    try {
      client.write('${response.encode()}\n');
      await client.flush();
    } catch (e) {
      log.warn('ipc', 'client write failed: $e');
    }
  }

  Future<void> _prepareParentDir(String socketPath) async {
    final dir = Directory(File(socketPath).parent.path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    try {
      await _chmod(dir.path, 0x1c0); // 0o700
    } catch (e) {
      log.warn('ipc', 'chmod 0700 on ${dir.path} failed: $e');
    }
  }

  Future<void> _unlinkStale(String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    // Probe: try connecting. If something answers, refuse to bind.
    try {
      final test = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      ).timeout(const Duration(milliseconds: 200));
      await test.close();
      throw StateError('another clide IPC server is already listening on $path');
    } on SocketException {
      // No live listener — safe to unlink the stale node.
      f.deleteSync();
    } on TimeoutException {
      throw StateError('socket $path exists and is unresponsive — refusing to clobber');
    }
  }

  /// `chmod` via `chmod(1)` because dart:io doesn't expose the
  /// syscall on unix. Cheap; only runs at start/stop.
  Future<void> _chmod(String path, int modeBits) async {
    final octal = modeBits.toRadixString(8).padLeft(3, '0');
    final r = await Process.run('chmod', [octal, path]);
    if (r.exitCode != 0) {
      throw ProcessException('chmod', [octal, path], r.stderr.toString(), r.exitCode);
    }
  }
}
