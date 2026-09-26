import 'dart:io';

import 'package:clide/src/broker/auth/secrets.dart';
import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/serve_config.dart';
import 'package:clide/src/broker/settings.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late BrokerStore store;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('clide-serve-config-');
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'));
  });
  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });

  Future<ServeConfig> resolve([Map<String, String> environment = const {}]) => ServeConfig.resolve(BrokerSettings(store, environment), store);

  Matcher refusedWith(List<String> parts) =>
      throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', allOf([for (final p in parts) contains(p)])));

  test('names everything that is missing at once', () async {
    await expectLater(
      resolve(),
      refusedWith(['The broker will not start', 'public_origin is not set', 'CLIDE_BROKER_PUBLIC_ORIGIN', 'signin.mode is not set']),
    );
  });

  test('token mode needs an issued token', () async {
    final environment = {'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.example.com', 'CLIDE_BROKER_SIGNIN_MODE': 'token'};
    await expectLater(resolve(environment), refusedWith(['clide_broker token rotate']));
    await store.rotateToken(0, secretHash('t' * 43));
    final config = await resolve(environment);
    expect([config.publicOrigin, config.mode, config.sessionLifetime], ['https://clide.example.com', SigninMode.token, const Duration(hours: 336)]);
  });

  group('OIDC mode', () {
    const oidc = {'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.example.com', 'CLIDE_BROKER_SIGNIN_MODE': 'oidc'};
    const provider = {'CLIDE_BROKER_OIDC_ISSUER': 'https://auth.example.com/application/o/clide/', 'CLIDE_BROKER_OIDC_CLIENT_ID': 'clide'};

    test('names a missing issuer, client and allowlist at once', () async {
      await expectLater(resolve(oidc), refusedWith(['oidc.issuer is not set', 'oidc.client_id is not set', 'OIDC mode needs an allowlist']));
    });

    test('refuses an http issuer, and a CA file that is not there', () async {
      await expectLater(
        resolve({
          ...oidc,
          ...provider,
          'CLIDE_BROKER_OIDC_ISSUER': 'http://auth.example.com/',
          'CLIDE_BROKER_OIDC_ALLOW_SUBJECTS': 'subject-1',
          'CLIDE_BROKER_OIDC_CA_FILE': '${dir.path}/missing.pem',
        }),
        refusedWith(['oidc.issuer: must be an https URL', 'there is no file at ${dir.path}/missing.pem']),
      );
    });

    test('reads the provider and the allowlist, with emails in lower case and blanks dropped', () async {
      File('${dir.path}/ca.pem').writeAsStringSync('');
      final config = await resolve({
        ...oidc,
        ...provider,
        'CLIDE_BROKER_OIDC_CLIENT_SECRET': 'client secret',
        'CLIDE_BROKER_OIDC_ALLOW_SUBJECTS': ' subject-1, subject-2,,',
        'CLIDE_BROKER_OIDC_ALLOW_EMAILS': 'Owner@Example.com',
        'CLIDE_BROKER_OIDC_ALLOW_GROUPS': 'clide-users',
        'CLIDE_BROKER_OIDC_CA_FILE': '${dir.path}/ca.pem',
      });
      final settings = config.oidc!;
      expect(config.mode, SigninMode.oidc);
      expect(
        [settings.issuer, settings.clientId, settings.clientSecret, settings.scopes, settings.groupsClaim, settings.caFile],
        [
          'https://auth.example.com/application/o/clide/',
          'clide',
          'client secret',
          ['openid', 'profile', 'email'],
          'groups',
          '${dir.path}/ca.pem',
        ],
      );
      expect(
        [settings.subjects, settings.emails, settings.groups],
        [
          {'subject-1', 'subject-2'},
          {'owner@example.com'},
          {'clide-users'},
        ],
      );
    });

    test('takes an allowlist of any one kind, and needs no client secret', () async {
      final config = await resolve({...oidc, ...provider, 'CLIDE_BROKER_OIDC_ALLOW_GROUPS': 'clide-users'});
      expect([config.oidc!.clientSecret, config.oidc!.hasAllowlist], [null, true]);
    });
  });

  test('reports an invalid value rather than starting on it', () async {
    await store.rotateToken(0, secretHash('t' * 43));
    await expectLater(
      resolve({'CLIDE_BROKER_PUBLIC_ORIGIN': 'http://clide.example.com', 'CLIDE_BROKER_SIGNIN_MODE': 'token', 'CLIDE_BROKER_SESSION_LIFETIME_HOURS': '0'}),
      refusedWith(['public_origin: must be an https origin', 'session.lifetime_hours: must be a whole number']),
    );
  });

  test('keeps the origin in the form a browser sends it', () async {
    await store.rotateToken(0, secretHash('t' * 43));
    final config = await resolve({'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://Clide.Example.com:443/', 'CLIDE_BROKER_SIGNIN_MODE': 'token'});
    expect(config.publicOrigin, 'https://clide.example.com');
    final withPort = await resolve({'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://localhost:8443', 'CLIDE_BROKER_SIGNIN_MODE': 'token'});
    expect(withPort.publicOrigin, 'https://localhost:8443');
  });
}
