/// Tests for `lib/src/ipc/transport.dart` (T-331) — the DaemonTransport
/// seam. Runs under plain `dart test` (core suite): no Flutter imports.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/ipc/transport.dart';
import 'package:test/test.dart';

void main() {
  group('LocalSocketTransport', () {
    late Directory dir;
    late String path;
    late ServerSocket server;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('clide-transport-');
      path = '${dir.path}/sock';
      server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
    });

    tearDown(() async {
      await server.close();
      await dir.delete(recursive: true);
    });

    test('endpoint reports the socket path', () {
      expect(LocalSocketTransport(path).endpoint, path);
    });

    test('open connects; lines round-trip both directions', () async {
      final accepted = Completer<Socket>();
      server.listen((s) => accepted.complete(s));

      final conn = await LocalSocketTransport(path).open();
      final serverSide = await accepted.future;

      // client -> server
      final serverLines = serverSide.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
      final firstLine = serverLines.first;
      conn.writeLine('{"hello":1}');
      expect(await firstLine.timeout(const Duration(seconds: 2)), '{"hello":1}');

      // server -> client
      final clientLine = conn.lines.first;
      serverSide.writeln('{"world":2}');
      expect(await clientLine.timeout(const Duration(seconds: 2)), '{"world":2}');

      await conn.close();
      await serverSide.close();
    });

    test('open throws when nothing is bound (caller owns retry)', () async {
      final t = LocalSocketTransport('${dir.path}/no-such.sock');
      await expectLater(t.open(), throwsA(isA<SocketException>()));
    });

    test('lines closes when the server drops the connection', () async {
      final accepted = Completer<Socket>();
      server.listen((s) => accepted.complete(s));

      final conn = await LocalSocketTransport(path).open();
      final serverSide = await accepted.future;

      final done = conn.lines.drain<void>();
      await serverSide.close();
      await done.timeout(const Duration(seconds: 2));
      await conn.close();
    });
  });
}
