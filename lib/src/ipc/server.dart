import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/cli/argv_dispatch.dart';
import 'package:clide/src/cli/argv_to_request.dart';
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
  IpcServer({
    required this.dispatcher,
    required this.workspaceRoot,
    required this.log,
    this.events,
    this.replayDepth = 16,
  });

  final DaemonDispatcher dispatcher;
  final String workspaceRoot;
  final Logger log;

  /// Bus the server subscribes to for events forwarded to
  /// `clide tail --events` subscribers. Optional — when null, the
  /// tail handler still accepts subscriptions but never gets events
  /// (useful in tests that don't need the full kernel wiring).
  final DaemonBus? events;

  /// Per-subsystem replay-buffer depth (D-6: default 16). New
  /// subscribers receive up to this many recent matching events on
  /// connect so they don't miss effects emitted just before they
  /// subscribed.
  final int replayDepth;

  ServerSocket? _socket;
  String? _socketPath;
  final List<Socket> _clients = [];
  StreamSubscription<Socket>? _accepts;

  // Event streaming (T-129).
  StreamSubscription<DaemonEvent>? _busSub;

  /// Subscribers: client socket → filter (`*` or a subsystem name).
  /// A connection enters this map after it sends `tail --events`.
  final Map<Socket, String> _subscribers = {};

  /// Per-subsystem ring buffer of recent events for replay.
  final Map<String, Queue<IpcEvent>> _replay = {};

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
    // Subscribe to the bus so we can populate the replay ring AND
    // fan out to live `tail --events` subscribers. Idempotent —
    // we only attach when a bus is supplied.
    final bus = events;
    if (bus != null) {
      _busSub = bus.on<DaemonEvent>().listen(_onBusEvent);
    }
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
    await _busSub?.cancel();
    _busSub = null;
    _subscribers.clear();
    _replay.clear();
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
        _subscribers.remove(client);
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
        // Peel off the `_argv` envelope at the server layer so the
        // streaming check sees the unwrapped command (T-129). Plain
        // typed requests skip this path.
        var req = msg;
        if (req.cmd == argvSentinelCmd) {
          final result = unwrapArgvRequest(req);
          if (result is ArgvError) {
            response = result.response;
            // Fall through to write below.
            try {
              client.write('${response.encode()}\n');
              await client.flush();
            } catch (e) {
              log.warn('ipc', 'client write failed: $e');
            }
            return;
          }
          req = (result as ArgvParsed).request;
        }
        if (_isTailSubscribe(req)) {
          // Long-lived subscription branch (T-129). Send the streaming
          // ack, replay matching ring buffer entries, register the
          // client. The connection stays open until the client closes.
          await _enterStreamingMode(client, req);
          return;
        }
        response = await dispatcher.dispatch(req);
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

  // -- event streaming (T-129) ----------------------------------------------

  /// Recognise the `tail --events [--filter X]` subscription
  /// request that the argv translator (T-125) produces.
  bool _isTailSubscribe(IpcRequest req) {
    if (req.cmd != 'tail') return false;
    final flags = req.args['flags'];
    return flags is Map && flags['events'] == true;
  }

  Future<void> _enterStreamingMode(Socket client, IpcRequest req) async {
    final flags = req.args['flags'] as Map?;
    final filter = (flags?['filter'] as String?) ?? '*';
    // Streaming ack — `data.streaming: true` tells the C client to
    // loop-read instead of exiting after one response.
    final ack = IpcResponse.ok(id: req.id, data: {'streaming': true, 'filter': filter});
    try {
      client.write('${ack.encode()}\n');
      await client.flush();
    } catch (e) {
      log.warn('ipc', 'streaming ack write failed: $e');
      return;
    }
    // Replay matching events from the ring.
    final replay = _replayFor(filter);
    for (final ev in replay) {
      if (!_sendEvent(client, ev)) return;
    }
    _subscribers[client] = filter;
  }

  Iterable<IpcEvent> _replayFor(String filter) {
    if (filter == '*') {
      // Flatten everything in arrival order. Per-subsystem rings
      // preserve order within a subsystem; across subsystems the
      // ordering is best-effort (interleaved-by-subsystem). Good
      // enough for "what just happened".
      return _replay.values.expand((q) => q);
    }
    return _replay[filter] ?? const [];
  }

  void _onBusEvent(DaemonEvent e) {
    final ev = IpcEvent(
      subsystem: e.subsystem,
      kind: e.kind,
      data: e.data,
      timestamp: e.ts,
    );
    // Push to replay ring.
    final ring = _replay.putIfAbsent(e.subsystem, () => Queue<IpcEvent>());
    ring.addLast(ev);
    while (ring.length > replayDepth) {
      ring.removeFirst();
    }
    // Fan out to live subscribers whose filter matches.
    final stale = <Socket>[];
    for (final entry in _subscribers.entries) {
      final filter = entry.value;
      if (filter != '*' && filter != e.subsystem) continue;
      if (!_sendEvent(entry.key, ev)) {
        stale.add(entry.key);
      }
    }
    for (final s in stale) {
      _subscribers.remove(s);
    }
  }

  /// Write an event line to [client]. Returns false on failure, which
  /// the caller uses to drop the subscriber. We deliberately don't
  /// await `flush` here — back-pressure handling per D-72: if the
  /// socket's write buffer is full, dart:io's Socket.write enqueues
  /// in-memory, and the kernel pushes through as it can. If the
  /// client is genuinely gone the write throws or onDone fires and
  /// the subscriber gets removed via _onClient's onDone.
  bool _sendEvent(Socket client, IpcEvent ev) {
    try {
      client.write('${ev.encode()}\n');
      return true;
    } catch (e) {
      log.warn('ipc', 'subscriber write failed (dropping): $e');
      return false;
    }
  }

  // -- internals ------------------------------------------------------------

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
