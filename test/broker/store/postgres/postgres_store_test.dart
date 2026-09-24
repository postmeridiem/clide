/// The broker's store on a real Postgres (T-697). `make test-broker-postgres`
/// starts a throwaway server with TLS from a test CA and runs this file;
/// without that server the tests skip, unless CLIDE_TEST_POSTGRES_REQUIRED
/// is set, which makes a missing server a failure.
@Tags(['postgres'])
library;

import 'dart:io';
import 'dart:math';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:clide/src/broker/store/postgres/connection.dart';
import 'package:test/test.dart';

import '../store_contract.dart';

void main() {
  final environment = Platform.environment;
  final port = int.tryParse(environment['CLIDE_TEST_POSTGRES_PORT'] ?? '');
  final password = environment['CLIDE_TEST_POSTGRES_PASSWORD'];
  final ca = environment['CLIDE_TEST_POSTGRES_CA'];
  if (port == null || password == null || ca == null) {
    final required = environment['CLIDE_TEST_POSTGRES_REQUIRED'] == '1';
    test(
      'a Postgres test server is configured',
      () => fail('CLIDE_TEST_POSTGRES_PORT, _PASSWORD and _CA must be set'),
      skip: required ? false : 'no Postgres test server; `make test-broker-postgres` starts one',
    );
    return;
  }

  /// The test server's certificate names localhost, signed by the test CA.
  PostgresLocation at({String host = 'localhost', SslMode mode = SslMode.verifyFull, String? rootCert}) => PostgresLocation(
    user: 'postgres',
    host: host,
    port: port,
    database: 'postgres',
    sslMode: mode,
    sslRootCert: mode == SslMode.verifyFull ? rootCert ?? ca : null,
  );

  late PostgresConnection admin;
  late String schema;

  setUp(() async {
    admin = await PostgresConnection.open(at(), password: password);
    schema = 'clide_test_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    await admin.execute('CREATE SCHEMA $schema');
  });
  tearDown(() async {
    await admin.execute('DROP SCHEMA $schema CASCADE');
    await admin.close();
  });

  Future<PostgresConnection> connect() => PostgresConnection.open(at(), password: password, startupParameters: {'search_path': schema});

  group('on Postgres', () => storeContract(connect));

  test('of two brokers racing for one link, exactly one wins', () async {
    final first = BrokerStore(await connect());
    final second = BrokerStore(await connect());
    addTearDown(first.close);
    addTearDown(second.close);
    await first.migrate();
    await first.putSigninLink('link', 0, DateTime.now().add(const Duration(minutes: 10)));
    final results = await Future.wait([first.useSigninLink('link'), second.useSigninLink('link')]);
    expect(results.where((user) => user != null), hasLength(1));
  });

  test('two brokers migrating a new store at once apply each migration once', () async {
    final first = BrokerStore(await connect());
    final second = BrokerStore(await connect());
    addTearDown(first.close);
    addTearDown(second.close);
    await Future.wait([first.migrate(), second.migrate()]);
    final versions = await admin.select('SELECT version FROM $schema.broker_schema ORDER BY version');
    expect([for (final r in versions) r['version']], List.generate(BrokerStore.schemaVersion, (i) => i + 1));
  });

  group('TLS', () {
    Future<int> encrypted(PostgresConnection c) async =>
        (await c.select('SELECT CASE WHEN ssl THEN 1 ELSE 0 END AS ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()')).single['ssl']! as int;

    test('verify-full connects when the certificate chains to the trusted CA and names the host', () async {
      final c = await PostgresConnection.open(at(), password: password);
      addTearDown(c.close);
      expect(await encrypted(c), 1);
    });

    test('verify-full refuses a certificate from a CA it does not trust', () async {
      await expectLater(
        PostgresConnection.open(
          PostgresLocation(user: 'postgres', host: 'localhost', port: port, database: 'postgres'),
          password: password,
        ),
        throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('TLS with the server at localhost failed'))),
      );
    });

    test('verify-full refuses a host the certificate does not name', () async {
      await expectLater(PostgresConnection.open(at(host: '127.0.0.1'), password: password), throwsA(isA<PostgresConnectionException>()));
    });

    test('require encrypts without checking the certificate', () async {
      final c = await PostgresConnection.open(
        at(host: '127.0.0.1', mode: SslMode.require),
        password: password,
      );
      addTearDown(c.close);
      expect(await encrypted(c), 1);
    });

    test('disable connects without TLS', () async {
      final c = await PostgresConnection.open(at(mode: SslMode.disable), password: password);
      addTearDown(c.close);
      expect(await encrypted(c), 0);
    });
  });

  test('a wrong password is refused as configuration, without repeating it', () async {
    await expectLater(
      PostgresConnection.open(at(), password: 'not-the-password'),
      throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', allOf(contains('28P01'), isNot(contains('not-the-password'))))),
    );
  });

  test('a server error leaves the connection usable', () async {
    final c = await connect();
    addTearDown(c.close);
    await expectLater(c.select('SELEC 1'), throwsA(isA<PostgresException>().having((e) => e.code, 'code', '42601')));
    expect((await c.select('SELECT 2 AS two')).single, {'two': 2});
  });

  test('a failed statement inside a transaction rolls the whole transaction back', () async {
    final c = await connect();
    addTearDown(c.close);
    await c.execute('CREATE TABLE t (a INTEGER PRIMARY KEY)');
    await expectLater(
      c.transaction(() async {
        await c.execute(r'INSERT INTO t VALUES ($1)', [1]);
        await c.execute(r'INSERT INTO t VALUES ($1)', [1]);
      }),
      throwsA(isA<PostgresException>().having((e) => e.code, 'code', '23505')),
    );
    expect((await c.select('SELECT COUNT(*) AS n FROM t')).single['n'], 0);
  });

  test('a connection the server ends is opened again for a later statement', () async {
    final c = await connect();
    addTearDown(c.close);
    final pid = (await c.select('SELECT pg_backend_pid() AS pid')).single['pid']! as int;
    await admin.select(r'SELECT pg_terminate_backend($1)::int AS ended', [pid]);
    // The first statement may still meet the old socket; the one after must
    // run on a new connection.
    try {
      await c.select('SELECT 1 AS one');
    } on PostgresConnectionException {
      // expected when the close had not arrived yet
    }
    final again = (await c.select('SELECT pg_backend_pid() AS pid')).single['pid']! as int;
    expect(again, isNot(pid));
  });

  test('BrokerStore.open reads the password from the environment and migrates', () async {
    // No search_path here, so this store lives in the throwaway server's
    // public schema.
    final url = 'postgres://postgres@localhost:$port/postgres?sslrootcert=$ca';
    final store = await BrokerStore.open(StoreLocation.fromEnvironment({'CLIDE_BROKER_STORE': url}), environment: {'CLIDE_BROKER_STORE_PASSWORD': password});
    addTearDown(store.close);
    await store.putSetting('signin.mode', 'oidc');
    expect(await store.settings(), {'signin.mode': 'oidc'});
  });
}
