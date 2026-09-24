import 'dart:async';
import 'dart:io';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:clide/src/broker/store/sql.dart';
import 'package:test/test.dart';

import 'store_contract.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-store-');
    path = '${dir.path}/broker.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('on SQLite', () => storeContract(() => SqliteConnection.open(path)));

  test('a new store file is readable and writable by its owner only', () async {
    await (await SqliteConnection.open(path)).close();
    expect((FileStat.statSync(path).mode & 0x1ff).toRadixString(8), '600');
  }, testOn: '!windows');

  test('the store runs in WAL mode', () async {
    final sql = await SqliteConnection.open(path);
    addTearDown(sql.close);
    expect((await sql.select('PRAGMA journal_mode')).single.values.single, 'wal');
  });

  test('a second connection sees what the first wrote, as the CLI does beside a running broker', () async {
    final broker = BrokerStore(await SqliteConnection.open(path));
    final cli = BrokerStore(await SqliteConnection.open(path));
    addTearDown(broker.close);
    addTearDown(cli.close);
    await broker.migrate();
    await cli.migrate();
    await cli.putSetting('signin.mode', 'oidc');
    expect(await broker.settings(), {'signin.mode': 'oidc'});
  });

  group('transactions', () {
    late SqliteConnection sql;

    setUp(() async {
      sql = await SqliteConnection.open(path);
      await sql.execute('CREATE TABLE t (a INTEGER)');
    });
    tearDown(() => sql.close());

    Future<Object?> rows() async => (await sql.select('SELECT COUNT(*) AS n FROM t')).single['n'];

    test('one whose body throws is rolled back', () async {
      await expectLater(
        sql.transaction(() async {
          await sql.execute('INSERT INTO t VALUES (1)');
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(await rows(), 0);
    });

    test('a call made from outside waits until it has finished', () async {
      final gate = Completer<void>();
      final transaction = sql.transaction(() async {
        await sql.execute('INSERT INTO t VALUES (1)');
        await gate.future;
        await sql.execute('INSERT INTO t VALUES (2)');
      });
      final outside = rows();
      gate.complete();
      await transaction;
      expect(await outside, 2);
    });

    test('they do not nest', () async {
      await expectLater(sql.transaction(() => sql.transaction(() async {})), throwsStateError);
    });
  });

  test('opening refuses a Postgres location, which this broker cannot use yet', () async {
    await expectLater(
      BrokerStore.open(const PostgresLocation(user: 'u', host: 'h', port: 5432, database: 'd')),
      throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains('sqlite:'))),
    );
  });

  test('opening a location migrates the store', () async {
    final store = await BrokerStore.open(SqliteLocation(path));
    addTearDown(store.close);
    await store.putSetting('signin.mode', 'token');
    expect(await store.settings(), {'signin.mode': 'token'});
  });
}
