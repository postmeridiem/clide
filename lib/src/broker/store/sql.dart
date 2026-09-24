/// What the broker's store needs from a SQL engine (D-121), and the SQLite
/// engine behind it. Statements are written once, with `$1`-style
/// parameters, and run unchanged on either engine.
library;

import 'dart:async';
import 'dart:io';

import 'sqlite3.dart';

/// A connection to the engine that holds the broker's store.
///
/// Calls run one at a time, in the order they were made. A [transaction]
/// holds the connection until its body finishes, and statements its body
/// runs go inside it.
abstract interface class SqlConnection {
  /// Runs a statement that returns no rows and answers how many rows it
  /// changed.
  Future<int> execute(String sql, [List<Object?> params = const []]);

  /// Runs a query and answers its rows, each a map from column name to an
  /// `int`, a `String` or `null`.
  Future<List<Map<String, Object?>>> select(String sql, [List<Object?> params = const []]);

  /// Runs [body] in a transaction, committed when it completes and rolled
  /// back when it throws. [exclusive] also takes the lock that keeps two
  /// brokers from migrating one store at the same time.
  Future<T> transaction<T>(Future<T> Function() body, {bool exclusive = false});

  Future<void> close();
}

/// The store in one SQLite file, in WAL mode so that `clide_broker
/// settings` can write while the broker runs.
final class SqliteConnection implements SqlConnection {
  SqliteConnection._(this._db);

  /// Opens the store at [path]. A new file is created readable by its owner
  /// only, and SQLite gives its journal files the same mode.
  static Future<SqliteConnection> open(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      try {
        file.createSync();
      } on FileSystemException catch (e) {
        throw SqliteException('cannot open $path: ${e.osError?.message ?? e.message}');
      }
      await _ownerOnly(path);
    }
    final db = SqliteDatabase.open(path);
    try {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    } catch (_) {
      db.close();
      rethrow;
    }
    return SqliteConnection._(db);
  }

  final SqliteDatabase _db;
  final CallQueue _serial = CallQueue();

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) => _serial.run(() => _db.execute(_numbered(sql), params));

  @override
  Future<List<Map<String, Object?>>> select(String sql, [List<Object?> params = const []]) => _serial.run(() => _db.select(_numbered(sql), params));

  @override
  Future<T> transaction<T>(Future<T> Function() body, {bool exclusive = false}) => _serial.hold(() async {
    // IMMEDIATE takes the write lock now rather than at the first write, so
    // two brokers cannot both read the schema version and both migrate.
    _db.execute(exclusive ? 'BEGIN IMMEDIATE' : 'BEGIN');
    try {
      final result = await body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      if (_db.inTransaction) _db.execute('ROLLBACK');
      rethrow;
    }
  });

  @override
  Future<void> close() => _serial.run(_db.close);

  /// `$1` becomes `?1`: the same numbered parameter in SQLite's spelling.
  static String _numbered(String sql) => sql.replaceAllMapped(_dollar, (m) => '?${m[1]}');
  static final _dollar = RegExp(r'\$(\d+)');
}

/// Runs a connection's calls one at a time, in the order they were made. A
/// call made from inside [hold]'s body runs straight away, inside it,
/// rather than queueing behind it.
final class CallQueue {
  Future<void> _tail = Future.value();
  final Object _inside = Object();

  Future<T> run<T>(FutureOr<T> Function() op) {
    if (Zone.current[_inside] == true) return Future.sync(op);
    return _enqueue(() => Future.sync(op));
  }

  Future<T> hold<T>(Future<T> Function() body) {
    if (Zone.current[_inside] == true) throw StateError('transactions do not nest');
    return _enqueue(() => runZoned(body, zoneValues: {_inside: true}));
  }

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => op()).whenComplete(done.complete);
  }
}

Future<void> _ownerOnly(String path) async {
  if (Platform.isWindows) return;
  final r = await Process.run('chmod', ['600', path]);
  if (r.exitCode != 0) throw ProcessException('chmod', ['600', path], r.stderr.toString(), r.exitCode);
}
