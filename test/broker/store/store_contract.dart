/// The broker store's behaviour on any engine (D-121). The SQLite suite runs
/// it, and the Postgres suite runs it again against a server.
library;

import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/sql.dart';
import 'package:test/test.dart';

void storeContract(Future<SqlConnection> Function() connect) {
  late SqlConnection sql;
  late BrokerStore store;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 9, 24, 12);
    sql = await connect();
    store = BrokerStore(sql, clock: () => now);
    await store.migrate();
  });
  tearDown(() => store.close());

  StoredSession session(String idHash, {int user = 0, Duration lifetime = const Duration(hours: 1), String via = 'token', String? subject}) =>
      StoredSession(idHash: idHash, user: user, via: via, subject: subject, createdAt: now, expiresAt: now.add(lifetime));

  Future<int> count(String table) async => (await sql.select('SELECT COUNT(*) AS n FROM $table')).single['n']! as int;

  group('migrations', () {
    test('a second run changes nothing', () async {
      await store.migrate();
      final versions = await sql.select('SELECT version FROM broker_schema ORDER BY version');
      expect([for (final r in versions) r['version']], List.generate(BrokerStore.schemaVersion, (i) => i + 1));
    });

    test('a store with a newer schema than this broker knows is refused', () async {
      await sql.execute(r'INSERT INTO broker_schema (version) VALUES ($1)', [BrokerStore.schemaVersion + 1]);
      await expectLater(store.migrate(), throwsA(isA<StoreSchemaException>()));
    });
  });

  test('settings are stored, replaced, listed in key order and deleted', () async {
    await store.putSetting('signin.mode', 'token');
    await store.putSetting('public_origin', 'https://a.example');
    await store.putSetting('signin.mode', 'oidc');
    expect(await store.settings(), {'public_origin': 'https://a.example', 'signin.mode': 'oidc'});
    expect((await store.settings()).keys, ['public_origin', 'signin.mode']);
    expect(await store.deleteSetting('public_origin'), isTrue);
    expect(await store.deleteSetting('public_origin'), isFalse);
    expect(await store.settings(), {'signin.mode': 'oidc'});
  });

  test("rotating a token replaces its hash and ends that user's sessions, and only theirs", () async {
    expect(await store.tokenHash(0), isNull);
    await store.rotateToken(0, 'first');
    await store.putSession(session('user0'));
    await store.putSession(session('user1', user: 1));
    await store.rotateToken(0, 'second');
    expect(await store.tokenHash(0), 'second');
    expect(await store.session('user0'), isNull);
    expect(await store.session('user1'), isNotNull);
  });

  group('sessions', () {
    test('a session is found until it expires, with what it was stored with', () async {
      await store.putSession(session('s', via: 'oidc', subject: 'sub-1'));
      final found = await store.session('s');
      expect([found!.user, found.via, found.subject, found.createdAt, found.expiresAt], [0, 'oidc', 'sub-1', now, now.add(const Duration(hours: 1))]);
      now = now.add(const Duration(hours: 1));
      expect(await store.session('s'), isNull);
    });

    test('ending a session removes it, once', () async {
      await store.putSession(session('s'));
      expect(await store.endSession('s'), isTrue);
      expect(await store.endSession('s'), isFalse);
      expect(await store.session('s'), isNull);
    });
  });

  group('single-use links', () {
    test('a link signs its user in once', () async {
      await store.putSigninLink('link', 0, now.add(const Duration(minutes: 10)));
      expect(await store.useSigninLink('link'), 0);
      expect(await store.useSigninLink('link'), isNull);
    });

    test('an expired link signs no one in', () async {
      await store.putSigninLink('link', 0, now.add(const Duration(minutes: 10)));
      now = now.add(const Duration(minutes: 10));
      expect(await store.useSigninLink('link'), isNull);
    });

    test('of two requests racing for one link, exactly one wins', () async {
      await store.putSigninLink('link', 0, now.add(const Duration(minutes: 10)));
      final results = await Future.wait([store.useSigninLink('link'), store.useSigninLink('link')]);
      expect(results.where((user) => user != null), hasLength(1));
    });
  });

  group('OIDC sign-ins in progress', () {
    OidcPending pending(String stateHash) =>
        OidcPending(stateHash: stateHash, nonce: 'n', verifier: 'v', nextPath: '/u/0/w/clide/', expiresAt: now.add(const Duration(minutes: 10)));

    test('one is taken once, with everything it held', () async {
      await store.putOidcPending(pending('state'));
      final taken = await store.takeOidcPending('state');
      expect([taken!.nonce, taken.verifier, taken.nextPath, taken.expiresAt], ['n', 'v', '/u/0/w/clide/', now.add(const Duration(minutes: 10))]);
      expect(await store.takeOidcPending('state'), isNull);
    });

    test('an expired one is not taken', () async {
      await store.putOidcPending(pending('state'));
      now = now.add(const Duration(minutes: 11));
      expect(await store.takeOidcPending('state'), isNull);
    });
  });

  test('sweeping removes what has expired and keeps what has not', () async {
    await store.putSession(session('short', lifetime: const Duration(minutes: 5)));
    await store.putSession(session('long', lifetime: const Duration(hours: 5)));
    await store.putSigninLink('short', 0, now.add(const Duration(minutes: 5)));
    await store.putSigninLink('long', 0, now.add(const Duration(hours: 5)));
    await store.putOidcPending(OidcPending(stateHash: 'short', nonce: 'n', verifier: 'v', nextPath: '/', expiresAt: now.add(const Duration(minutes: 5))));
    now = now.add(const Duration(minutes: 5));
    expect(await store.sweep(), 3);
    expect([await count('broker_sessions'), await count('broker_signin_links'), await count('broker_oidc_pending')], [1, 1, 0]);
    expect(await store.session('long'), isNotNull);
  });
}
