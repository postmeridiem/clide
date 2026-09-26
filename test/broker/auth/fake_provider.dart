/// A stand-in OpenID Connect provider for the broker's tests, over TLS from a
/// test CA: discovery, an authorization step the test takes by hand, and a
/// token endpoint that checks what a real one checks.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/auth/oidc.dart';

/// A certificate authority, and a certificate it signed for the name
/// localhost, made fresh with openssl in [directory].
final class TestCa {
  TestCa._(this.directory);

  final String directory;

  static Future<TestCa> create(String directory) async {
    Future<void> openssl(List<String> args) async {
      final r = await Process.run('openssl', args, workingDirectory: directory);
      if (r.exitCode != 0) throw StateError('openssl ${args.first} failed: ${r.stderr}');
    }

    await openssl(['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=clide broker test CA', '-keyout', 'ca.key', '-out', 'ca.crt']);
    await openssl(['req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost', '-keyout', 'server.key', '-out', 'server.csr']);
    File('$directory/san.ext').writeAsStringSync('subjectAltName=DNS:localhost\n');
    await openssl([
      'x509', '-req', '-in', 'server.csr', '-CA', 'ca.crt', '-CAkey', 'ca.key', '-CAcreateserial', //
      '-days', '1', '-extfile', 'san.ext', '-out', 'server.crt',
    ]);
    return TestCa._(directory);
  }

  /// The CA's certificate, for a client to trust.
  String get certificate => '$directory/ca.crt';

  SecurityContext serverContext() => SecurityContext()
    ..useCertificateChain('$directory/server.crt')
    ..usePrivateKey('$directory/server.key');
}

/// What the provider remembers about a code it issued.
typedef _Grant = ({String challenge, String redirectUri, Map<String, Object?> claims});

final class FakeProvider {
  FakeProvider._(this._server) : _port = _server.port {
    _server.listen(_handle);
  }

  static Future<FakeProvider> start(TestCa ca) async => FakeProvider._(await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ca.serverContext()));

  final HttpServer _server;

  /// Kept from the start: a slow answer can outlive the server.
  final int _port;

  String get issuer => 'https://localhost:$_port/application/o/clide/';

  Uri get _tokenEndpoint => Uri.parse('https://localhost:$_port/application/o/token/');

  /// Changes to the discovery document. A key set to null is left out.
  Map<String, Object?> discovery = {};

  /// Sent in place of the discovery document, when set.
  String? discoveryBody;

  /// How long the provider waits before it answers.
  Duration delay = Duration.zero;

  /// How many times the discovery document was asked for.
  var discoveries = 0;

  /// Answer discovery with a redirect to a copy of the document elsewhere.
  bool movedDiscovery = false;

  /// Every token request, as the provider received it.
  final tokenRequests = <({String? authorization, Map<String, String> form})>[];

  final _grants = <String, _Grant>{};

  /// Signs someone in for [authorization], the URL the broker sent the
  /// browser to, and answers the code the provider sends back. Its ID token
  /// carries this issuer, the client, the flow's nonce and a fresh `iat` and
  /// `exp` for [now], with [claims] laid over them.
  String authorize(Uri authorization, {required DateTime now, Map<String, Object?> claims = const {}}) {
    final query = authorization.queryParameters;
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final code = 'code-${_grants.length}';
    _grants[code] = (
      challenge: query['code_challenge']!,
      redirectUri: query['redirect_uri']!,
      claims: {'iss': issuer, 'aud': query['client_id'], 'sub': 'subject-1', 'nonce': query['nonce'], 'iat': seconds, 'exp': seconds + 300, ...claims},
    );
    return code;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response..headers.contentType = ContentType.json;
    await Future<void>.delayed(delay);
    switch (request.uri.path) {
      case '/application/o/clide/.well-known/openid-configuration' when movedDiscovery:
        response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, 'https://localhost:$_port/moved/.well-known/openid-configuration');
      case '/application/o/clide/.well-known/openid-configuration' when discoveryBody != null:
        discoveries++;
        response.write(discoveryBody);
      case '/application/o/clide/.well-known/openid-configuration' || '/moved/.well-known/openid-configuration':
        discoveries++;
        response.write(
          jsonEncode(
            {
              'issuer': issuer,
              'authorization_endpoint': '${issuer}authorize/',
              'token_endpoint': '$_tokenEndpoint',
              'response_types_supported': ['code'],
              'code_challenge_methods_supported': ['plain', 'S256'],
              ...discovery,
            }..removeWhere((key, value) => value == null),
          ),
        );
      case '/application/o/token/' when request.method == 'POST':
        final form = Uri.splitQueryString(await utf8.decoder.bind(request).join());
        tokenRequests.add((authorization: request.headers.value(HttpHeaders.authorizationHeader), form: form));
        final grant = _grants.remove(form['code']);
        final valid =
            grant != null &&
            form['grant_type'] == 'authorization_code' &&
            form['redirect_uri'] == grant.redirectUri &&
            pkceChallenge(form['code_verifier'] ?? '') == grant.challenge;
        if (valid) {
          response.write(jsonEncode({'access_token': 'not used', 'token_type': 'Bearer', 'id_token': _jwt(grant.claims)}));
        } else {
          response
            ..statusCode = HttpStatus.badRequest
            ..write(jsonEncode({'error': 'invalid_grant'}));
        }
      default:
        response.statusCode = HttpStatus.notFound;
    }
    try {
      await response.close();
    } on IOException {
      // The client gave up waiting, as a test of a slow provider means it to.
    }
  }

  /// A JWT with [claims] and a signature nobody checks: the broker takes the
  /// token straight from the token endpoint, over TLS (D-118).
  static String _jwt(Map<String, Object?> claims) {
    String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'RS256', 'typ': 'JWT'})}.${part(claims)}.bm90IGNoZWNrZWQ';
  }
}
