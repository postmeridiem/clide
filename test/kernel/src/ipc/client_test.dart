/// Real-socket integration tests for `lib/kernel/src/ipc/client.dart` —
/// boots a Unix domain server in the test, has DaemonClient connect,
/// then exercises request/response correlation, event forwarding,
/// disconnect, reconnect, malformed-line resilience, and dispose.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/ipc/client.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:test/test.dart';

/// Minimal test daemon — binds a Unix socket, accepts one connection,
/// exposes the accepted socket so the test can write framed JSON back.
class _TestDaemon {
  _TestDaemon(this.path);
  final String path;
  ServerSocket? _server;
  Socket? _client;
  final _onClient = Completer<Socket>();
  final _lines = StreamController<String>.broadcast();

  Future<void> start() async {
    final addr = InternetAddress(path, type: InternetAddressType.unix);
    _server = await ServerSocket.bind(addr, 0);
    _server!.listen((socket) {
      _client = socket;
      if (!_onClient.isCompleted) _onClient.complete(socket);
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(_lines.add);
    });
  }

  Future<Socket> waitForClient() => _onClient.future;

  Stream<String> get lines => _lines.stream;

  void send(String line) {
    _client!.writeln(line);
  }

  Future<void> close() async {
    await _client?.close();
    await _server?.close();
    await _lines.close();
  }
}

Future<String> _tmpSocket() async {
  final dir = await Directory.systemTemp.createTemp('clide-ipc-');
  return '${dir.path}/sock';
}

DaemonClient _build(String socketPath, DaemonBus bus) {
  return DaemonClient.unixSocket(
    socketPath: socketPath,
    log: Logger(minLevel: LogLevel.error, sinks: const []),
    events: bus,
  );
}

/// In-memory transport (T-331): proves DaemonClient runs unmodified over
/// any [DaemonTransport], not just the unix socket — the seam the remote
/// backend (T-329) slots into.
class _MemoryTransport implements DaemonTransport {
  final toClient = StreamController<String>.broadcast();
  final fromClient = StreamController<String>.broadcast();
  int opens = 0;

  @override
  String get endpoint => 'memory://test';

  @override
  Future<DaemonConnection> open() async {
    opens++;
    return _MemoryConnection(this);
  }

  Future<void> close() async {
    await toClient.close();
    await fromClient.close();
  }
}

class _MemoryConnection implements DaemonConnection {
  _MemoryConnection(this._t);
  final _MemoryTransport _t;

  @override
  Stream<String> get lines => _t.toClient.stream;

  @override
  void writeLine(String line) => _t.fromClient.add(line);

  @override
  Future<void> close() async {}
}

void main() {
  group('DaemonClient — happy path', () {
    test('connect → request → matching response completes', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();

      final socket = await daemon.waitForClient();
      expect(socket, isNotNull);
      // Wait for _setConnected → notifyListeners to actually run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isTrue);

      // Issue a request, capture the id off the wire, send back a response.
      final lineFuture = daemon.lines.first;
      final responseFuture = client.request('files.list', args: {'limit': 3});
      final reqLine = await lineFuture;
      final reqJson = jsonDecode(reqLine) as Map<String, Object?>;
      expect(reqJson['cmd'], 'files.list');
      expect(reqJson['args'], {'limit': 3});
      final id = reqJson['id'] as String;
      // Encode an IpcResponse using the framework's encoder.
      daemon.send(IpcResponse.ok(id: id, data: {'files': []}).encode());
      final resp = await responseFuture;
      expect(resp.ok, isTrue);
      expect(resp.id, id);
      expect(resp.data['files'], isEmpty);
    });

    test('event line from daemon emits on the bus', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final eventFuture = bus.stream.firstWhere((e) => e.event is DaemonEvent);
      final ev = IpcEvent(subsystem: 'pty', kind: 'output', data: {'bytes': 'aGVsbG8='}, timestamp: DateTime.now());
      daemon.send(ev.encode());
      final received = await eventFuture.timeout(const Duration(seconds: 2));
      final daemonEvent = received.event as DaemonEvent;
      expect(daemonEvent.subsystem, 'pty');
      expect(daemonEvent.kind, 'output');
    });
  });

  group('DaemonClient — error + lifecycle paths', () {
    test('request while disconnected (never started) returns a not-connected error fast', () async {
      // Never started → no connect attempt in flight → fail fast (no wait).
      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build('/tmp/does-not-exist.sock', bus);
      addTearDown(client.dispose);
      final resp = await client.request('anything');
      expect(resp.ok, isFalse);
      expect(resp.error?.message, contains('not connected'));
    });

    test('a request issued before connect waits, then sends once connected', () async {
      // Reproduces the startup race: the UI queries before the socket
      // finishes connecting. Started (so a connect is in flight) but no
      // server yet — the request must park, not fail, and send once the
      // server comes up.
      final path = await _tmpSocket();
      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);

      await client.start(); // no server yet → connect fails, reconnect armed
      expect(client.isConnected, isFalse);

      final respFuture = client.request('ping'); // parks (does not fail)

      // Bring the server up; the reconnect loop connects, waking the request.
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final line = await daemon.lines.first;
      expect(line, contains('ping'));
      final req = IpcMessage.decode(line) as IpcRequest;
      daemon.send(IpcResponse.ok(id: req.id, data: const {'pong': true}).encode());

      final resp = await respFuture;
      expect(resp.ok, isTrue);
      expect(resp.data['pong'], isTrue);
    });

    test('malformed line is logged and skipped, real lines still work', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Send garbage and an empty line — must not throw.
      daemon.send('not json at all');
      daemon.send('');
      // Then a real response — should still arrive.
      final lineFuture = daemon.lines.first;
      final respFuture = client.request('ping');
      final line = await lineFuture;
      final id = (jsonDecode(line) as Map)['id'] as String;
      daemon.send(IpcResponse.ok(id: id, data: const {}).encode());
      final resp = await respFuture.timeout(const Duration(seconds: 2));
      expect(resp.ok, isTrue);
    });

    test('daemon disconnect fails pending requests and flips isConnected', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      final acceptedSocket = await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isTrue);

      // Send a request but never respond — it should resolve with an error
      // once the daemon closes the connection.
      final respFuture = client.request('orphan');
      await acceptedSocket.close();
      final resp = await respFuture.timeout(const Duration(seconds: 2));
      expect(resp.ok, isFalse);
      expect(resp.error?.message, contains('disconnect'));
      // _handleDisconnect → _setConnected(false).
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isFalse);
    });

    test('stop closes the socket cleanly and clears pending requests', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pending = client.request('hang');
      await client.stop();
      final resp = await pending.timeout(const Duration(seconds: 2));
      expect(resp.ok, isFalse);
      expect(resp.error?.message, contains('stopped'));
      expect(client.isConnected, isFalse);
      // dispose path
      client.dispose();
    });

    test('connect failure schedules a reconnect (covers _connect catch + _scheduleReconnect)', () async {
      // Path that won't resolve — Socket.connect throws → _scheduleReconnect.
      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build('/tmp/clide-ipc-no-such-${DateTime.now().microsecondsSinceEpoch}.sock', bus);
      addTearDown(client.dispose);
      await client.start();
      // Give the catch branch + reconnect-scheduling a tick.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isFalse);
    });

    test('daemon-sent IpcRequest line is logged and ignored', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Send a Request from the daemon — the case is matched and warned.
      daemon.send(IpcRequest(id: 'X', cmd: 'should-not-happen', args: const {}).encode());
      // Real follow-up still works.
      final lineFuture = daemon.lines.first;
      final respFuture = client.request('ok');
      final line = await lineFuture;
      final id = (jsonDecode(line) as Map)['id'] as String;
      daemon.send(IpcResponse.ok(id: id, data: const {}).encode());
      final resp = await respFuture.timeout(const Duration(seconds: 2));
      expect(resp.ok, isTrue);
    });

    test('emits DaemonConnectionChanged on the bus when the connection state flips', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final flips = <bool>[];
      final sub = bus.on<DaemonConnectionChanged>().listen((e) => flips.add(e.connected));
      addTearDown(sub.cancel);

      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(flips, contains(true));
    });

    test('reconnectAt swaps socket paths and re-binds (T-127)', () async {
      final pathA = await _tmpSocket();
      final daemonA = _TestDaemon(pathA);
      await daemonA.start();
      addTearDown(daemonA.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(pathA, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemonA.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isTrue);
      expect(client.socketPath, pathA);

      // Spin up a SECOND daemon on a different socket and move the
      // client over to it.
      final pathB = await _tmpSocket();
      final daemonB = _TestDaemon(pathB);
      await daemonB.start();
      addTearDown(daemonB.close);

      await client.reconnectAt(pathB);
      await daemonB.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.socketPath, pathB);
      expect(client.isConnected, isTrue);

      // A request goes to the NEW daemon — verify by reading the
      // line off daemonB.lines.
      final lineFuture = daemonB.lines.first;
      final responseFuture = client.request('ping');
      final reqLine = await lineFuture;
      final reqJson = jsonDecode(reqLine) as Map<String, Object?>;
      daemonB.send(IpcResponse.ok(id: reqJson['id'] as String, data: const {'pong': true}).encode());
      final resp = await responseFuture;
      expect(resp.ok, isTrue);
    });
  });

  group('DaemonClient — transport seam (T-331)', () {
    test('request/response round-trips over a non-socket transport', () async {
      final transport = _MemoryTransport();
      addTearDown(transport.close);
      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = DaemonClient(
        transport: transport,
        log: Logger(minLevel: LogLevel.error, sinks: const []),
        events: bus,
      );
      addTearDown(client.dispose);

      await client.start();
      expect(transport.opens, 1);
      expect(client.isConnected, isTrue);
      expect(client.socketPath, 'memory://test');

      final lineFuture = transport.fromClient.stream.first;
      final respFuture = client.request('ping', args: {'n': 1});
      final line = await lineFuture;
      final req = IpcMessage.decode(line) as IpcRequest;
      expect(req.cmd, 'ping');
      transport.toClient.add(IpcResponse.ok(id: req.id, data: const {'pong': true}).encode());
      final resp = await respFuture.timeout(const Duration(seconds: 2));
      expect(resp.ok, isTrue);
      expect(resp.data['pong'], isTrue);
    });

    test('reconnectWith swaps from a socket transport to another transport', () async {
      final path = await _tmpSocket();
      final daemon = _TestDaemon(path);
      await daemon.start();
      addTearDown(daemon.close);

      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build(path, bus);
      addTearDown(client.dispose);
      await client.start();
      await daemon.waitForClient();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isTrue);

      final transport = _MemoryTransport();
      addTearDown(transport.close);
      await client.reconnectWith(transport);
      expect(client.isConnected, isTrue);
      expect(client.socketPath, 'memory://test');

      // Requests now flow over the new transport, not the old socket.
      final lineFuture = transport.fromClient.stream.first;
      final respFuture = client.request('over-memory');
      final req = IpcMessage.decode(await lineFuture) as IpcRequest;
      transport.toClient.add(IpcResponse.ok(id: req.id, data: const {}).encode());
      expect((await respFuture).ok, isTrue);
    });
  });
}
