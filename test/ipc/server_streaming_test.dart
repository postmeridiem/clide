/// T-129 — event streaming over the IPC socket. Tests the
/// `tail --events` subscription branch on the server: subscriber
/// registration, per-subsystem replay-buffer (D-6 / replayDepth=16),
/// filter matching, fanout on bus events, and broken-subscriber
/// cleanup.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/server.dart';
import 'package:test/test.dart';

Logger _silent() => Logger(minLevel: LogLevel.error, sinks: const []);

Future<Socket> _connect(IpcServer s) async => Socket.connect(
      InternetAddress(s.socketPath, type: InternetAddressType.unix),
      0,
    );

/// Wrap a Socket in a line iterator backed by a single broadcast
/// stream so the same connection can read multiple framed lines.
({Stream<String> lines, Socket sock}) _lineReader(Socket s) {
  final stream = s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  return (lines: stream, sock: s);
}

/// Thin wrapper over StreamIterator with a [next] convenience.
class _Lines {
  _Lines(Stream<String> s) : _it = StreamIterator(s);
  final StreamIterator<String> _it;
  Future<String> next({Duration timeout = const Duration(seconds: 2)}) async {
    final ok = await _it.moveNext().timeout(timeout);
    if (!ok) throw StateError('stream ended before next line');
    return _it.current;
  }

  Future<void> cancel() => _it.cancel();
}

Future<void> _send(Socket s, IpcRequest req) async {
  s.write('${req.encode()}\n');
  await s.flush();
}

IpcRequest _tailReq({String? filter, String id = 't'}) => IpcRequest(
      id: id,
      cmd: 'tail',
      args: {
        'flags': {
          'events': true,
          if (filter != null) 'filter': filter,
        },
      },
    );

void main() {
  late Directory ws;
  late DaemonDispatcher dispatcher;
  late DaemonBus bus;
  late IpcServer server;

  setUp(() async {
    ws = await Directory.systemTemp.createTemp('clide-stream-test-');
    dispatcher = DaemonDispatcher();
    bus = DaemonBus();
    server =
        IpcServer(dispatcher: dispatcher, workspaceRoot: '${ws.path}/${DateTime.now().microsecondsSinceEpoch}', log: _silent(), events: bus, replayDepth: 4);
    await server.start();
  });

  tearDown(() async {
    try {
      await server.stop();
    } catch (_) {}
    await bus.dispose();
    if (ws.existsSync()) ws.deleteSync(recursive: true);
  });

  test('subscribe → streaming ack with filter echoed', () async {
    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    await _send(s, _tailReq(filter: 'pane'));
    final line = await r.lines.first.timeout(const Duration(seconds: 2));
    final ack = IpcMessage.decode(line) as IpcResponse;
    expect(ack.ok, isTrue);
    expect(ack.data['streaming'], isTrue);
    expect(ack.data['filter'], 'pane');
  });

  test('subscribe with no filter → wildcard ack', () async {
    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    await _send(s, _tailReq());
    final line = await r.lines.first.timeout(const Duration(seconds: 2));
    final ack = IpcMessage.decode(line) as IpcResponse;
    expect(ack.data['filter'], '*');
  });

  test('events emitted post-subscribe land on the subscriber', () async {
    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    final lineQ = _Lines(r.lines);
    await _send(s, _tailReq(filter: 'pane'));
    await lineQ.next(); // ack
    bus.emit(DaemonEvent(subsystem: 'pane', kind: 'spawned', data: const {'id': 'p1'}, ts: DateTime.now().toUtc()));
    final evLine = await lineQ.next();
    final ev = IpcMessage.decode(evLine) as IpcEvent;
    expect(ev.subsystem, 'pane');
    expect(ev.kind, 'spawned');
    expect(ev.data['id'], 'p1');
    await lineQ.cancel();
  });

  test('filter excludes non-matching subsystems', () async {
    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    final lineQ = _Lines(r.lines);
    await _send(s, _tailReq(filter: 'pane'));
    await lineQ.next(); // ack
    // Emit a non-matching event first, then a matching one. The
    // subscriber should only see the matching one.
    bus.emit(DaemonEvent(subsystem: 'git', kind: 'changed', data: const {}, ts: DateTime.now().toUtc()));
    bus.emit(DaemonEvent(subsystem: 'pane', kind: 'closed', data: const {'id': 'p1'}, ts: DateTime.now().toUtc()));
    final ev = IpcMessage.decode(await lineQ.next()) as IpcEvent;
    expect(ev.subsystem, 'pane');
    expect(ev.kind, 'closed');
    await lineQ.cancel();
  });

  test('replay buffer surfaces pre-subscribe events on connect', () async {
    // Push three events before any subscriber exists.
    for (var i = 0; i < 3; i++) {
      bus.emit(DaemonEvent(subsystem: 'pane', kind: 'spawned', data: {'i': i}, ts: DateTime.now().toUtc()));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    final lineQ = _Lines(r.lines);
    await _send(s, _tailReq(filter: 'pane'));
    await lineQ.next(); // ack
    final replayed = <int>[];
    for (var i = 0; i < 3; i++) {
      final ev = IpcMessage.decode(await lineQ.next()) as IpcEvent;
      replayed.add(ev.data['i'] as int);
    }
    expect(replayed, [0, 1, 2]);
    await lineQ.cancel();
  });

  test('replay ring is bounded to replayDepth (4 for this test)', () async {
    for (var i = 0; i < 10; i++) {
      bus.emit(DaemonEvent(subsystem: 'pane', kind: 'spawned', data: {'i': i}, ts: DateTime.now().toUtc()));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final s = await _connect(server);
    addTearDown(s.close);
    final r = _lineReader(s);
    final lineQ = _Lines(r.lines);
    await _send(s, _tailReq(filter: 'pane'));
    await lineQ.next(); // ack
    final replayed = <int>[];
    for (var i = 0; i < 4; i++) {
      final ev = IpcMessage.decode(await lineQ.next()) as IpcEvent;
      replayed.add(ev.data['i'] as int);
    }
    // Last 4 of 0..9 → 6,7,8,9.
    expect(replayed, [6, 7, 8, 9]);
    await lineQ.cancel();
  });

  test('multiple subscribers each receive an event independently', () async {
    final sA = await _connect(server);
    addTearDown(sA.close);
    final sB = await _connect(server);
    addTearDown(sB.close);
    final rA = _lineReader(sA);
    final rB = _lineReader(sB);
    final qA = _Lines(rA.lines);
    final qB = _Lines(rB.lines);
    await _send(sA, _tailReq(filter: 'pane', id: 'A'));
    await _send(sB, _tailReq(filter: 'pane', id: 'B'));
    await qA.next(); // ack
    await qB.next(); // ack
    bus.emit(DaemonEvent(subsystem: 'pane', kind: 'event', data: const {'tag': 'broadcast'}, ts: DateTime.now().toUtc()));
    final evA = IpcMessage.decode(await qA.next()) as IpcEvent;
    final evB = IpcMessage.decode(await qB.next()) as IpcEvent;
    expect(evA.data['tag'], 'broadcast');
    expect(evB.data['tag'], 'broadcast');
    await qA.cancel();
    await qB.cancel();
  });

  test('subscriber going away removes itself from fanout (no crash on emit)', () async {
    final s = await _connect(server);
    final r = _lineReader(s);
    final q = _Lines(r.lines);
    await _send(s, _tailReq(filter: 'pane'));
    await q.next(); // ack
    await q.cancel();
    await s.close();
    // Give the server's onDone a tick.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Emitting should not throw or stall — covered by reaching the
    // next assertion.
    bus.emit(DaemonEvent(subsystem: 'pane', kind: 'orphan', data: const {}, ts: DateTime.now().toUtc()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(server.isRunning, isTrue);
  });
}
