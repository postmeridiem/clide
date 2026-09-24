import 'dart:io';

import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:test/test.dart';

StoreLocation parse(String? value) => StoreLocation.fromEnvironment({'CLIDE_BROKER_STORE': ?value});

Matcher refusedWith(String part) => throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', contains(part)));

void main() {
  test('refuses to guess when the variable is missing or blank', () {
    expect(() => parse(null), refusedWith('CLIDE_BROKER_STORE is not set'));
    expect(() => parse('  '), refusedWith('CLIDE_BROKER_STORE is not set'));
  });

  test('reads a sqlite path in either spelling', () {
    expect((parse('sqlite:/clide/state/broker.db') as SqliteLocation).path, '/clide/state/broker.db');
    expect((parse('sqlite:///clide/state/broker.db') as SqliteLocation).path, '/clide/state/broker.db');
  });

  test('refuses a relative sqlite path', () {
    expect(() => parse('sqlite:broker.db'), refusedWith('absolute path'));
    expect(() => parse('sqlite:'), refusedWith('absolute path'));
  });

  test('reads a postgres URL', () {
    final p = parse('postgres://clide_user@db.internal:6543/clide?sslmode=require') as PostgresLocation;
    expect([p.user, p.host, p.port, p.database, p.sslMode, p.sslRootCert], ['clide_user', 'db.internal', 6543, 'clide', SslMode.require, null]);
    expect((parse('postgresql://clide_user@db/clide') as PostgresLocation).port, 5432);
  });

  test('verifies TLS unless the URL says otherwise', () {
    PostgresLocation at(String query) => parse('postgres://clide_user@db/clide$query') as PostgresLocation;
    expect(at('').sslMode, SslMode.verifyFull);
    expect(at('?sslmode=verify-full').sslMode, SslMode.verifyFull);
    expect(at('?sslmode=disable').sslMode, SslMode.disable);
    final pinned = at('?sslrootcert=/clide/state/ca.pem');
    expect([pinned.sslMode, pinned.sslRootCert], [SslMode.verifyFull, '/clide/state/ca.pem']);
  });

  test('refuses an sslmode it does not use, a misplaced or relative sslrootcert, and unknown options', () {
    expect(() => parse('postgres://u@db/clide?sslmode=prefer'), refusedWith('verify-full, require or disable'));
    expect(() => parse('postgres://u@db/clide?sslmode=require&sslrootcert=/ca.pem'), refusedWith('only sslmode=verify-full'));
    expect(() => parse('postgres://u@db/clide?sslrootcert=ca.pem'), refusedWith('absolute path'));
    expect(() => parse('postgres://u@db/clide?application_name=x'), refusedWith('does not know: application_name'));
  });

  test('refuses a URL that carries a password, without repeating it', () {
    expect(
      () => parse('postgres://clide_user:hunter2@db/clide'),
      throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', allOf(contains('CLIDE_BROKER_STORE_PASSWORD'), isNot(contains('hunter2'))))),
    );
  });

  test('refuses another scheme without repeating the value', () {
    expect(
      () => parse('mysql://root:hunter2@db/clide'),
      throwsA(isA<BrokerConfigException>().having((e) => e.message, 'message', allOf(contains('sqlite: or postgres://'), isNot(contains('hunter2'))))),
    );
  });

  test('refuses a postgres URL without a user, a host or exactly one database', () {
    expect(() => parse('postgres://db/clide'), refusedWith('names no user'));
    expect(() => parse('postgres://clide_user@/clide'), refusedWith('names no host'));
    expect(() => parse('postgres://clide_user@db'), refusedWith('one database'));
    expect(() => parse('postgres://clide_user@db/a/b'), refusedWith('one database'));
    expect(() => parse('postgres://clide_user@[::1/clide'), refusedWith('not a valid postgres:// URL'));
  });

  test('the password comes from its own variable, or from the file its _FILE variant names', () {
    const location = PostgresLocation(user: 'u', host: 'h', port: 5432, database: 'd');
    expect(location.password({}), isNull);
    expect(location.password({'CLIDE_BROKER_STORE_PASSWORD': 'pw'}), 'pw');
    String secrets(String path) => path == '/run/secrets/store' ? 'pw\n' : throw FileSystemException('missing', path);
    expect(location.password({'CLIDE_BROKER_STORE_PASSWORD_FILE': '/run/secrets/store'}, readFile: secrets), 'pw');
  });
}
