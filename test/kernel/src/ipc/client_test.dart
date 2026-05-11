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
  return DaemonClient(
    socketPath: socketPath,
    log: Logger(minLevel: LogLevel.error, sinks: const []),
    events: bus,
  );
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

      final eventFuture = bus.stream.firstWhere(
        (e) => e.event is DaemonEvent,
      );
      final ev = IpcEvent(
        subsystem: 'pty',
        kind: 'output',
        data: {'bytes': 'aGVsbG8='},
        timestamp: DateTime.now(),
      );
      daemon.send(ev.encode());
      final received = await eventFuture.timeout(const Duration(seconds: 2));
      final daemonEvent = received.event as DaemonEvent;
      expect(daemonEvent.subsystem, 'pty');
      expect(daemonEvent.kind, 'output');
    });
  });

  group('DaemonClient — error + lifecycle paths', () {
    test('request while disconnected returns a not-connected error', () async {
      // Don't connect — point at a non-existent socket path.
      final bus = DaemonBus();
      addTearDown(bus.dispose);
      final client = _build('/tmp/does-not-exist.sock', bus);
      addTearDown(client.dispose);
      final resp = await client.request('anything');
      expect(resp.ok, isFalse);
      expect(resp.error?.message, contains('not connected'));
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
  });
}
