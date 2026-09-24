import 'dart:io';

import 'package:clide/src/broker/store/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late SqliteDatabase db;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-sqlite-');
    db = SqliteDatabase.open('${dir.path}/t.db');
  });
  tearDown(() {
    db.close();
    dir.deleteSync(recursive: true);
  });

  test('round-trips null, integers, booleans and text, empty and non-ASCII text included', () {
    db.execute('CREATE TABLE t (a, b, c, d, e)');
    db.execute('INSERT INTO t VALUES (?1, ?2, ?3, ?4, ?5)', [null, 1 << 40, true, '', 'grüße \u{1F600} a\u0000b']);
    expect(db.select('SELECT a, b, c, d, e FROM t').single, {'a': null, 'b': 1 << 40, 'c': 1, 'd': '', 'e': 'grüße \u{1F600} a\u0000b'});
  });

  test('a numbered parameter can appear more than once', () {
    expect(db.select('SELECT ?1 AS x, ?1 AS y, ?2 AS z', ['a', 2]).single, {'x': 'a', 'y': 'a', 'z': 2});
  });

  test('answers how many rows a statement changed', () {
    db.execute('CREATE TABLE t (a)');
    for (var i = 0; i < 3; i++) {
      db.execute('INSERT INTO t VALUES (?1)', [i]);
    }
    expect(db.execute('DELETE FROM t WHERE a < ?1', [2]), 2);
  });

  test('refuses a parameter list that does not fit the statement', () {
    expect(() => db.select('SELECT ?1, ?2', ['only one']), throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('takes 2 parameters'))));
  });

  test('refuses a second statement instead of silently dropping it, and runs neither', () {
    db.execute('CREATE TABLE t (a)');
    expect(
      () => db.execute('INSERT INTO t VALUES (1); INSERT INTO t VALUES (2)'),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('one statement'))),
    );
    expect(db.select('SELECT COUNT(*) AS n FROM t').single['n'], 0);
  });

  test("a failed statement carries SQLite's message and extended code", () {
    db.execute('CREATE TABLE t (a PRIMARY KEY)');
    db.execute('INSERT INTO t VALUES (1)');
    expect(
      () => db.execute('INSERT INTO t VALUES (1)'),
      throwsA(isA<SqliteException>().having((e) => e.code, 'code', 1555).having((e) => e.message, 'message', contains('UNIQUE'))),
    );
    expect(() => db.select('SELEC 1'), throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('syntax error'))));
  });

  test('binds only the types the store uses, and reads only those back', () {
    expect(() => db.select('SELECT ?1', [1.5]), throwsArgumentError);
    expect(() => db.select('SELECT 1.5 AS x'), throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('column x'))));
  });

  test('knows whether a transaction is open', () {
    expect(db.inTransaction, isFalse);
    db.execute('BEGIN');
    expect(db.inTransaction, isTrue);
    db.execute('ROLLBACK');
    expect(db.inTransaction, isFalse);
  });

  test('a closed database refuses further calls', () {
    db.close();
    expect(() => db.select('SELECT 1'), throwsStateError);
  });

  test("a path that cannot be opened reports SQLite's reason", () {
    expect(
      () => SqliteDatabase.open('${dir.path}/no/such/dir/t.db'),
      throwsA(isA<SqliteException>().having((e) => e.message, 'message', contains('cannot open'))),
    );
  });

  test('reports the library version', () {
    expect(SqliteDatabase.libraryVersion, matches(RegExp(r'^3\.\d+\.\d+')));
  });
}
