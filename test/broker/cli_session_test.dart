@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/cli.dart';
import 'package:test/test.dart';

/// `clide_broker workspaces`, and `serve` with its workspaces and hosts
/// (D-119, D-120).
void main() {
  late Directory dir;
  late Map<String, String> environment;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-broker-cli-');
    environment = {
      'CLIDE_BROKER_STORE': 'sqlite:${dir.path}/broker.db',
      'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.test',
      'CLIDE_BROKER_SIGNIN_MODE': 'token',
      'PATH': Platform.environment['PATH']!,
    };
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, String, String)> run(List<String> args, {Future<void>? stop}) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runBrokerCli(args, environment: environment, out: out, err: err, stop: stop);
    return (code, out.toString(), err.toString());
  }

  group('workspaces', () {
    test("lists user 0's workspaces, and names each folder it skipped", () async {
      final projects = '${dir.path}/users/0/projects';
      for (final name in ['beta', 'alpha', 'with space']) {
        Directory('$projects/$name').createSync(recursive: true);
      }
      final (code, out, err) = await run(['workspaces', '--users', '${dir.path}/users']);
      expect([code, out], [0, 'alpha\nbeta\n']);
      expect(err, 'Skipped the folder "with space": the name has characters other than A-Z, a-z, 0-9, ".", "_" and "-".\n');
    });

    test('names a missing projects folder, and needs an absolute --users', () async {
      final (code, _, err) = await run(['workspaces', '--users', '${dir.path}/users']);
      expect(code, exitConfig);
      expect(err, contains('${dir.path}/users/0/projects'));
      expect((await run(['workspaces', '--users', 'users'])).$1, exitUsage);
    });
  });

  test('serve --host starts the workspace host on the first session, and stops it on the way out', () async {
    final token = RegExp('#token=(.+)').firstMatch((await run(['token', 'rotate'])).$2)![1]!;
    Directory('${dir.path}/users/0/projects/demo').createSync(recursive: true);
    final host = File('${dir.path}/host')..writeAsStringSync('#!/bin/sh\nexec dart run ${Directory.current.path}/bin/clide_stub_host.dart "\$@"\n');
    Process.runSync('chmod', ['755', host.path]);
    final socket = '${dir.path}/run/broker.sock';
    final stop = Completer<void>();
    final served = run(['serve', '--socket', socket, '--users', '${dir.path}/users', '--host', host.path], stop: stop.future);
    while (FileSystemEntity.typeSync(socket) != FileSystemEntityType.unixDomainSock) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(socket, type: InternetAddressType.unix), 0);
    addTearDown(() => client.close(force: true));

    final login = await client.openUrl('POST', Uri.parse('http://broker/auth/login'));
    login.followRedirects = false;
    login.headers
      ..set('origin', 'https://clide.test')
      ..contentType = ContentType('application', 'x-www-form-urlencoded');
    login.write('token=$token');
    final signedIn = await login.close();
    await signedIn.drain<void>();
    final cookie = signedIn.headers[HttpHeaders.setCookieHeader]!.single.split(';').first;

    final session = await WebSocket.connect(
      'ws://broker/u/0/w/demo/session',
      headers: {'origin': 'https://clide.test', 'cookie': cookie},
      customClient: client,
    );
    final received = StringBuffer();
    final closed = Completer<void>();
    session.listen((message) => received.write(utf8.decode(message as List<int>)), onDone: closed.complete);
    session.add(utf8.encode('ping\n'));
    for (var i = 0; i < 250 && !received.toString().endsWith('ping\n'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(received.toString(), 'clide stub host for demo\nping\n');

    stop.complete();
    final (code, _, err) = await served;
    await closed.future.timeout(const Duration(seconds: 5));
    expect(code, 0);
    expect(session.closeCode, WebSocketStatus.goingAway);
    expect(
      err,
      allOf(contains('1 workspace in ${dir.path}/users/0/projects'), contains('user 0 opened a session on demo'), contains('host demo: listening for demo')),
    );
    expect(Directory('${dir.path}/run/clide').listSync(), isEmpty, reason: 'the host was stopped, and removed its socket');
  });

  test('serve without --host says sessions cannot open, and names a missing projects folder', () async {
    await run(['token', 'rotate']);
    final stop = Completer<void>()..complete();
    final (code, _, err) = await run(['serve', '--socket', '${dir.path}/run/broker.sock', '--users', '${dir.path}/users'], stop: stop.future);
    expect(code, 0);
    expect(err, allOf(contains('no --host was given'), contains('There is no projects folder at ${dir.path}/users/0/projects')));
  });
}
