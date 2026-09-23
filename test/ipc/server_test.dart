import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/risk_tiers.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/paths.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:clide/src/ipc/server.dart';
import 'package:test/test.dart';

import '../helpers/timeouts.dart';

/// Every server binds in a per-test temp dir ([sockDir]), never the real
/// runtime dir: start() probes and sweeps whatever sockets it finds, and
/// the real one holds the sockets of any clide running on this machine
/// (T-639). Workspace roots are arbitrary strings; the path resolver only
/// hashes them.

void main() {
  late Directory xdg;
  late String sockDir;
  late DaemonDispatcher dispatcher;
  late IpcServer server;
  late String workRoot;

  setUp(() async {
    xdg = await Directory.systemTemp.createTemp('clide-ipc-test-');
    sockDir = '${xdg.path}/clide';
    workRoot = '${xdg.path}/workspace-${DateTime.now().microsecondsSinceEpoch}';
    dispatcher = DaemonDispatcher();
  });

  tearDown(() async {
    try {
      await server.stop();
    } catch (_) {}
    if (xdg.existsSync()) xdg.deleteSync(recursive: true);
  });

  group('IpcServer (T-124)', () {
    test('start binds the socket at the per-workspace path', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      expect(server.isRunning, isTrue);
      expect(server.socketPath, endsWith('.sock'));
      expect(File(server.socketPath).statSync().type, FileSystemEntityType.unixDomainSock);
    });

    test('socketDir confines the socket to that directory (T-639)', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      expect(File(server.socketPath).parent.path, sockDir);
      expect(server.socketPath, workspaceSocketPath(workRoot, directory: sockDir));
      expect(File(workspaceSocketPath(workRoot)).existsSync(), isFalse, reason: 'nothing bound in the real runtime dir');
    });

    test('socket file has mode 0600 and parent dir has 0700', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final sock = File(server.socketPath).statSync();
      final parent = Directory(File(server.socketPath).parent.path).statSync();
      // FileStat.mode masks to the low 9 bits we care about.
      expect(sock.mode & 0x1ff, 0x180, reason: 'socket mode != 0600');
      expect(parent.mode & 0x1ff, 0x1c0, reason: 'parent mode != 0700');
    });

    test('a connected client gets a JSON-line response to ping', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final reply = await _roundTrip(server.socketPath, IpcRequest(id: '1', cmd: 'ping'));
      expect(reply.ok, isTrue);
      expect(reply.id, '1');
      expect(reply.data['pong'], isTrue);
    });

    test('unknown command returns a notFound IpcError', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final reply = await _roundTrip(server.socketPath, IpcRequest(id: '2', cmd: 'no.such.cmd'));
      expect(reply.ok, isFalse);
      expect(reply.error?.kind, IpcErrorKind.notFound);
    });

    test('malformed JSON line surfaces a userError', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      c.write('{not json\n');
      await c.flush();
      final line = await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 2));
      await c.close();
      final reply = IpcMessage.decode(line) as IpcResponse;
      expect(reply.ok, isFalse);
      expect(reply.error?.kind, IpcErrorKind.userError);
    });

    test('a wrong-type field is a userError naming the field, not an internal error (T-635)', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      c.write('{"type":"request","v":1,"id":1,"cmd":"ping"}\n');
      await c.flush();
      final line = await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(ioTimeout);
      await c.close();
      final reply = IpcMessage.decode(line) as IpcResponse;
      expect(reply.ok, isFalse);
      expect(reply.error?.kind, IpcErrorKind.userError);
      expect(reply.error?.message, contains('"id"'));
    });

    test('multi-connection accept loop: two simultaneous clients both get replies', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final results = await Future.wait([
        _roundTrip(server.socketPath, IpcRequest(id: 'a', cmd: 'ping')),
        _roundTrip(server.socketPath, IpcRequest(id: 'b', cmd: 'version')),
      ]);
      expect(results[0].id, 'a');
      expect(results[0].ok, isTrue);
      expect(results[1].id, 'b');
      expect(results[1].ok, isTrue);
    });

    test('stop removes the socket file and lets a fresh server bind the same path', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final path = server.socketPath;
      await server.stop();
      expect(File(path).existsSync(), isFalse);
      // Same path can be re-bound on a new server.
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      expect(server.socketPath, path);
      expect(File(path).existsSync(), isTrue);
    });

    test('stale socket file left behind is unlinked on start', () async {
      final path = workspaceSocketPath(workRoot, directory: sockDir);
      Directory(File(path).parent.path).createSync(recursive: true);
      File(path).writeAsBytesSync([]); // stale node, not a live listener
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      expect(server.isRunning, isTrue);
    });

    test('refuses to clobber a live listener on the same path', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final other = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      expect(() async => other.start(), throwsA(isA<StateError>()));
    });

    test('a handoff wait binds once the live listener goes away (D-113)', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final successor = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      final bound = successor.start(handoffWait: const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(successor.isRunning, isFalse, reason: 'still waiting on the old window');
      await server.stop();
      await bound;
      expect(successor.isRunning, isTrue);
      server = successor; // tearDown stops it
    });

    test('a handoff wait still refuses once it runs out', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final other = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await expectLater(other.start(handoffWait: const Duration(milliseconds: 300)), throwsA(isA<StateError>()));
    });

    test('startup sweeps dead orphan sockets from the runtime dir, keeps live ones (T-247)', () async {
      final socketDir = Directory(File(workspaceSocketPath(workRoot, directory: sockDir)).parent.path);
      socketDir.createSync(recursive: true);
      final uniq = DateTime.now().microsecondsSinceEpoch;
      // A dead orphan (a socket node with no listener) and a live orphan
      // (a real listener for some other "workspace"). Unique names so the
      // assertions don't depend on whatever else is in the shared runtime dir.
      final dead = File('${socketDir.path}/clide-sweep-dead-$uniq.sock')..writeAsBytesSync([]);
      final livePath = '${socketDir.path}/clide-sweep-live-$uniq.sock';
      final live = await ServerSocket.bind(InternetAddress(livePath, type: InternetAddressType.unix), 0);
      addTearDown(() async {
        await live.close();
        for (final p in [livePath, dead.path]) {
          if (File(p).existsSync()) File(p).deleteSync();
        }
      });

      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();

      expect(dead.existsSync(), isFalse, reason: 'a dead orphan should be swept on startup');
      expect(File(livePath).existsSync(), isTrue, reason: 'a live instance must be left untouched');
    });

    test('start is idempotent: second call on the same instance is a no-op', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      await server.start();
      expect(server.isRunning, isTrue);
    });

    test('stop on a never-started server is a no-op', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('a handler that throws surfaces as a toolError response', () async {
      dispatcher.register('boom', risk: const CommandRisk(RiskTier.observe), (_) async => throw StateError('handler crash'));
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final reply = await _roundTrip(server.socketPath, IpcRequest(id: 'x', cmd: 'boom'));
      expect(reply.ok, isFalse);
      expect(reply.error?.kind, IpcErrorKind.toolError);
      expect(reply.error?.message, contains('handler crash'));
    });

    test('stop closes an in-flight client connection', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      c.write('${IpcRequest(id: 'q', cmd: 'ping').encode()}\n');
      await c.flush();
      await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first;
      await server.stop();
      expect(server.isRunning, isFalse);
      try {
        await c.close();
      } catch (_) {}
    });

    test('multiple sequential requests on the same connection each get a reply', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      final replies = c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
      final iter = StreamIterator(replies);
      for (var i = 0; i < 3; i++) {
        c.write('${IpcRequest(id: '$i', cmd: 'ping').encode()}\n');
        await c.flush();
        expect(await iter.moveNext().timeout(const Duration(seconds: 2)), isTrue);
        final reply = IpcMessage.decode(iter.current) as IpcResponse;
        expect(reply.id, '$i');
        expect(reply.ok, isTrue);
      }
      await iter.cancel();
      await c.close();
    });

    // T-372: the old async onData never paused its subscription, so
    // pipelined requests interleaved mid-handler; per-chunk decode also
    // corrupted runes split across socket writes.
    test('two requests pipelined in one write are handled serially, in order (T-372/D-72)', () async {
      final order = <String>[];
      dispatcher.register('slow', risk: const CommandRisk(RiskTier.observe), (req) async {
        order.add('${req.id}:start');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        order.add('${req.id}:end');
        return IpcResponse.ok(id: req.id);
      });
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      // Single write carrying both frames.
      c.write('${IpcRequest(id: 'p1', cmd: 'slow').encode()}\n${IpcRequest(id: 'p2', cmd: 'slow').encode()}\n');
      await c.flush();
      final replies = c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
      final got = await replies.take(2).toList().timeout(const Duration(seconds: 5));
      await c.close();
      expect((IpcMessage.decode(got[0]) as IpcResponse).id, 'p1');
      expect((IpcMessage.decode(got[1]) as IpcResponse).id, 'p2');
      expect(order, ['p1:start', 'p1:end', 'p2:start', 'p2:end'], reason: 'D-72: dispatch is serial, never interleaved');
    });

    test('a request split mid-UTF-8-rune across two writes decodes intact (T-372)', () async {
      String? gotText;
      dispatcher.register('echo', risk: const CommandRisk(RiskTier.observe), (req) async {
        gotText = req.args['text'] as String?;
        return IpcResponse.ok(id: req.id, data: {'echo': gotText});
      });
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      final frame = utf8.encode('${IpcRequest(id: 'u1', cmd: 'echo', args: const {'text': 'héllo — ünïcode'}).encode()}\n');
      // Split inside the multi-byte 'é' (the first non-ASCII rune).
      final cut = frame.indexWhere((b) => b > 0x7f) + 1;
      c.add(frame.sublist(0, cut));
      await c.flush();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.add(frame.sublist(cut));
      await c.flush();
      final line = await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 2));
      await c.close();
      final reply = IpcMessage.decode(line) as IpcResponse;
      expect(reply.ok, isTrue);
      expect(gotText, 'héllo — ünïcode', reason: 'persistent decoder must join the split rune');
    });

    test('socketPath returns the resolved path before start (no bind)', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      // Before start, the getter falls back to workspaceSocketPath; it
      // must return the same path the server WOULD bind, so callers
      // can pre-publish it to clients.
      expect(server.socketPath, workspaceSocketPath(workRoot, directory: sockDir));
      expect(server.isRunning, isFalse);
    });

    test('prepareParentDir creates the parent directory if it does not exist', () async {
      // The per-test socket dir doesn't exist until start() makes it.
      final parent = Directory(sockDir);
      expect(parent.existsSync(), isFalse);
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      expect(parent.existsSync(), isTrue);
      expect((parent.statSync().mode) & 0x1ff, 0x1c0);
    });

    test('a non-request message (e.g. event) surfaces a userError', () async {
      server = IpcServer(dispatcher: dispatcher, workspaceRoot: workRoot, log: _silentLog(), socketDir: sockDir);
      await server.start();
      final c = await Socket.connect(InternetAddress(server.socketPath, type: InternetAddressType.unix), 0);
      final evt = IpcEvent(subsystem: 'test', kind: 'wrong-shape', timestamp: DateTime.now().toUtc());
      c.write('${evt.encode()}\n');
      await c.flush();
      final line = await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 2));
      await c.close();
      final reply = IpcMessage.decode(line) as IpcResponse;
      expect(reply.ok, isFalse);
      expect(reply.error?.kind, IpcErrorKind.userError);
    });
  });
}

Logger _silentLog() => Logger(minLevel: LogLevel.error, sinks: const []);

Future<IpcResponse> _roundTrip(String socketPath, IpcRequest req) async {
  final c = await Socket.connect(InternetAddress(socketPath, type: InternetAddressType.unix), 0);
  c.write('${req.encode()}\n');
  await c.flush();
  final line = await c.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 2));
  await c.close();
  return IpcMessage.decode(line) as IpcResponse;
}
