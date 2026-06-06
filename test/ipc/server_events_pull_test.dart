/// T-223 — cursor-based pull events over the IPC socket
/// (`clide events --since <cursor>`). Tests the one-shot read complement
/// to `tail --events`: events-after-cursor, the next-cursor high-water mark,
/// no-drop/no-duplicate across polls, subsystem filtering, and the gap marker
/// when a cursor predates the retained window (drop-oldest, D-85).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/types.dart';
import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:clide/src/ipc/server.dart';
import 'package:test/test.dart';

Logger _silent() => Logger(minLevel: LogLevel.error, sinks: const []);

Future<Socket> _connect(IpcServer s) async => Socket.connect(
      InternetAddress(s.socketPath, type: InternetAddressType.unix),
      0,
    );

void _emit(DaemonBus bus, String sub, String kind, [Map<String, Object?> data = const {}]) =>
    bus.emit(DaemonEvent(subsystem: sub, kind: kind, data: data, ts: DateTime.now().toUtc()));

/// Let the bus drain into the server's cursor log before a pull.
Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Directory ws;
  late DaemonBus bus;
  late IpcServer server;

  setUp(() async {
    ws = await Directory.systemTemp.createTemp('clide-events-pull-');
    bus = DaemonBus();
    server = IpcServer(
      dispatcher: DaemonDispatcher(),
      workspaceRoot: '${ws.path}/${DateTime.now().microsecondsSinceEpoch}',
      log: _silent(),
      events: bus,
      eventLogDepth: 4,
    );
    await server.start();
  });

  tearDown(() async {
    try {
      await server.stop();
    } catch (_) {}
    if (ws.existsSync()) ws.deleteSync(recursive: true);
  });

  /// Open a connection, send one `events` request, read the single response.
  Future<IpcResponse> pull({Object? since, String? filter}) async {
    final s = await _connect(server);
    try {
      final lines = s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
      final it = StreamIterator(lines);
      s.write('${IpcRequest(id: 'e', cmd: 'events', args: {
            'flags': {
              if (since != null) 'since': since,
              if (filter != null) 'filter': filter,
            },
          }).encode()}\n');
      await s.flush();
      if (!await it.moveNext().timeout(const Duration(seconds: 2))) {
        throw StateError('no response');
      }
      final resp = IpcMessage.decode(it.current) as IpcResponse;
      await it.cancel();
      return resp;
    } finally {
      await s.close();
    }
  }

  List<int> cursors(IpcResponse r) => [for (final e in r.data['events'] as List) (e as Map)['cursor'] as int];

  test('since 0 returns all retained events with a monotonic cursor + high-water', () async {
    _emit(bus, 'pane', 'spawned', {'id': 'p1'});
    _emit(bus, 'git', 'changed');
    _emit(bus, 'pane', 'closed', {'id': 'p1'});
    await _drain();

    final r = await pull(since: 0);
    expect(r.ok, isTrue);
    expect(cursors(r), [1, 2, 3]);
    expect(r.data['cursor'], 3); // next poll uses --since 3
    expect(r.data['gap'], isFalse);
    // Each event keeps its wire shape plus the cursor.
    final first = (r.data['events'] as List).first as Map;
    expect(first['subsystem'], 'pane');
    expect(first['kind'], 'spawned');
  });

  test('since <cursor> returns only events after it', () async {
    _emit(bus, 'pane', 'a');
    _emit(bus, 'pane', 'b');
    _emit(bus, 'pane', 'c');
    await _drain();
    final r = await pull(since: 1);
    expect(cursors(r), [2, 3]);
  });

  test('repeated polls neither drop nor duplicate', () async {
    _emit(bus, 'pane', 'a');
    _emit(bus, 'pane', 'b');
    await _drain();
    final first = await pull(since: 0);
    expect(cursors(first), [1, 2]);
    final next = first.data['cursor'] as int;

    _emit(bus, 'pane', 'c');
    _emit(bus, 'pane', 'd');
    await _drain();
    final second = await pull(since: next);
    expect(cursors(second), [3, 4]); // no overlap with the first batch
    expect(second.data['cursor'], 4);

    // Polling again with the latest cursor yields nothing new.
    final third = await pull(since: 4);
    expect(third.data['events'], isEmpty);
    expect(third.data['cursor'], 4);
  });

  test('filter restricts to a single subsystem', () async {
    _emit(bus, 'pane', 'a');
    _emit(bus, 'git', 'changed');
    _emit(bus, 'pane', 'b');
    await _drain();
    final r = await pull(since: 0, filter: 'pane');
    expect(cursors(r), [1, 3]); // git event (cursor 2) excluded
  });

  test('a cursor that aged out of the ring is reported as a gap', () async {
    // Depth is 4; emit 6 so cursors 1,2 are evicted (retained: 3,4,5,6).
    for (var i = 0; i < 6; i++) {
      _emit(bus, 'pane', 'e$i');
    }
    await _drain();

    final r = await pull(since: 1); // 1 predates the retained window
    expect(r.data['gap'], isTrue);
    expect(r.data['oldestCursor'], 3);
    expect(cursors(r), [3, 4, 5, 6]);

    // A cursor at/after the dropped watermark is not a gap.
    final r2 = await pull(since: 2);
    expect(r2.data['gap'], isFalse);
  });

  test('a first read (since 0) is never a gap even after eviction', () async {
    for (var i = 0; i < 6; i++) {
      _emit(bus, 'pane', 'e$i');
    }
    await _drain();
    final r = await pull(since: 0);
    expect(r.data['gap'], isFalse);
  });

  test('bare events with no flags reads from the start', () async {
    _emit(bus, 'pane', 'a');
    _emit(bus, 'pane', 'b');
    await _drain();
    final r = await pull();
    expect(cursors(r), [1, 2]);
  });

  test('a string --since (argv shape) parses', () async {
    _emit(bus, 'pane', 'a');
    _emit(bus, 'pane', 'b');
    await _drain();
    final r = await pull(since: '1');
    expect(cursors(r), [2]);
  });

  test('an invalid --since is a user error', () async {
    final r = await pull(since: 'abc');
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.userError);
  });
}
