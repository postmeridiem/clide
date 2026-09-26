/// OpenID Connect sign-in (D-118): the authorization code flow with PKCE,
/// `state` and `nonce`, against a provider found by discovery. The ID token
/// comes straight from the token endpoint over verified TLS, which OpenID
/// Connect Core §3.1.3.7 accepts in place of checking its signature. Its
/// claims are still checked, and an allowlist decides who may sign in.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The provider, and who may sign in through it (D-118).
final class OidcSettings {
  const OidcSettings({
    required this.issuer,
    required this.clientId,
    this.clientSecret,
    this.scopes = const ['openid', 'profile', 'email'],
    this.subjects = const {},
    this.emails = const {},
    this.groups = const {},
    this.groupsClaim = 'groups',
    this.caFile,
  });

  /// The issuer, exactly as the provider names itself.
  final String issuer;
  final String clientId;

  /// Set for a confidential client, which the token endpoint then
  /// authenticates with HTTP Basic. A public client relies on PKCE alone.
  final String? clientSecret;
  final List<String> scopes;

  /// Subjects allowed in.
  final Set<String> subjects;

  /// Email addresses allowed in, in lower case, when the provider has
  /// verified them.
  final Set<String> emails;

  /// Groups whose members are allowed in.
  final Set<String> groups;

  /// The ID token claim that lists the groups.
  final String groupsClaim;

  /// A PEM file of extra certificate authorities for reaching the provider.
  final String? caFile;

  /// Whether anyone at all may sign in. OIDC mode refuses to start without it.
  bool get hasAllowlist => subjects.isNotEmpty || emails.isNotEmpty || groups.isNotEmpty;
}

/// A sign-in the provider did not complete, or answered in a way the broker
/// cannot accept. The message is for the broker's log: it says what failed
/// and never carries a secret.
final class OidcException implements Exception {
  OidcException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Who signed in, as the ID token says.
final class OidcIdentity {
  const OidcIdentity({required this.subject, this.email, this.emailVerified = false, this.groups = const []});

  final String subject;
  final String? email;
  final bool emailVerified;
  final List<String> groups;
}

/// The two endpoints the flow uses, from the provider's discovery document.
typedef OidcEndpoints = ({Uri authorization, Uri token});

final class OidcClient {
  /// A client for [settings], whose provider sends browsers back to
  /// [redirectUri]. Certificates are always checked: against the system's
  /// authorities, and the ones in the settings' CA file.
  OidcClient(this.settings, {required this.redirectUri, DateTime Function()? clock, this.timeout = const Duration(seconds: 10)})
    : _now = clock ?? DateTime.now,
      _http = _client(settings.caFile, timeout);

  final OidcSettings settings;
  final String redirectUri;

  /// How long each request to the provider may take.
  final Duration timeout;

  final DateTime Function() _now;
  final HttpClient _http;
  ({OidcEndpoints endpoints, DateTime at})? _discovered;

  /// How long a discovery document is reused.
  static const discoveryLifetime = Duration(hours: 1);

  /// The largest answer read from the provider.
  static const answerLimit = 1 << 20;

  static HttpClient _client(String? caFile, Duration timeout) {
    final context = SecurityContext(withTrustedRoots: true);
    if (caFile != null) context.setTrustedCertificates(caFile);
    return HttpClient(context: context)
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 15)
      ..userAgent = 'clide-broker';
  }

  void close() => _http.close(force: true);

  /// The provider's endpoints, from its discovery document. A document is
  /// reused for [discoveryLifetime]; a failure is not remembered, so the next
  /// sign-in asks again.
  Future<OidcEndpoints> endpoints() async {
    final discovered = _discovered;
    if (discovered != null && _now().difference(discovered.at) < discoveryLifetime) return discovered.endpoints;
    final issuer = settings.issuer;
    final base = issuer.endsWith('/') ? issuer.substring(0, issuer.length - 1) : issuer;
    final document = await _json('discovery', 'GET', Uri.parse('$base/.well-known/openid-configuration'));
    if (document['issuer'] != issuer) {
      throw OidcException('the provider names its issuer ${jsonEncode(document['issuer'])}, not ${jsonEncode(issuer)}');
    }
    final methods = document['code_challenge_methods_supported'];
    if (methods is List && !methods.contains('S256')) throw OidcException('the provider does not take PKCE with S256');
    final types = document['response_types_supported'];
    if (types is List && !types.contains('code')) throw OidcException('the provider does not offer the authorization code flow');
    final endpoints = (authorization: _https(document, 'authorization_endpoint'), token: _https(document, 'token_endpoint'));
    _discovered = (endpoints: endpoints, at: _now());
    return endpoints;
  }

  /// Where to send the browser to sign in, for a flow with [state], [nonce]
  /// and the PKCE [verifier].
  Future<Uri> authorizationUri({required String state, required String nonce, required String verifier}) async {
    final authorization = (await endpoints()).authorization;
    return authorization.replace(
      queryParameters: {
        ...authorization.queryParameters,
        'response_type': 'code',
        'client_id': settings.clientId,
        'redirect_uri': redirectUri,
        'scope': settings.scopes.join(' '),
        'state': state,
        'nonce': nonce,
        'code_challenge': pkceChallenge(verifier),
        'code_challenge_method': 'S256',
      },
    );
  }

  /// Exchanges [code] at the token endpoint, and answers who the ID token
  /// says signed in, once its claims have been checked against [nonce].
  Future<OidcIdentity> exchange({required String code, required String verifier, required String nonce}) async {
    final token = (await endpoints()).token;
    final secret = settings.clientSecret;
    final form = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': verifier,
      if (secret == null) 'client_id': settings.clientId,
    };
    final answer = await _json(
      'the token endpoint',
      'POST',
      token,
      body: Uri(queryParameters: form).query,
      headers: (headers) {
        headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        if (secret != null) {
          // RFC 6749 §2.3.1: each part form-encoded before Basic's base64.
          final pair = '${Uri.encodeQueryComponent(settings.clientId)}:${Uri.encodeQueryComponent(secret)}';
          headers.set(HttpHeaders.authorizationHeader, 'Basic ${base64.encode(utf8.encode(pair))}');
        }
      },
    );
    final idToken = answer['id_token'];
    if (idToken is! String) throw OidcException('the token endpoint answered without an ID token');
    return checkIdToken(idToken, issuer: settings.issuer, clientId: settings.clientId, nonce: nonce, now: _now(), groupsClaim: settings.groupsClaim);
  }

  /// Whether [identity] is on the allowlist: by subject, by an email address
  /// the provider has verified, or by a group.
  bool allows(OidcIdentity identity) {
    final email = identity.email;
    return settings.subjects.contains(identity.subject) ||
        (identity.emailVerified && email != null && settings.emails.contains(email.toLowerCase())) ||
        identity.groups.any(settings.groups.contains);
  }

  /// One JSON object from the provider, [what] naming the request in errors.
  /// A redirect, an error status, a large answer and a slow one are all
  /// refused.
  Future<Map<String, Object?>> _json(String what, String method, Uri uri, {String? body, void Function(HttpHeaders headers)? headers}) async {
    try {
      final request = await _http.openUrl(method, uri).timeout(timeout);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.acceptHeader, 'application/json');
      headers?.call(request.headers);
      if (body != null) request.write(body);
      final response = await request.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > answerLimit) throw OidcException('$what answered with more than ${answerLimit >> 10} KiB');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } on FormatException {
        throw OidcException('$what answered ${response.statusCode} with something other than JSON');
      }
      if (response.statusCode != HttpStatus.ok) {
        final error = decoded is Map ? decoded['error'] : null;
        throw OidcException('$what answered ${response.statusCode}${error is String ? ' (${jsonEncode(error)})' : ''}');
      }
      if (decoded is! Map<String, Object?>) throw OidcException('$what answered with JSON that is not an object');
      return decoded;
    } on TlsException catch (e) {
      throw OidcException('$what failed its TLS check: ${e.osError?.message ?? e.message}');
    } on SocketException catch (e) {
      throw OidcException('$what cannot be reached: ${e.osError?.message ?? e.message}');
    } on TimeoutException {
      throw OidcException('$what did not answer within ${timeout.inSeconds} s');
    } on HttpException catch (e) {
      throw OidcException('$what broke off: ${e.message}');
    }
  }

  static Uri _https(Map<String, Object?> document, String key) {
    final value = document[key];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.hasFragment) {
      throw OidcException('the provider\'s $key is not an https URL: ${jsonEncode(value)}');
    }
    return uri;
  }
}

/// PKCE's S256 challenge for [verifier] (RFC 7636 §4.2).
String pkceChallenge(String verifier) => base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');

/// How far the broker's clock and the provider's may disagree.
const idTokenLeeway = Duration(seconds: 60);

/// How old an ID token may be when the token endpoint hands it over.
const idTokenMaxAge = Duration(minutes: 10);

/// The identity in [idToken], once its claims pass OpenID Connect Core
/// §3.1.3.7: the issuer, this client as the only audience and any authorized
/// party, the expiry and issue time, and the [nonce] this flow sent. The
/// signature is not checked, which holds only for a token taken straight from
/// the token endpoint over verified TLS.
OidcIdentity checkIdToken(
  String idToken, {
  required String issuer,
  required String clientId,
  required String nonce,
  required DateTime now,
  String groupsClaim = 'groups',
}) {
  final parts = idToken.split('.');
  if (parts.length != 3) throw OidcException('the ID token is not a signed JWT');
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  } on FormatException {
    throw OidcException('the ID token cannot be read');
  }
  if (decoded is! Map<String, Object?>) throw OidcException('the ID token cannot be read');
  final claims = decoded;
  if (claims['iss'] != issuer) throw OidcException('the ID token was issued by ${jsonEncode(claims['iss'])}, not ${jsonEncode(issuer)}');
  final audience = claims['aud'];
  final audiences = audience is String ? [audience] : (audience is List ? audience : const []);
  if (!audiences.contains(clientId)) throw OidcException('the ID token is not for this client');
  if (audiences.any((a) => a != clientId)) throw OidcException('the ID token is for other clients too');
  final party = claims['azp'];
  if (party != null && party != clientId) throw OidcException('the ID token was issued to another client');
  final expires = claims['exp'];
  final issued = claims['iat'];
  if (expires is! num || issued is! num) throw OidcException('the ID token has no exp or iat');
  final seconds = now.millisecondsSinceEpoch / 1000;
  if (seconds > expires + idTokenLeeway.inSeconds) throw OidcException('the ID token has expired');
  if (issued > seconds + idTokenLeeway.inSeconds || issued < seconds - idTokenMaxAge.inSeconds) {
    throw OidcException('the ID token was not issued just now');
  }
  if (claims['nonce'] != nonce) throw OidcException('the ID token carries another nonce');
  final subject = claims['sub'];
  if (subject is! String || subject.isEmpty) throw OidcException('the ID token names no subject');
  final email = claims['email'];
  final groups = claims[groupsClaim];
  return OidcIdentity(
    subject: subject,
    email: email is String ? email : null,
    emailVerified: claims['email_verified'] == true,
    groups: groups is List
        ? [
            for (final group in groups)
              if (group is String) group,
          ]
        : const [],
  );
}
