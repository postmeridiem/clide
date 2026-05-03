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
  DaemonClient({
    required this.socketPath,
    required Logger log,
    required DaemonBus events,
  })  : _log = log,
        _events = events;

  final String socketPath;
  final Logger _log;
  final DaemonBus _events;

  Socket? _socket;
  bool _connected = false;
  bool _disposed = false;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(milliseconds: 200);
  int _nextId = 0;
  final Map<String, Completer<IpcResponse>> _pending = {};

  bool get isConnected => _connected;

  Future<void> start() async {
    _disposed = false;
    await _connect();
  }

  Future<void> stop() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final s = _socket;
    _socket = null;
    await s?.close();
    _failPending('client stopped');
    _setConnected(false);
  }

  Future<IpcResponse> request(
    String cmd, {
    Map<String, Object?> args = const {},
  }) {
    if (!_connected || _socket == null) {
      return Future.value(IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.toolError,
          kind: IpcErrorKind.toolError,
          message: 'daemon not connected',
          hint: 'is `clide --daemon` running?',
        ),
      ));
    }
    final id = '${_nextId++}';
    final completer = Completer<IpcResponse>();
    _pending[id] = completer;
    final req = IpcRequest(id: id, cmd: cmd, args: args);
    _socket!.writeln(req.encode());
    return completer.future;
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
      final socket = await Socket.connect(addr, 0);
      _socket = socket;
      _backoff = const Duration(milliseconds: 200);
      _setConnected(true);
      _log.info('ipc', 'connected to $socketPath');
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
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
          _events.emit(DaemonEvent(
            subsystem: e.subsystem,
            kind: e.kind,
            data: e.data,
            ts: e.timestamp,
          ));
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
    final err = IpcError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: reason,
    );
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
    _backoff = Duration(
      milliseconds: math.min(_backoff.inMilliseconds * 2, 5000),
    );
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    _events.emit(DaemonConnectionChanged(connected: v));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_socket?.close());
    _socket = null;
    _failPending('client disposed');
    super.dispose();
  }
}
