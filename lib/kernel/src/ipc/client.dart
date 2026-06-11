import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:flutter/foundation.dart';

class DaemonClient extends ChangeNotifier {
  DaemonClient({required String socketPath, required Logger log, required DaemonBus events}) : _socketPath = socketPath, _log = log, _events = events;

  String _socketPath;
  String get socketPath => _socketPath;
  final Logger _log;
  final DaemonBus _events;

  Socket? _socket;
  bool _connected = false;
  bool _disposed = false;
  bool _started = false;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(milliseconds: 200);
  int _nextId = 0;
  final Map<String, Completer<IpcResponse>> _pending = {};

  /// Requests that arrived before the socket was connected park here
  /// until the connection comes up (or the wait times out).
  final List<Completer<void>> _connectWaiters = [];

  /// How long a request will wait for an in-progress connection before
  /// giving up with a not-connected error. Covers the startup window
  /// where the UI queries before the socket has finished connecting.
  static const Duration _connectWait = Duration(seconds: 5);

  bool get isConnected => _connected;

  Future<void> start() async {
    _disposed = false;
    _started = true;
    await _connect();
  }

  Future<void> stop() async {
    _disposed = true;
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final s = _socket;
    _socket = null;
    await s?.close();
    _failPending('client stopped');
    _wakeConnectWaiters();
    _setConnected(false);
  }

  /// Point the client at a different socket path and reconnect.
  /// Used on project switch — the workspace-derived socket path
  /// (D-70) changes when the user opens a different project, so the
  /// client follows. Cancels the reconnect timer, closes the live
  /// socket (failing in-flight requests with `disconnect`), updates
  /// the path, and re-arms the connect loop. Idempotent if the new
  /// path equals the current one.
  Future<void> reconnectAt(String newPath) async {
    if (newPath == _socketPath && _connected) return;
    _socketPath = newPath;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final s = _socket;
    _socket = null;
    await s?.close();
    _failPending('socket path changed');
    _setConnected(false);
    _disposed = false;
    _started = true;
    _backoff = const Duration(milliseconds: 200);
    await _connect();
  }

  Future<IpcResponse> request(String cmd, {Map<String, Object?> args = const {}}) async {
    if (!_connected || _socket == null) {
      // A connection attempt is in flight (startup or reconnect) — wait
      // for it rather than failing instantly, so queries issued during
      // the startup window don't get a spurious not-connected error.
      // If the client was never started (or is disposed), fail fast.
      if (_started && !_disposed) {
        await _awaitConnected(_connectWait);
      }
      if (!_connected || _socket == null) {
        return IpcResponse.err(
          id: '',
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'daemon not connected'),
        );
      }
    }
    final id = '${_nextId++}';
    final completer = Completer<IpcResponse>();
    _pending[id] = completer;
    final req = IpcRequest(id: id, cmd: cmd, args: args);
    _socket!.writeln(req.encode());
    return completer.future;
  }

  /// Complete when the socket connects, or after [timeout] (whichever
  /// first). Returns immediately if already connected.
  Future<void> _awaitConnected(Duration timeout) async {
    if (_connected) return;
    final c = Completer<void>();
    _connectWaiters.add(c);
    try {
      await c.future.timeout(timeout);
    } on TimeoutException {
      _connectWaiters.remove(c);
    }
  }

  void _wakeConnectWaiters() {
    if (_connectWaiters.isEmpty) return;
    final waiters = List<Completer<void>>.from(_connectWaiters);
    _connectWaiters.clear();
    for (final c in waiters) {
      if (!c.isCompleted) c.complete();
    }
  }

  Future<void> _connect() async {
    // Already connected? Don't open a second socket. Guards against
    // racing connect attempts (e.g. start() arming the reconnect loop
    // while swapIpcServer's reconnectAt connects on first boot).
    if (_disposed || _connected) return;
    try {
      final addr = InternetAddress(_socketPath, type: InternetAddressType.unix);
      final socket = await Socket.connect(addr, 0);
      _socket = socket;
      _backoff = const Duration(milliseconds: 200);
      _setConnected(true);
      _log.info('ipc', 'connected to $_socketPath');
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onDone: _handleDisconnect,
            onError: (Object e) {
              _log.warn('ipc', 'socket error', error: e);
              _handleDisconnect();
            },
            cancelOnError: true,
          );
    } catch (e) {
      _log.debug('ipc', 'connect failed ($e); retry in ${_backoff.inMilliseconds}ms');
      _scheduleReconnect();
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) return;
    try {
      final msg = IpcMessage.decode(line);
      switch (msg) {
        case IpcResponse r:
          final c = _pending.remove(r.id);
          if (c != null && !c.isCompleted) c.complete(r);
        case IpcEvent e:
          _events.emit(DaemonEvent(subsystem: e.subsystem, kind: e.kind, data: e.data, ts: e.timestamp));
        case IpcRequest _:
          _log.warn('ipc', 'daemon sent a request — unexpected');
      }
    } on FormatException catch (e) {
      _log.warn('ipc', 'bad line from daemon: $e');
    }
  }

  void _handleDisconnect() {
    _socket = null;
    _failPending('daemon disconnected');
    _setConnected(false);
    _scheduleReconnect();
  }

  void _failPending(String reason) {
    final err = IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: reason);
    for (final entry in _pending.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(IpcResponse.err(id: entry.key, error: err));
      }
    }
    _pending.clear();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, _connect);
    _backoff = Duration(milliseconds: math.min(_backoff.inMilliseconds * 2, 5000));
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    // Release any requests parked waiting for the connection — on a
    // successful connect they proceed to send; this runs before the
    // dispose guard so a connect always wakes them.
    if (v) _wakeConnectWaiters();
    // Skip side-effects (event emit + notifyListeners) after dispose —
    // the socket stream's onDone can fire post-dispose and would
    // otherwise hit ChangeNotifier's "used after disposed" assert.
    if (_disposed) return;
    _events.emit(DaemonConnectionChanged(connected: v));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _started = false;
    _reconnectTimer?.cancel();
    unawaited(_socket?.close());
    _socket = null;
    _failPending('client disposed');
    _wakeConnectWaiters();
    super.dispose();
  }
}
