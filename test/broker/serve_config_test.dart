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

  test('refuses OIDC mode until the broker can sign in with it', () async {
    await expectLater(resolve({'CLIDE_BROKER_PUBLIC_ORIGIN': 'https://clide.example.com', 'CLIDE_BROKER_SIGNIN_MODE': 'oidc'}), refusedWith(['OIDC']));
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
