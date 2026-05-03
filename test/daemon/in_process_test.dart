import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  group('DaemonServer (in-process)', () {
    late DaemonServer server;
    late DaemonDispatcher dispatcher;
    late String socketPath;

    setUp(() async {
      final tmp = await Directory.systemTemp.createTemp('clide_daemon_');
      socketPath = '${tmp.path}/daemon.sock';
      dispatcher = DaemonDispatcher();
      server = DaemonServer(
        socketPath: socketPath,
        dispatch: dispatcher.dispatch,
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('ping round-trips with pong=true', () async {
      final resp = await _send(
        socketPath,
        IpcRequest(id: '1', cmd: 'ping').encode(),
      );
      final parsed = IpcMessage.decode(resp) as IpcResponse;
      expect(parsed.ok, true);
      expect(parsed.id, '1');
      expect(parsed.data['pong'], true);
      expect(parsed.data['ts'], isA<String>());
      expect(parsed.data['version'], isA<String>());
    });

    test('version returns current clideVersion', () async {
      final resp = await _send(
        socketPath,
        IpcRequest(id: 'v', cmd: 'version').encode(),
      );
      final parsed = IpcMessage.decode(resp) as IpcResponse;
      expect(parsed.ok, true);
      expect(parsed.data['version'], clideVersion);
    });

    test('unknown command returns NotFound (exit code 3)', () async {
      final resp = await _send(
        socketPath,
        IpcRequest(id: 'x', cmd: 'this.does.not.exist').encode(),
      );
      final parsed = IpcMessage.decode(resp) as IpcResponse;
      expect(parsed.ok, false);
      expect(parsed.error!.code, IpcExitCode.notFound);
      expect(parsed.error!.kind, IpcErrorKind.notFound);
      expect(parsed.error!.message, contains('this.does.not.exist'));
    });

    test('multiple concurrent requests on one connection', () async {
      final socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      for (var i = 0; i < 5; i++) {
        socket.writeln(IpcRequest(id: '$i', cmd: 'ping').encode());
      }
      final lines = <String>[];
      final done = Completer<void>();
      final sub = socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        lines.add(line);
        if (lines.length == 5) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
      await socket.close();
      final ids = lines.map((l) => (IpcMessage.decode(l) as IpcResponse).id).toSet();
      expect(ids, {'0', '1', '2', '3', '4'});
    });

    test('custom handler plugs into dispatcher', () async {
      dispatcher.register('test.custom', (req) async {
        return IpcResponse.ok(id: req.id, data: {'echo': req.args});
      });
      final resp = await _send(
        socketPath,
        IpcRequest(
          id: 'c',
          cmd: 'test.custom',
          args: const {'x': 1},
        ).encode(),
      );
      final parsed = IpcMessage.decode(resp) as IpcResponse;
      expect(parsed.ok, true);
      expect(parsed.data['echo'], {'x': 1});
    });
  });
}

Future<String> _send(String socketPath, String line) async {
  final socket = await Socket.connect(
    InternetAddress(socketPath, type: InternetAddressType.unix),
    0,
  );
  socket.writeln(line);
  final resp = await socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first.timeout(const Duration(seconds: 2));
  await socket.close();
  return resp;
}
