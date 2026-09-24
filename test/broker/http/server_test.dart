import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/auth/login_page.dart';
import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/http/server.dart';
import 'package:clide/src/broker/serve_config.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const _origin = 'https://clide.test';
final _token = 'T' * 43;

void main() {
  late Directory dir;
  late BrokerStore store;
  late BrokerServer server;
  late HttpClient client;
  late DateTime now;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('clide-broker-http-');
    now = DateTime.utc(2026, 9, 24, 12);
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'), clock: () => now);
    await store.rotateToken(0, secretHash(_token));
    server = await BrokerServer.bind(
      '${dir.path}/run/broker.sock',
      store: store,
      config: const ServeConfig(publicOrigin: _origin, mode: SigninMode.token, sessionLifetime: Duration(hours: 1)),
      failureDelay: Duration.zero,
      clock: () => now,
    );
    client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(server.path, type: InternetAddressType.unix), 0);
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    await store.close();
    dir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> send(String method, String path, {Map<String, String> headers = const {}, String? form, String? raw}) async {
    final request = await client.openUrl(method, Uri.parse('http://broker$path'));
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (form != null) {
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write(form);
    }
    if (raw != null) request.write(raw);
    return request.close();
  }

  Future<String> body(HttpClientResponse response) => response.transform(utf8.decoder).join();

  /// Signs in with [value] and answers the session cookie, `name=value`.
  Future<String?> signIn([String? value]) async {
    final response = await send('POST', '/auth/login', headers: {'origin': _origin}, form: 'token=${value ?? _token}&next=%2F');
    await response.drain<void>();
    return response.headers[HttpHeaders.setCookieHeader]?.single.split(';').first;
  }

  Future<HttpClientResponse> verify(String uri, {String? cookie, bool navigate = true}) => send(
    'GET',
    '/auth/verify',
    headers: {'x-forwarded-uri': uri, 'x-forwarded-method': 'GET', 'sec-fetch-mode': navigate ? 'navigate' : 'cors', 'cookie': ?cookie},
  );

  group('forward-auth', () {
    test('sends a browser that is not signed in to the sign-in page, and answers anything else 401', () async {
      final page = await verify('/u/0/w/clide/?x=1');
      expect([page.statusCode, page.headers.value('location')], [302, '/auth/login?next=%2Fu%2F0%2Fw%2Fclide%2F%3Fx%3D1']);
      expect((await verify('/main.dart.wasm', navigate: false)).statusCode, 401);
    });

    test('lets a signed-in request through, naming its user', () async {
      final cookie = await signIn();
      for (final uri in ['/u/0/w/clide/', '/u/0', '/main.dart.wasm', '/']) {
        final response = await verify(uri, cookie: cookie);
        expect([response.statusCode, response.headers.value('x-clide-user')], [200, '0'], reason: uri);
      }
    });

    test('refuses a path that belongs to another user, or names a user in another spelling', () async {
      final cookie = await signIn();
      for (final uri in ['/u/1/w/clide/', '/u/00/w/clide/', '/u/%30/w/clide/', '/u/x/']) {
        expect((await verify(uri, cookie: cookie)).statusCode, 403, reason: uri);
      }
    });

    test('refuses a session that has expired, or one that a token rotation ended', () async {
      final cookie = await signIn();
      now = now.add(const Duration(hours: 1));
      expect((await verify('/', cookie: cookie, navigate: false)).statusCode, 401);
      now = now.subtract(const Duration(hours: 1));
      expect((await verify('/', cookie: cookie, navigate: false)).statusCode, 200);
      await store.rotateToken(0, secretHash('R' * 43));
      expect((await verify('/', cookie: cookie, navigate: false)).statusCode, 401);
    });

    test('ignores a cookie that is not shaped like a session id', () async {
      expect((await verify('/', cookie: '__Host-clide_session=../../etc', navigate: false)).statusCode, 401);
    });
  });

  group('sign-in', () {
    test('the page allows only its own script and style', () async {
      final response = await send('GET', '/auth/login?next=/u/0/w/clide/');
      final html = await body(response);
      String hashOf(String s) => "'sha256-${base64.encode(sha256.convert(utf8.encode(s)).bytes)}'";
      final csp = response.headers.value('content-security-policy')!;
      expect(csp, allOf(contains("default-src 'none'"), contains('script-src ${hashOf(loginScript)}'), contains('style-src ${hashOf(loginStyle)}')));
      expect(html, allOf(contains('<script>$loginScript</script>'), contains('<style>$loginStyle</style>'), contains('value="/u/0/w/clide/"')));
      expect(response.headers.value('cache-control'), 'no-store');
    });

    test('escapes where the page sends the browser next', () async {
      final html = await body(await send('GET', '/auth/login?next=${Uri.encodeQueryComponent('/u/0/"><script>x</script>')}'));
      expect(html, isNot(contains('"><script>x')));
      expect(html, contains('&quot;&gt;&lt;script&gt;x'));
    });

    test('the token signs the browser in with a __Host- cookie and sends it on', () async {
      final response = await send('POST', '/auth/login', headers: {'origin': _origin}, form: 'token=$_token&next=%2Fu%2F0%2Fw%2Fclide%2F');
      expect([response.statusCode, response.headers.value('location')], [303, '/u/0/w/clide/']);
      expect(
        response.headers[HttpHeaders.setCookieHeader]!.single,
        matches(RegExp(r'^__Host-clide_session=[A-Za-z0-9_-]{43}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=3600$')),
      );
    });

    test('a wrong token, or a value of another shape, goes back to the page with a notice', () async {
      for (final value in ['W' * 43, 'short', '${_token}x' * 3]) {
        final response = await send('POST', '/auth/login', headers: {'origin': _origin}, form: 'token=$value&next=%2Fu%2F0%2F');
        expect([response.statusCode, response.headers.value('location')], [303, '/auth/login?error=1&next=%2Fu%2F0%2F'], reason: value);
        expect(response.headers[HttpHeaders.setCookieHeader], isNull);
      }
      expect(await body(await send('GET', '/auth/login?error=1')), contains('was not accepted'));
    });

    test('a sign-in from another origin, or with none, is refused', () async {
      for (final headers in [
        {'origin': 'https://evil.test'},
        <String, String>{},
      ]) {
        final response = await send('POST', '/auth/login', headers: headers, form: 'token=$_token');
        expect(response.statusCode, 403);
        expect(response.headers[HttpHeaders.setCookieHeader], isNull);
      }
    });

    test('a single-use link signs in once', () async {
      final link = 'L' * 43;
      await store.putSigninLink(secretHash(link), 0, now.add(const Duration(minutes: 10)));
      expect(await signIn(link), startsWith('__Host-clide_session='));
      expect(await signIn(link), isNull);
    });

    test('refuses a body that is not a form, or is too large', () async {
      expect((await send('POST', '/auth/login', headers: {'origin': _origin, 'content-type': 'application/json'}, raw: '{}')).statusCode, 415);
      expect((await send('POST', '/auth/login', headers: {'origin': _origin}, form: 'token=${'x' * 5000}')).statusCode, 413);
    });

    test('answers a form it cannot read with 400, not as a broker failure', () async {
      expect((await send('POST', '/auth/login', headers: {'origin': _origin}, form: 'token=%zz')).statusCode, 400);
      final request = await client.openUrl('POST', Uri.parse('http://broker/auth/login'));
      request.headers
        ..set('origin', _origin)
        ..contentType = ContentType('application', 'x-www-form-urlencoded');
      request.add([0x74, 0x3D, 0xFF, 0xFE]);
      expect((await request.close()).statusCode, 400);
    });
  });

  test('without Sec-Fetch-Mode, a GET that accepts HTML counts as a page navigation', () async {
    final page = await send('GET', '/auth/verify', headers: {'x-forwarded-uri': '/', 'x-forwarded-method': 'GET', 'accept': 'text/html,*/*'});
    expect(page.statusCode, 302);
    final fetch = await send('GET', '/auth/verify', headers: {'x-forwarded-uri': '/', 'x-forwarded-method': 'POST', 'accept': 'text/html'});
    expect(fetch.statusCode, 401);
  });

  test('the next page stays on this origin and outside /auth/', () {
    for (final next in ['https://evil.test/', '//evil.test/x', '///evil.test', '/auth/logout', r'/\evil.test', '/u/0/\u0000', null, '', 'u/0/']) {
      expect(safeNext(next), '/', reason: '$next');
    }
    expect([safeNext('/u/0/w/clide/?a=1'), safeNext('/')], ['/u/0/w/clide/?a=1', '/']);
  });

  test('signing out ends the session and clears the cookie', () async {
    final cookie = await signIn();
    final refused = await send('POST', '/auth/logout', headers: {'cookie': cookie!});
    expect(refused.statusCode, 403);
    final response = await send('POST', '/auth/logout', headers: {'origin': _origin, 'cookie': cookie});
    expect([response.statusCode, response.headers.value('location')], [303, '/auth/login']);
    expect(response.headers[HttpHeaders.setCookieHeader]!.single, endsWith('Max-Age=0'));
    expect((await verify('/', cookie: cookie, navigate: false)).statusCode, 401);
  });

  test('answers 404 elsewhere and 405 for a method a path does not take', () async {
    expect((await send('GET', '/u/0/w/clide/')).statusCode, 404);
    expect((await send('GET', '/auth/logout')).statusCode, 405);
    expect((await send('POST', '/auth/verify')).statusCode, 405);
  });

  test('a store that fails answers 503 rather than leaving Caddy waiting', () async {
    final cookie = await signIn();
    await store.close();
    expect((await verify('/', cookie: cookie)).statusCode, 503);
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'), clock: () => now);
  });

  group('the socket', () {
    test('only its owner can use it, in a directory only its owner can enter', () {
      expect((FileStat.statSync(server.path).mode & 0x1ff).toRadixString(8), '600');
      expect((FileStat.statSync(File(server.path).parent.path).mode & 0x1ff).toRadixString(8), '700');
    });

    test('a second broker on the same socket is refused while the first runs', () async {
      await expectLater(
        BrokerServer.bind(
          server.path,
          store: store,
          config: const ServeConfig(publicOrigin: _origin, mode: SigninMode.token, sessionLifetime: Duration(hours: 1)),
        ),
        throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains('Another broker'))),
      );
    });

    test('a file left where the socket goes is replaced', () async {
      final path = '${dir.path}/run/second.sock';
      File(path).writeAsStringSync('left behind');
      final second = await BrokerServer.bind(
        path,
        store: store,
        config: const ServeConfig(publicOrigin: _origin, mode: SigninMode.token, sessionLifetime: Duration(hours: 1)),
      );
      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.unixDomainSock);
      await second.close();
      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    });
  });
}
