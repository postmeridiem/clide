@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/http/server.dart';
import 'package:clide/src/broker/serve_config.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:clide/src/broker/supervise/hosts.dart';
import 'package:clide/src/broker/workspaces.dart';
import 'package:test/test.dart';

const _origin = 'https://clide.test';
const _config = ServeConfig(publicOrigin: _origin, mode: SigninMode.token, sessionLifetime: Duration(hours: 1));
final _token = 'T' * 43;

/// The session WebSocket (D-117): `/u/<N>/w/<slug>/session`, bridged to the
/// workspace's host byte for byte.
void main() {
  late Directory dir;
  late BrokerStore store;
  late BrokerServer server;
  late HttpClient client;
  late _TestHosts hosts;
  late String projects;
  late List<String> lines;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('clide-broker-session-');
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'));
    await store.rotateToken(0, secretHash(_token));
    final registry = WorkspaceRegistry('${dir.path}/users');
    projects = registry.projects(0);
    Directory('$projects/demo').createSync(recursive: true);
    hosts = _TestHosts(dir.path);
    lines = [];
    server = await BrokerServer.bind(
      '${dir.path}/run/broker.sock',
      store: store,
      config: _config,
      workspaces: registry,
      hosts: hosts,
      failureDelay: Duration.zero,
      log: lines.add,
    );
    client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(server.path, type: InternetAddressType.unix), 0);
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    await hosts.close();
    await store.close();
    dir.deleteSync(recursive: true);
  });

  Future<String> signIn() async {
    final request = await client.openUrl('POST', Uri.parse('http://broker/auth/login'));
    request.followRedirects = false;
    request.headers
      ..set('origin', _origin)
      ..contentType = ContentType('application', 'x-www-form-urlencoded');
    request.write('token=$_token&next=%2F');
    final response = await request.close();
    await response.drain<void>();
    return response.headers[HttpHeaders.setCookieHeader]!.single.split(';').first;
  }

  /// Opens a session the way a browser on the install's origin does.
  Future<_Browser> open(String cookie, {String path = '/u/0/w/demo/session'}) async =>
      _Browser(await WebSocket.connect('ws://broker$path', headers: {'origin': _origin, 'cookie': cookie}, customClient: client));

  /// How the broker answers a WebSocket handshake for [path].
  Future<({int status, HttpHeaders headers, String body})> answer(
    String path, {
    String? cookie,
    String? origin = _origin,
    String method = 'GET',
    bool upgrade = true,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(method, Uri.parse('http://broker$path'));
    if (upgrade) {
      request.headers
        ..set(HttpHeaders.connectionHeader, 'Upgrade')
        ..set(HttpHeaders.upgradeHeader, 'websocket')
        ..set('sec-websocket-version', '13')
        ..set('sec-websocket-key', base64.encode(List.generate(16, (i) => i)));
    }
    if (origin != null) request.headers.set('origin', origin);
    if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
    headers.forEach(request.headers.set);
    final response = await request.close();
    var body = '';
    if (response.statusCode == HttpStatus.switchingProtocols) {
      (await response.detachSocket()).destroy();
    } else {
      body = await utf8.decoder.bind(response).join();
    }
    return (status: response.statusCode, headers: response.headers, body: body);
  }

  /// The status the broker answers a WebSocket handshake for [path] with.
  Future<int> handshake(String path, {String? cookie, String? origin = _origin, String method = 'GET', bool upgrade = true}) async =>
      (await answer(path, cookie: cookie, origin: origin, method: method, upgrade: upgrade)).status;

  group('a session', () {
    test('carries every byte value both ways, unparsed', () async {
      final browser = await open(await signIn());
      final bytes = Uint8List.fromList([for (var round = 0; round < 4; round++) ...List.generate(256, (i) => i)]);
      browser.socket.add(bytes);
      await browser.until(() => browser.bytes.length >= bytes.length);
      expect(browser.bytes, bytes);
      expect(hosts.attached, ['$projects/demo']);
      expect(lines, contains('user 0 opened a session on demo'));
      await browser.socket.close();
    });

    test('delivers what the host sends first as binary messages', () async {
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      hosts.connections.single.socket.add(utf8.encode('{"hello":1}\n'));
      await browser.until(() => browser.messages.isNotEmpty);
      expect(browser.messages.single, isA<List<int>>().having(utf8.decode, 'text', '{"hello":1}\n'));
      await browser.socket.close();
    });

    test('ends with 1003 on a text message, and passes on nothing after it', () async {
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      final host = hosts.connections.single;
      browser.socket
        ..add('{"text":"not bytes"}')
        ..add([1, 2, 3])
        ..add([4, 5, 6]);
      await browser.closed;
      expect([browser.socket.closeCode, browser.socket.closeReason], [WebSocketStatus.unsupportedData, 'The session carries binary messages only.']);
      await host.closed;
      expect(host.received, isEmpty);
      expect(await handshake('/u/0/w/demo/session', cookie: await signIn()), 101, reason: 'the broker is still serving');
    });

    test('opens with a 101 that says Connection: Upgrade, which a proxy checks before switching', () async {
      final response = await answer('/u/0/w/demo/session', cookie: await signIn());
      expect(response.status, 101);
      expect(response.headers[HttpHeaders.connectionHeader], [equalsIgnoringCase('upgrade')]);
      expect(response.headers.value(HttpHeaders.upgradeHeader), equalsIgnoringCase('websocket'));
    });

    test('is not compressed, whatever the browser offers', () async {
      final response = await answer(
        '/u/0/w/demo/session',
        cookie: await signIn(),
        headers: {'sec-websocket-extensions': 'permessage-deflate; client_max_window_bits'},
      );
      expect(response.status, 101);
      expect(response.headers.value('sec-websocket-extensions'), isNull);
    });

    test('ends with 1001 when the host closes its side', () async {
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      hosts.connections.single.socket.destroy();
      await browser.closed;
      expect([browser.socket.closeCode, browser.socket.closeReason], [WebSocketStatus.goingAway, 'The workspace host ended the session.']);
    });

    test('ends with 1011 when the host connection breaks', () async {
      hosts.hold = true;
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      browser.socket.add(List.filled(1024, 7));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Closing with those bytes unread resets the connection (ECONNRESET).
      hosts.connections.single.socket.destroy();
      await browser.closed;
      expect([browser.socket.closeCode, browser.socket.closeReason], [WebSocketStatus.internalServerError, 'The connection to the workspace host failed.']);
      expect(await handshake('/u/0/w/demo/session', cookie: await signIn()), 101, reason: 'the broker is still serving');
    });

    test('closes the host connection when the browser closes', () async {
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      await browser.socket.close(WebSocketStatus.normalClosure);
      await hosts.connections.single.closed;
      await _until(() => lines.contains('a session on demo ended'));
    });

    test('ends with 1001 when the broker stops', () async {
      final browser = await open(await signIn());
      await _until(() => hosts.connections.isNotEmpty);
      await server.close();
      await browser.closed;
      expect([browser.socket.closeCode, browser.socket.closeReason], [WebSocketStatus.goingAway, 'The broker is stopping.']);
      await hosts.connections.single.closed;
    });
  });

  group('the handshake', () {
    test('refuses another origin, or none, before looking for a host', () async {
      final cookie = await signIn();
      expect(await handshake('/u/0/w/demo/session', cookie: cookie, origin: 'https://evil.test'), 403);
      expect(await handshake('/u/0/w/demo/session', cookie: cookie, origin: null), 403);
      expect(hosts.attached, isEmpty);
    });

    test("refuses without a session, and on another user's path", () async {
      expect(await handshake('/u/0/w/demo/session'), 401);
      expect(await handshake('/u/0/w/demo/session', cookie: '__Host-clide_session=${'x' * 43}'), 401);
      final cookie = await signIn();
      Directory('${dir.path}/users/1/projects/demo').createSync(recursive: true);
      expect(await handshake('/u/1/w/demo/session', cookie: cookie), 403);
      expect(hosts.attached, isEmpty);
    });

    test('answers 404 for a workspace that is not there, or not one', () async {
      final cookie = await signIn();
      Directory('$projects/.hidden').createSync();
      Link('$projects/linked').createSync('$projects/demo');
      for (final slug in ['missing', '.hidden', 'linked', '%2E%2E']) {
        expect(await handshake('/u/0/w/$slug/session', cookie: cookie), 404, reason: slug);
      }
      expect(hosts.attached, isEmpty);
    });

    test('answers 503 when the host cannot start or does not take the session', () async {
      final cookie = await signIn();
      hosts.failure = HostStartException('The host for demo exited with code 1 before it answered.');
      expect(await handshake('/u/0/w/demo/session', cookie: cookie), 503);
      expect(lines, contains('The host for demo exited with code 1 before it answered.'));
      hosts
        ..failure = null
        ..silent = true;
      expect(await handshake('/u/0/w/demo/session', cookie: cookie), 503);
      expect(lines, contains(startsWith('the host for demo did not take the session')));
    });

    test('answers 503 from a broker with no hosts', () async {
      final bare = await BrokerServer.bind('${dir.path}/run/bare.sock', store: store, config: _config, workspaces: WorkspaceRegistry('${dir.path}/users'));
      addTearDown(bare.close);
      final bareClient = HttpClient()
        ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(bare.path, type: InternetAddressType.unix), 0);
      addTearDown(() => bareClient.close(force: true));
      client = bareClient;
      final response = await answer('/u/0/w/demo/session', cookie: await signIn());
      expect([response.status, response.body], [503, 'This broker has no workspace host to start.']);
    });

    test('answers 426 to a request that is not an upgrade, and 405 to another method', () async {
      final cookie = await signIn();
      expect(await handshake('/u/0/w/demo/session', cookie: cookie, upgrade: false), 426);
      expect(await handshake('/u/0/w/demo/session', cookie: cookie, method: 'POST'), 405);
    });
  });
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 250 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

/// A browser's end of a session: what it received, and when it closed.
final class _Browser {
  _Browser(this.socket) {
    socket.listen(messages.add, onDone: _closed.complete);
  }

  final WebSocket socket;
  final messages = <Object?>[];
  final _closed = Completer<void>();

  Future<void> get closed => _closed.future.timeout(const Duration(seconds: 5));

  List<int> get bytes => [for (final m in messages) ...m! as List<int>];

  Future<void> until(bool Function() condition) => _until(condition);
}

/// Hosts that live in the test. Each workspace gets a socket whose
/// connections echo what they receive, and which the test can see and end.
final class _TestHosts implements WorkspaceHosts {
  _TestHosts(this.directory);

  final String directory;
  final attached = <String>[];
  final connections = <({Socket socket, List<int> received, Future<void> closed})>[];

  /// What [attach] throws, when set.
  Object? failure;

  /// Answer with a socket nothing listens on.
  bool silent = false;

  /// Leave what a connection receives unread.
  bool hold = false;

  final _servers = <String, ServerSocket>{};

  @override
  Future<String> attach(String workspace) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    if (silent) return '$directory/nothing.sock';
    attached.add(workspace);
    var server = _servers[workspace];
    if (server == null) {
      server = _servers[workspace] = await ServerSocket.bind(InternetAddress('$directory/host-${_servers.length}.sock', type: InternetAddressType.unix), 0);
      server.listen((socket) {
        final closed = Completer<void>();
        final received = <int>[];
        unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
        final reading = socket.listen(
          (bytes) {
            received.addAll(bytes);
            socket.add(bytes);
          },
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
          onError: (Object _) {
            if (!closed.isCompleted) closed.complete();
          },
        );
        if (hold) reading.pause();
        connections.add((socket: socket, received: received, closed: closed.future.timeout(const Duration(seconds: 5))));
      });
    }
    return server.address.address;
  }

  Future<void> close() async {
    for (final server in _servers.values) {
      await server.close();
    }
  }
}
