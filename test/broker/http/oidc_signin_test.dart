@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/auth/oidc.dart';
import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/http/server.dart';
import 'package:clide/src/broker/serve_config.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

import '../auth/fake_provider.dart';

const _origin = 'https://clide.test';

/// Signing in through an OpenID Connect provider (D-118), end to end: the
/// broker on its socket, and a provider over TLS from a test CA.
void main() {
  late Directory caDirectory;
  late TestCa ca;
  late Directory dir;
  late FakeProvider provider;
  late BrokerStore store;
  late BrokerServer server;
  late OidcClient oidc;
  late HttpClient client;
  late List<String> lines;
  late DateTime now;

  setUpAll(() async {
    caDirectory = Directory.systemTemp.createTempSync('clide-oidc-ca-');
    ca = await TestCa.create(caDirectory.path);
  });
  tearDownAll(() => caDirectory.deleteSync(recursive: true));

  /// The provider's settings. Unless [trusted] is false, the test CA is the
  /// install's CA file; without it, only the system's authorities count.
  OidcSettings settings({String? secret = 'client secret', bool trusted = true}) => OidcSettings(
    issuer: provider.issuer,
    clientId: 'clide',
    clientSecret: secret,
    subjects: const {'subject-1'},
    emails: const {'owner@example.com'},
    groups: const {'clide-users'},
    caFile: trusted ? ca.certificate : null,
  );

  /// Serves on a fresh socket with [oidcSettings], or token mode without
  /// them, giving each request to the provider [timeout].
  Future<void> serve(OidcSettings? oidcSettings, {Duration timeout = const Duration(seconds: 10)}) async {
    await server.close();
    oidc.close();
    oidc = OidcClient(oidcSettings ?? settings(), redirectUri: '$_origin/auth/callback', clock: () => now, timeout: timeout);
    server = await BrokerServer.bind(
      '${dir.path}/run/broker.sock',
      store: store,
      config: ServeConfig(
        publicOrigin: _origin,
        mode: oidcSettings == null ? SigninMode.token : SigninMode.oidc,
        sessionLifetime: const Duration(hours: 1),
        oidc: oidcSettings,
      ),
      oidc: oidcSettings == null ? null : oidc,
      failureDelay: Duration.zero,
      clock: () => now,
      log: lines.add,
    );
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('clide-oidc-');
    now = DateTime.now().toUtc();
    provider = await FakeProvider.start(ca);
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'), clock: () => now);
    lines = [];
    oidc = OidcClient(settings(), redirectUri: '$_origin/auth/callback', clock: () => now);
    server = await BrokerServer.bind(
      '${dir.path}/run/broker.sock',
      store: store,
      config: ServeConfig(publicOrigin: _origin, mode: SigninMode.oidc, sessionLifetime: const Duration(hours: 1), oidc: oidc.settings),
      oidc: oidc,
      failureDelay: Duration.zero,
      clock: () => now,
      log: lines.add,
    );
    client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(InternetAddress(server.path, type: InternetAddressType.unix), 0);
  });
  tearDown(() async {
    printOnFailure('The broker logged:\n${lines.join('\n')}');
    client.close(force: true);
    await server.close();
    oidc.close();
    await provider.close();
    await store.close();
    dir.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> send(String method, String path, {String? cookie, String? form}) async {
    final request = await client.openUrl(method, Uri.parse('http://broker$path'));
    request.followRedirects = false;
    if (cookie != null) request.headers.set(HttpHeaders.cookieHeader, cookie);
    if (form != null) {
      request.headers
        ..set('origin', _origin)
        ..contentType = ContentType('application', 'x-www-form-urlencoded');
      request.write(form);
    }
    final response = await request.close();
    await response.drain<void>();
    return response;
  }

  /// Starts a sign-in: the provider URL the broker sends the browser to, and
  /// the cookie that binds the flow to this browser.
  Future<({Uri authorization, String cookie})> start({String next = '/u/0/w/clide/'}) async {
    final response = await send('GET', '/auth/oidc?next=${Uri.encodeQueryComponent(next)}');
    expect(response.statusCode, HttpStatus.found);
    return (
      authorization: Uri.parse(response.headers.value(HttpHeaders.locationHeader)!),
      cookie: response.headers[HttpHeaders.setCookieHeader]!.single.split(';').first,
    );
  }

  /// Brings the browser back from the provider with [query].
  Future<HttpClientResponse> back(Map<String, String> query, {String? cookie}) =>
      send('GET', '/auth/callback?${Uri(queryParameters: query).query}', cookie: cookie);

  /// A whole sign-in in which the provider puts [claims] in the ID token.
  Future<HttpClientResponse> signIn([Map<String, Object?> claims = const {}]) async {
    final flow = await start();
    final code = provider.authorize(flow.authorization, now: now, claims: claims);
    return back({'code': code, 'state': flow.authorization.queryParameters['state']!}, cookie: flow.cookie);
  }

  String? location(HttpClientResponse response) => response.headers.value(HttpHeaders.locationHeader);

  List<String> cookies(HttpClientResponse response) => response.headers[HttpHeaders.setCookieHeader] ?? const [];

  String? sessionCookie(HttpClientResponse response) =>
      cookies(response).where((c) => c.startsWith('__Host-clide_session=')).map((c) => c.split(';').first).firstOrNull;

  test('signs a browser in: discovery, PKCE, the code exchange and the claims', () async {
    final flow = await start();
    final query = flow.authorization.queryParameters;
    expect(flow.authorization.toString(), startsWith('${provider.issuer}authorize/?'));
    expect(query, allOf(containsPair('response_type', 'code'), containsPair('client_id', 'clide'), containsPair('redirect_uri', '$_origin/auth/callback')));
    expect(query, allOf(containsPair('scope', 'openid profile email'), containsPair('code_challenge_method', 'S256')));
    expect([looksLikeSecret(query['state']!), looksLikeSecret(query['nonce']!), query['state'] == query['nonce']], [true, true, false]);
    expect(flow.cookie, '__Host-clide_signin=${query['state']}');

    final code = provider.authorize(flow.authorization, now: now);
    final response = await back({'code': code, 'state': query['state']!}, cookie: flow.cookie);
    expect([response.statusCode, location(response)], [HttpStatus.seeOther, '/u/0/w/clide/']);
    expect(cookies(response), contains('__Host-clide_signin=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0'));
    final session = sessionCookie(response)!;
    final verified = await send('GET', '/auth/verify', cookie: session);
    expect(verified.statusCode, HttpStatus.ok);
    expect((await store.session(secretHash(session.split('=').last)))!.subject, 'subject-1');
    expect(lines, contains('user 0 signed in by OIDC'));

    final exchange = provider.tokenRequests.single;
    expect(exchange.authorization, 'Basic ${base64.encode(utf8.encode('clide:client+secret'))}');
    expect(exchange.form, allOf(containsPair('grant_type', 'authorization_code'), isNot(contains('client_id'))));
  });

  test('a public client names itself in the form, and sends no secret', () async {
    await serve(settings(secret: null));
    expect(sessionCookie(await signIn()), isNotNull);
    final exchange = provider.tokenRequests.single;
    expect([exchange.authorization, exchange.form['client_id']], [null, 'clide']);
  });

  test('lets in a verified listed email and a member of a listed group, and nobody else', () async {
    expect(sessionCookie(await signIn({'sub': 'x', 'email': 'Owner@example.com', 'email_verified': true})), isNotNull);
    expect(
      sessionCookie(
        await signIn({
          'sub': 'y',
          'groups': ['clide-users'],
        }),
      ),
      isNotNull,
    );
    for (final claims in [
      {'sub': 'z'},
      {'sub': 'z', 'email': 'owner@example.com', 'email_verified': false},
    ]) {
      final response = await signIn(claims);
      expect([location(response), sessionCookie(response)], ['/auth/login?error=denied&next=%2Fu%2F0%2Fw%2Fclide%2F', null], reason: '$claims');
    }
    expect(lines, contains('an OIDC sign-in by subject "z" is not on the allowlist'));
  });

  group('refuses', () {
    test('a callback this browser did not start: another state, or no cookie', () async {
      final flow = await start();
      final state = flow.authorization.queryParameters['state']!;
      final code = provider.authorize(flow.authorization, now: now);
      for (final (query, cookie) in [
        ({'code': code, 'state': randomSecret()}, flow.cookie),
        ({'code': code, 'state': state}, null),
        ({'code': code, 'state': state}, '__Host-clide_signin=${randomSecret()}'),
      ]) {
        final response = await back(query, cookie: cookie);
        expect([location(response), sessionCookie(response)], ['/auth/login?error=expired', null]);
      }
      expect(provider.tokenRequests, isEmpty);
    });

    test('a callback used twice', () async {
      final flow = await start();
      final query = {'code': provider.authorize(flow.authorization, now: now), 'state': flow.authorization.queryParameters['state']!};
      expect(sessionCookie(await back(query, cookie: flow.cookie)), isNotNull);
      expect(location(await back(query, cookie: flow.cookie)), '/auth/login?error=expired');
    });

    test('a sign-in that took longer than ten minutes', () async {
      final flow = await start();
      final code = provider.authorize(flow.authorization, now: now);
      now = now.add(const Duration(minutes: 10, seconds: 1));
      expect(location(await back({'code': code, 'state': flow.authorization.queryParameters['state']!}, cookie: flow.cookie)), '/auth/login?error=expired');
    });

    test("an ID token that fails a claim check: nonce, audience, party, expiry, issuer", () async {
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      for (final (claims, logged) in [
        ({'nonce': 'another'}, 'another nonce'),
        ({'aud': 'another-client'}, 'not for this client'),
        (
          {
            'aud': ['clide', 'another-client'],
          },
          'other clients too',
        ),
        ({'azp': 'another-client'}, 'issued to another client'),
        ({'exp': seconds - 120}, 'has expired'),
        ({'iss': 'https://elsewhere.example/'}, 'issued by'),
      ]) {
        final response = await signIn(claims);
        expect([location(response), sessionCookie(response)], ['/auth/login?error=provider&next=%2Fu%2F0%2Fw%2Fclide%2F', null], reason: logged);
        expect(lines.last, contains(logged));
      }
    });

    test('the provider saying no, or an iss that names another provider', () async {
      for (final extra in [
        {'error': 'access_denied', 'code': 'x'},
        {'code': 'x', 'iss': 'https://elsewhere.example/'},
      ]) {
        final flow = await start();
        final response = await back({...extra, 'state': flow.authorization.queryParameters['state']!}, cookie: flow.cookie);
        expect(location(response), '/auth/login?error=provider&next=%2Fu%2F0%2Fw%2Fclide%2F', reason: '$extra');
      }
      expect(provider.tokenRequests, isEmpty);
    });

    test('a provider that cannot be reached, or whose certificate this install does not trust', () async {
      await serve(settings(trusted: false));
      var response = await send('GET', '/auth/oidc?next=%2F');
      expect(location(response), '/auth/login?error=provider&next=%2F');
      expect(lines.last, contains('failed its TLS check'));
      final gone = settings();
      await provider.close();
      await serve(gone);
      response = await send('GET', '/auth/oidc?next=%2F');
      expect(location(response), '/auth/login?error=provider&next=%2F');
      expect(lines.last, contains('cannot be reached'));
    });

    test('a discovery document behind a redirect', () async {
      provider.movedDiscovery = true;
      expect(location(await send('GET', '/auth/oidc?next=%2F')), '/auth/login?error=provider&next=%2F');
      expect(lines.last, contains('discovery answered 302'));
    });

    test('a code the provider did not issue, which its token endpoint refuses', () async {
      final flow = await start();
      final response = await back({'code': 'never-issued', 'state': flow.authorization.queryParameters['state']!}, cookie: flow.cookie);
      expect(location(response), '/auth/login?error=provider&next=%2Fu%2F0%2Fw%2Fclide%2F');
      expect(lines.last, contains('the token endpoint answered 400 ("invalid_grant")'));
    });

    test('a discovery answer that is not JSON, not an object, or too large', () async {
      for (final (body, logged) in [
        ('<html>a sign-in page</html>', 'something other than JSON'),
        ('["not", "an", "object"]', 'not an object'),
        ('"${'x' * OidcClient.answerLimit}"', 'more than 1024 KiB'),
      ]) {
        provider.discoveryBody = body;
        await serve(settings());
        expect(location(await send('GET', '/auth/oidc?next=%2F')), '/auth/login?error=provider&next=%2F', reason: logged);
        expect(lines.last, contains(logged));
      }
    });

    test('a provider that answers too slowly', () async {
      provider.delay = const Duration(seconds: 2);
      await serve(settings(), timeout: const Duration(seconds: 1));
      expect(location(await send('GET', '/auth/oidc?next=%2F')), '/auth/login?error=provider&next=%2F');
      expect(lines.last, contains('did not answer within 1 s'));
    });

    test('a discovery document for another issuer, with an http endpoint, without S256, or without the code flow', () async {
      for (final (change, logged) in [
        ({'issuer': 'https://elsewhere.example/'}, 'names its issuer'),
        ({'token_endpoint': 'http://localhost/token'}, 'token_endpoint is not an https URL'),
        (
          {
            'code_challenge_methods_supported': ['plain'],
          },
          'PKCE with S256',
        ),
        (
          {
            'response_types_supported': ['id_token'],
          },
          'authorization code flow',
        ),
      ]) {
        provider.discovery = change;
        await serve(settings());
        expect(location(await send('GET', '/auth/oidc?next=%2F')), '/auth/login?error=provider&next=%2F', reason: logged);
        expect(lines.last, contains(logged));
      }
    });
  });

  test('asks for the discovery document once an hour', () async {
    await start();
    await start();
    expect(provider.discoveries, 1);
    now = now.add(OidcClient.discoveryLifetime);
    await start();
    expect(provider.discoveries, 2);
  });

  test('the sign-in page sends the browser to the provider, and still takes a single-use link', () async {
    final request = await client.openUrl('GET', Uri.parse('http://broker/auth/login?next=%2Fu%2F0%2F'));
    final page = await (await request.close()).transform(utf8.decoder).join();
    expect(page, allOf(contains('href="/auth/oidc?next=%2Fu%2F0%2F"'), isNot(contains('Access token'))));
    // The page's script moves a link from the fragment into this form.
    expect(page, allOf(contains('<form id="signin" method="post" action="/auth/login" hidden>'), contains('<input name="token" type="hidden">')));
    final link = randomSecret();
    await store.putSigninLink(secretHash(link), 0, now.add(const Duration(minutes: 10)));
    expect(sessionCookie(await send('POST', '/auth/login', form: 'token=$link&next=%2F')), isNotNull);
  });

  test('token mode has no OIDC flow', () async {
    await serve(null);
    expect((await send('GET', '/auth/oidc')).statusCode, HttpStatus.notFound);
    expect((await send('GET', '/auth/callback?code=x&state=y')).statusCode, HttpStatus.notFound);
  });
}
