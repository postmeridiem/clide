import 'dart:async';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:clide/src/broker/store/postgres/connection.dart';
import 'package:clide/src/broker/store/postgres/wire.dart';
import 'package:test/test.dart';

import 'scripted_server.dart';

void main() {
  late ScriptedServer server;

  tearDown(() => server.close());

  PostgresLocation at({SslMode mode = SslMode.disable}) => PostgresLocation(user: 'u', host: '127.0.0.1', port: server.port, database: 'd', sslMode: mode);

  Future<PostgresConnection> open({String? password = 'pw', SslMode mode = SslMode.disable, Duration timeout = const Duration(seconds: 5)}) =>
      PostgresConnection.open(
        at(mode: mode),
        password: password,
        timeout: timeout,
      );

  Matcher refusedWith(String part) => throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains(part)));

  group('sign-in', () {
    test('completes SCRAM-SHA-256 and sends the startup parameters the store needs', () async {
      late Map<String, String> startup;
      server = await ScriptedServer.start((c) async {
        startup = await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.untilClosed();
      });
      final connection = await open();
      await connection.close();
      expect(startup, {'user': 'u', 'database': 'd', 'application_name': 'clide-broker', 'client_encoding': 'UTF8'});
      expect(server.errors, isEmpty);
    });

    test('refuses a server whose SCRAM signature is not the verifier\'s', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw', wrongSignature: true);
        await c.untilClosed();
      });
      await expectLater(open(), throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('signature is wrong'))));
    });

    test('refuses a server that ends SCRAM before proving itself', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw', skipFinal: true);
        c.signedIn();
        await c.untilClosed();
      });
      await expectLater(open(), throwsA(isA<PostgresProtocolException>()));
    });

    test('refuses a server that skips authentication while a password is set', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.signedIn();
        await c.untilClosed();
      });
      await expectLater(open(), refusedWith('without proving who it is'));
    });

    test('accepts a server that asks for nothing when no password is set', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.signedIn();
        await c.untilClosed();
      });
      await (await open(password: null)).close();
    });

    test('never sends the password in clear text over a connection that is not verified TLS', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.authentication(3);
        await c.untilClosed();
      });
      await expectLater(open(), refusedWith('clear text'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.clients.single.received, isNot(contains(0x70)));
    });

    test('refuses MD5, an unknown method and a SASL list without SCRAM-SHA-256', () async {
      for (final (answer, expected) in <(void Function(FakeClient), String)>[
        ((c) => c.authentication(5, [1, 2, 3, 4]), 'MD5'),
        ((c) => c.authentication(7), 'does not support (code 7)'),
        ((c) => c.authentication(10, [...'SCRAM-SHA-256-PLUS'.codeUnits, 0, 0]), 'no SCRAM-SHA-256'),
      ]) {
        server = await ScriptedServer.start((c) async {
          await c.startup();
          answer(c);
          await c.untilClosed();
        });
        await expectLater(open(), refusedWith(expected));
        await server.close();
      }
      server = await ScriptedServer.start((c) async {});
    });

    test('asks for the password variable when the server wants one and none is set', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.authentication(10, [...'SCRAM-SHA-256'.codeUnits, 0, 0]);
        await c.untilClosed();
      });
      await expectLater(open(password: null), refusedWith('CLIDE_BROKER_STORE_PASSWORD'));
    });

    test('reports a refused password as configuration, and other sign-in errors with their code', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.error('28P01', 'password authentication failed');
        await c.untilClosed();
      });
      await expectLater(open(), refusedWith('28P01'));
      await server.close();
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.error('3D000', 'database "d" does not exist');
        await c.untilClosed();
      });
      await expectLater(open(), refusedWith('database "d" does not exist'));
    });

    test('refuses a password that is not printable ASCII before connecting', () async {
      server = await ScriptedServer.start((c) async {});
      await expectLater(open(password: 'grüße'), refusedWith('printable ASCII'));
      expect(server.clients, isEmpty);
    });

    test('refuses a server that will not use UTF8, or wants another protocol version', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn(encoding: 'LATIN1');
        await c.untilClosed();
      });
      await expectLater(open(), throwsA(isA<PostgresProtocolException>().having((e) => e.message, 'message', contains('UTF8'))));
      await server.close();
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.send(0x76, [0, 0, 0, 1, 0, 0, 0, 0]);
        await c.untilClosed();
      });
      await expectLater(open(), throwsA(isA<PostgresProtocolException>().having((e) => e.message, 'message', contains('protocol 3.0'))));
    });
  });

  group('TLS negotiation', () {
    test('a server that does not offer TLS is refused, with the way to opt out', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup(sslAnswer: [0x4E]);
      });
      await expectLater(open(mode: SslMode.verifyFull), refusedWith('add ?sslmode=disable'));
    });

    test('bytes after the one-byte answer are refused, not read as if TLS had protected them', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup(sslAnswer: [0x53, 0x45, 0, 0, 0, 4]);
      });
      await expectLater(
        open(mode: SslMode.require),
        throwsA(isA<PostgresProtocolException>().having((e) => e.message, 'message', contains('one-byte answer'))),
      );
    });

    test('an answer that is neither S nor N is refused', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup(sslAnswer: [0x45]);
      });
      await expectLater(open(mode: SslMode.require), throwsA(isA<PostgresProtocolException>()));
    });
  });

  group('statements', () {
    test('converts integers, text, NULL and void, and counts changed rows from the tag', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.query(
          columns: [('small', 21), ('n', 23), ('big', 20), ('s', 25), ('v', 1043), ('none', 25), ('nothing', 2278)],
          rows: [
            ['1', '-7', '9007199254740993', 'grüße', 'x', null, ''],
          ],
          tag: 'SELECT 1',
        );
        await c.query(tag: 'INSERT 0 3');
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      expect(await connection.select('SELECT …'), [
        {'small': 1, 'n': -7, 'big': 9007199254740993, 's': 'grüße', 'v': 'x', 'none': null, 'nothing': null},
      ]);
      expect(await connection.execute(r'INSERT …'), 3);
    });

    test('refuses a column type the store never reads', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.query(
          columns: [('flag', 16)],
          rows: [
            ['t'],
          ],
        );
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      await expectLater(connection.select('SELECT true AS flag'), throwsA(isA<PostgresException>().having((e) => e.message, 'message', contains('type 16'))));
    });

    test('a server error arrives as a PostgresException and the session stays in step', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.query(errorCode: '42601');
        await c.query(
          columns: [('n', 23)],
          rows: [
            ['1'],
          ],
          before: () {
            c.send(0x4E, [0x4D, ...'a notice'.codeUnits, 0, 0]);
            c.parameter('TimeZone', 'UTC');
          },
        );
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      await expectLater(connection.select('SELEC 1'), throwsA(isA<PostgresException>().having((e) => e.code, 'code', '42601')));
      expect(await connection.select('SELECT 1 AS n'), [
        {'n': 1},
      ]);
      expect(server.clients, hasLength(1));
    });

    test('an unexpected message ends the session, and the next statement opens a new one', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        if (server.clients.length == 1) {
          await c.query(before: () => c.send(0x57, [0, 0]));
        } else {
          await c.query(
            columns: [('n', 23)],
            rows: [
              ['2'],
            ],
          );
        }
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      await expectLater(connection.select('SELECT 1'), throwsA(isA<PostgresConnectionException>()));
      expect(await connection.select('SELECT 2 AS n'), [
        {'n': 2},
      ]);
      expect(server.clients, hasLength(2));
    });

    test('a message claiming more than the size limit ends the session', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.read();
        c.sendRaw([0x44, 0x7F, 0xFF, 0xFF, 0xFF]);
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      await expectLater(connection.select('SELECT 1'), throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('more than'))));
    });

    test('a server that stops answering times out and ends the session', () async {
      // Signs in without SCRAM: the timeout bounds sign-in too, and on a loaded
      // CI runner the scripted server's PBKDF2 alone can outlast a short one.
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.signedIn();
        await c.untilClosed();
      });
      final connection = await open(password: null, timeout: const Duration(seconds: 1));
      addTearDown(connection.close);
      await expectLater(
        connection.select('SELECT 1'),
        throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('no answer in time'))),
      );
    });

    test('a server that drops the connection during sign-in is reported as a lost connection', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
      });
      await expectLater(open(), throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('dropped the connection'))));
    });
  });

  group('BrokerStore.open', () {
    const password = {'CLIDE_BROKER_STORE_PASSWORD': 'pw'};
    Matcher unavailable(String part) => throwsA(isA<StoreUnavailableException>().having((e) => e.message, 'message', contains(part)));

    test('reports a server that breaks the protocol as unavailable', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.send(0x57, [0, 0]);
        await c.untilClosed();
      });
      await expectLater(BrokerStore.open(at(), environment: password), unavailable('broke the protocol'));
    });

    test('reports a server that refuses for a reason other than configuration as unavailable', () async {
      server = await ScriptedServer.start((c) async {
        await c.startup();
        c.error('53300', 'too many connections');
        await c.untilClosed();
      });
      await expectLater(BrokerStore.open(at(), environment: password), unavailable('53300'));
    });

    test('reports a schema the server will not let it create, and closes the connection', () async {
      final closed = Completer<void>();
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        await c.query(tag: 'BEGIN', status: 'T');
        await c.query(tag: 'SELECT 1', status: 'T');
        await c.query(errorCode: '42501', status: 'E');
        await c.query(tag: 'ROLLBACK');
        await c.untilClosed();
        closed.complete();
      });
      await expectLater(BrokerStore.open(at(), environment: password), unavailable('cannot be brought up to date'));
      await closed.future.timeout(const Duration(seconds: 5));
    });
  });

  group('transactions', () {
    test('commit, and COMMIT answered with ROLLBACK is a failed transaction', () async {
      final seen = <String>[];
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        seen.add(await c.query(tag: 'BEGIN', status: 'T'));
        seen.add(await c.query(tag: 'SELECT 1', status: 'T'));
        seen.add(await c.query(tag: 'COMMIT'));
        seen.add(await c.query(tag: 'BEGIN', status: 'T'));
        seen.add(await c.query(tag: 'ROLLBACK'));
        await c.untilClosed();
      });
      final connection = await open();
      addTearDown(connection.close);
      expect(await connection.transaction(() async => 'done', exclusive: true), 'done');
      await expectLater(connection.transaction(() async {}), throwsA(isA<PostgresException>().having((e) => e.message, 'message', contains('rolled back'))));
      expect(seen, ['BEGIN', r'SELECT pg_advisory_xact_lock($1)', 'COMMIT', 'BEGIN', 'COMMIT']);
    });

    test('a body that throws is rolled back, and a lost connection mid-transaction is not reopened', () async {
      final seen = <String>[];
      server = await ScriptedServer.start((c) async {
        await c.startup();
        await c.scram('pw');
        c.signedIn();
        seen.add(await c.query(tag: 'BEGIN', status: 'T'));
        seen.add(await c.query(tag: 'ROLLBACK'));
        seen.add(await c.query(tag: 'BEGIN', status: 'T'));
        // The connection drops with the transaction open.
      });
      final connection = await open();
      addTearDown(connection.close);
      await expectLater(connection.transaction(() async => throw StateError('boom')), throwsStateError);
      await expectLater(
        connection.transaction(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await connection.execute('INSERT …');
        }),
        throwsA(isA<PostgresConnectionException>().having((e) => e.message, 'message', contains('during a transaction'))),
      );
      expect(seen, ['BEGIN', 'ROLLBACK', 'BEGIN']);
    });
  });
}
