import 'dart:io';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/settings.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late BrokerStore store;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('clide-settings-');
    store = await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'));
  });
  tearDown(() async {
    await store.close();
    dir.deleteSync(recursive: true);
  });

  BrokerSettings settings([Map<String, String> environment = const {}, String Function(String path)? readFile]) =>
      BrokerSettings(store, environment, readFile: readFile);

  Matcher refusedWith(String part) => throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains(part)));

  test('the environment overrides the store, which overrides the default', () async {
    Future<(String?, SettingSource)> lifetime(BrokerSettings s) async {
      final v = await s.get('session.lifetime_hours');
      return (v.value, v.source);
    }

    expect(await lifetime(settings()), ('336', SettingSource.fallback));
    expect(await settings().set('session.lifetime_hours', '24'), isNull);
    expect(await lifetime(settings()), ('24', SettingSource.store));
    final overridden = settings({'CLIDE_BROKER_SESSION_LIFETIME_HOURS': '12'});
    expect(await lifetime(overridden), ('12', SettingSource.environment));
    expect(await overridden.set('session.lifetime_hours', '48'), 'CLIDE_BROKER_SESSION_LIFETIME_HOURS');
    expect(await lifetime(settings()), ('48', SettingSource.store));
  });

  test('an empty variable counts as unset', () async {
    await settings().set('signin.mode', 'token');
    expect((await settings({'CLIDE_BROKER_SIGNIN_MODE': ''}).get('signin.mode')).source, SettingSource.store);
  });

  test('unsetting removes the stored value and says whether there was one', () async {
    await settings().set('signin.mode', 'token');
    expect(await settings().unset('signin.mode'), isTrue);
    expect(await settings().unset('signin.mode'), isFalse);
    expect((await settings().get('signin.mode')).source, SettingSource.unset);
  });

  group('a secret', () {
    test('comes from its own variable, or from the file its _FILE variant names', () async {
      final direct = await settings({'CLIDE_BROKER_OIDC_CLIENT_SECRET': 'hunter2'}).get('oidc.client_secret');
      expect([direct.value, direct.source], ['hunter2', SettingSource.environment]);
      String secrets(String path) => path == '/run/secrets/oidc' ? 'hunter2\n' : throw FileSystemException('missing', path);
      final fromFile = await settings({'CLIDE_BROKER_OIDC_CLIENT_SECRET_FILE': '/run/secrets/oidc'}, secrets).get('oidc.client_secret');
      expect(fromFile.value, 'hunter2');
    });

    test('is never stored, and one found in the store is ignored', () async {
      await expectLater(settings().set('oidc.client_secret', 'hunter2'), refusedWith('CLIDE_BROKER_OIDC_CLIENT_SECRET'));
      await expectLater(settings().unset('oidc.client_secret'), refusedWith('never stored'));
      expect(await store.settings(), isEmpty);
      await store.putSetting('oidc.client_secret', 'planted');
      final resolved = await settings().get('oidc.client_secret');
      expect([resolved.value, resolved.source], [null, SettingSource.unset]);
      final listed = (await settings().all()).singleWhere((s) => s.spec.key == 'oidc.client_secret');
      expect([listed.value, listed.source], [null, SettingSource.unset]);
    });

    test('is never shown', () async {
      final all = await settings({'CLIDE_BROKER_OIDC_CLIENT_SECRET': 'hunter2'}).all();
      expect(all.map((s) => s.shown), isNot(contains('hunter2')));
      expect(all.singleWhere((s) => s.spec.key == 'oidc.client_secret').shown, '(set)');
      expect((await settings().get('oidc.client_secret')).shown, '(unset)');
    });

    test('set both ways at once is reported, not guessed at', () async {
      final s = await settings({'CLIDE_BROKER_OIDC_CLIENT_SECRET': 'a', 'CLIDE_BROKER_OIDC_CLIENT_SECRET_FILE': '/x'}).get('oidc.client_secret');
      expect([s.value, s.shown], [null, '(invalid)']);
      expect(s.problem, contains('not both'));
    });
  });

  test('values are checked when they are set', () async {
    final s = settings();
    for (final (key, value) in [
      ('public_origin', 'http://clide.example.com'),
      ('public_origin', 'https://clide.example.com/app'),
      ('public_origin', 'https://user@clide.example.com'),
      ('signin.mode', 'basic'),
      ('session.lifetime_hours', '0'),
      ('session.lifetime_hours', '8761'),
      ('session.lifetime_hours', 'a day'),
      ('oidc.issuer', 'http://id.example.com'),
      ('oidc.scopes', 'profile email'),
      ('oidc.ca_file', 'ca.pem'),
    ]) {
      await expectLater(s.set(key, value), refusedWith(key), reason: '$key = $value');
    }
    for (final (key, value) in [
      ('public_origin', 'https://clide.example.com'),
      ('public_origin', 'https://localhost:8443/'),
      ('signin.mode', 'oidc'),
      ('session.lifetime_hours', '8760'),
      ('oidc.issuer', 'https://id.example.com/application/o/clide/'),
      ('oidc.scopes', 'openid email'),
      ('oidc.ca_file', '/clide/state/ca.pem'),
    ]) {
      await s.set(key, value);
    }
  });

  test('a bad value from the environment or the store is reported and not used', () async {
    final fromEnvironment = await settings({'CLIDE_BROKER_SIGNIN_MODE': 'basic'}).get('signin.mode');
    expect([fromEnvironment.value, fromEnvironment.source, fromEnvironment.shown], [null, SettingSource.environment, '(invalid)']);
    expect(fromEnvironment.problem, contains('token or oidc'));
    await store.putSetting('session.lifetime_hours', '0');
    final fromStore = await settings().get('session.lifetime_hours');
    expect([fromStore.value, fromStore.source], [null, SettingSource.store]);
  });

  test('an unknown key is refused', () async {
    expect(() => BrokerSettings.spec('signin.method'), refusedWith('no setting "signin.method"'));
    await expectLater(settings().set('signin.method', 'token'), refusedWith('no setting'));
  });

  test("every setting has its own variable, and none is the store's", () {
    final variables = brokerSettings.map((s) => s.variable).toList();
    expect(variables.toSet(), hasLength(variables.length));
    expect(variables, everyElement(startsWith('CLIDE_BROKER_')));
    expect(variables, everyElement(isNot(startsWith(StoreLocation.variable))));
  });
}
