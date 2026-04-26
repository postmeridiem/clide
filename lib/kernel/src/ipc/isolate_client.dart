/// IPC client that sends requests to a backend isolate via SendPort.
///
/// Replaces [InProcessClient] for production use. The backend isolate
/// owns the [DaemonDispatcher] and all subprocess/file-I/O services.
/// Requests and responses travel as serialized Maps over SendPort,
/// reusing the existing IPC protocol (IpcRequest/IpcResponse/IpcEvent).
library;

import 'dart:async';
import 'dart:isolate';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/log.dart';

class IsolateClient extends DaemonClient {
  IsolateClient({
    required Logger log,
    required DaemonBus events,
    required SendPort backendPort,
  })  : _backendPort = backendPort,
        _events = events,
        super(socketPath: '', log: log, events: events);

  final SendPort _backendPort;
  final DaemonBus _events;

  /// The event bus that receives events from the backend.
  DaemonBus get events => _events;
  final Map<String, Completer<IpcResponse>> _pending = {};
  int _nextId = 0;

  /// Called by [Backend] to feed incoming messages from the backend isolate.
  void handleMessage(Map<String, Object?> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'response':
        final resp = IpcResponse.fromJson(msg);
        final c = _pending.remove(resp.id);
        if (c != null && !c.isCompleted) c.complete(resp);
      case 'event':
        final evt = IpcEvent.fromJson(msg);
        _events.emit(DaemonEvent(
          subsystem: evt.subsystem,
          kind: evt.kind,
          data: evt.data,
          ts: evt.timestamp,
        ));
    }
  }

  @override
  bool get isConnected => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<IpcResponse> request(String cmd, {Map<String, Object?> args = const {}}) {
    final id = '${_nextId++}';
    final req = IpcRequest(id: id, cmd: cmd, args: args);
    final c = Completer<IpcResponse>();
    _pending[id] = c;
    _backendPort.send(req.toJson());
    return c.future;
  }
}
