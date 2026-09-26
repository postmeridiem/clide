import 'dart:convert';

import 'package:clide/src/broker/auth/oidc.dart';
import 'package:test/test.dart';

/// OIDC's claim checks, PKCE and the allowlist (D-118), without a provider.
void main() {
  final now = DateTime.utc(2026, 9, 26, 12);
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  const issuer = 'https://auth.example.com/application/o/clide/';

  /// An ID token whose claims are the good ones with [changes] laid over
  /// them; a change to null removes that claim.
  String token(Map<String, Object?> changes, {int parts = 3}) {
    final claims = {'iss': issuer, 'aud': 'clide', 'sub': 'subject-1', 'nonce': 'n', 'iat': seconds, 'exp': seconds + 300, ...changes}
      ..removeWhere((key, value) => value == null);
    String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return [
      part({'alg': 'RS256'}),
      part(claims),
      'c2ln',
    ].take(parts).join('.');
  }

  OidcIdentity check(String idToken) => checkIdToken(idToken, issuer: issuer, clientId: 'clide', nonce: 'n', now: now);
  Matcher refused(String part) => throwsA(isA<OidcException>().having((e) => e.message, 'message', contains(part)));

  test("PKCE's S256 challenge matches RFC 7636's example", () {
    expect(pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'), 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });

  group('an ID token', () {
    test('passes with this issuer, audience and nonce and fresh times, and names who signed in', () {
      final who = check(
        token({
          'email': 'Owner@Example.com',
          'email_verified': true,
          'groups': ['a', 3, 'b'],
        }),
      );
      expect(
        [who.subject, who.email, who.emailVerified, who.groups],
        [
          'subject-1',
          'Owner@Example.com',
          true,
          ['a', 'b'],
        ],
      );
    });

    test('passes with its audience in a list, and this client as its authorized party', () {
      expect(
        check(
          token({
            'aud': ['clide'],
            'azp': 'clide',
          }),
        ).subject,
        'subject-1',
      );
    });

    test('is refused from another issuer', () {
      expect(() => check(token({'iss': 'https://elsewhere.example/'})), refused('issued by'));
    });

    test('is refused for another audience, for others as well, or for none', () {
      expect(() => check(token({'aud': 'other'})), refused('not for this client'));
      expect(
        () => check(
          token({
            'aud': ['clide', 'other'],
          }),
        ),
        refused('other clients too'),
      );
      expect(() => check(token({'aud': null})), refused('not for this client'));
    });

    test('is refused when issued to another party', () {
      expect(() => check(token({'azp': 'other'})), refused('another client'));
    });

    test('is refused once expired, allowing a minute of clock skew', () {
      expect(check(token({'exp': seconds - 59})).subject, 'subject-1');
      expect(() => check(token({'exp': seconds - 61})), refused('expired'));
    });

    test('is refused unless issued just now', () {
      expect(check(token({'iat': seconds + 59})).subject, 'subject-1');
      expect(() => check(token({'iat': seconds + 61})), refused('not issued just now'));
      expect(() => check(token({'iat': seconds - 601})), refused('not issued just now'));
      expect(() => check(token({'iat': null})), refused('no exp or iat'));
    });

    test('is refused with another nonce, or none', () {
      expect(() => check(token({'nonce': 'other'})), refused('another nonce'));
      expect(() => check(token({'nonce': null})), refused('another nonce'));
    });

    test('is refused without a subject', () {
      expect(() => check(token({'sub': ''})), refused('no subject'));
    });

    test('is refused when it is not a readable signed JWT', () {
      expect(() => check(token({}, parts: 2)), refused('not a signed JWT'));
      expect(() => check('a.!!!.c'), refused('cannot be read'));
      expect(() => check('a.WzFd.c'), refused('cannot be read'));
    });

    test('counts an email as verified only when the provider says so with true', () {
      expect(check(token({'email': 'owner@example.com', 'email_verified': 'true'})).emailVerified, isFalse);
    });
  });

  group('the allowlist', () {
    late OidcClient client;
    setUp(() {
      client = OidcClient(
        const OidcSettings(issuer: issuer, clientId: 'clide', subjects: {'subject-1'}, emails: {'owner@example.com'}, groups: {'clide-users'}),
        redirectUri: 'https://clide.test/auth/callback',
      );
    });
    tearDown(() => client.close());

    test('lets in a listed subject, a listed email the provider verified, in any case, and a member of a listed group', () {
      expect(client.allows(const OidcIdentity(subject: 'subject-1')), isTrue);
      expect(client.allows(const OidcIdentity(subject: 'x', email: 'Owner@Example.COM', emailVerified: true)), isTrue);
      expect(client.allows(const OidcIdentity(subject: 'x', groups: ['other', 'clide-users'])), isTrue);
    });

    test('keeps out anyone else, including a listed email the provider has not verified', () {
      expect(client.allows(const OidcIdentity(subject: 'x')), isFalse);
      expect(client.allows(const OidcIdentity(subject: 'x', email: 'owner@example.com')), isFalse);
      expect(client.allows(const OidcIdentity(subject: 'x', groups: ['other'])), isFalse);
    });
  });
}
