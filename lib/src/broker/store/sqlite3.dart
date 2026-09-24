/// A minimal binding to the system SQLite library through `dart:ffi`: open a
/// database file, run one statement at a time with bound parameters, read the
/// rows back. It covers what the broker's store needs and nothing more
/// (D-121), so clide adds no package for it.
///
/// Parameters are written `?1`, `?2`… and bind from a list: `null`, `bool`,
/// `int` or `String`. Rows come back as maps from column name to `int`,
/// `String` or `null`; the store never writes any other type.
library;

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

/// SQLite reported an error, or the binding refused a call.
class SqliteException implements Exception {
  SqliteException(this.message, {this.code, this.sql});

  final String message;

  /// SQLite's extended result code, when SQLite produced the error.
  final int? code;

  /// The statement that failed, when there was one.
  final String? sql;

  @override
  String toString() => 'SqliteException${code == null ? '' : '($code)'}: $message${sql == null ? '' : '\n  in: $sql'}';
}

/// An open SQLite database. Use it from one isolate only.
final class SqliteDatabase {
  SqliteDatabase._(this._db, this.path);

  /// Opens [path], creating the file if it does not exist.
  factory SqliteDatabase.open(String path, {Duration busyTimeout = const Duration(seconds: 5)}) {
    final out = calloc<ffi.Pointer<_Db>>();
    final name = path.toNativeUtf8(allocator: calloc);
    try {
      final rc = _api.open(name, out, _openReadWrite | _openCreate, ffi.nullptr);
      final db = out.value;
      if (rc != _ok) {
        final reason = db == ffi.nullptr ? _api.errstr(rc).toDartString() : _api.errmsg(db).toDartString();
        if (db != ffi.nullptr) _api.close(db);
        throw SqliteException('cannot open $path: $reason', code: rc);
      }
      _api.extendedResultCodes(db, 1);
      _api.busyTimeout(db, busyTimeout.inMilliseconds);
      return SqliteDatabase._(db, path);
    } finally {
      calloc.free(name);
      calloc.free(out);
    }
  }

  /// The version of the SQLite library in use, such as `3.40.1`.
  static String get libraryVersion => _api.libversion().toDartString();

  final String path;
  final ffi.Pointer<_Db> _db;
  bool _closed = false;

  /// Whether a transaction is open.
  bool get inTransaction {
    _checkOpen();
    return _api.getAutocommit(_db) == 0;
  }

  /// Runs a query and answers its rows.
  List<Map<String, Object?>> select(String sql, [List<Object?> params = const []]) => _withStatement(sql, params, (stmt) {
    final columns = _api.columnCount(stmt);
    final names = [for (var i = 0; i < columns; i++) _api.columnName(stmt, i).toDartString()];
    final rows = <Map<String, Object?>>[];
    while (true) {
      final rc = _api.step(stmt);
      if (rc == _done) return rows;
      if (rc != _row) _fail(rc, sql);
      rows.add({for (var i = 0; i < columns; i++) names[i]: _column(stmt, i, sql)});
    }
  });

  /// Runs a statement to completion and answers how many rows it changed.
  /// Rows a statement returns, such as a pragma's, are discarded.
  int execute(String sql, [List<Object?> params = const []]) => _withStatement(sql, params, (stmt) {
    while (true) {
      final rc = _api.step(stmt);
      if (rc == _done) return _api.changes(_db);
      if (rc != _row) _fail(rc, sql);
    }
  });

  /// Closes the database. Later calls throw.
  void close() {
    if (_closed) return;
    _closed = true;
    _api.close(_db);
  }

  T _withStatement<T>(String sql, List<Object?> params, T Function(ffi.Pointer<_Stmt> stmt) body) {
    _checkOpen();
    final text = sql.toNativeUtf8(allocator: calloc);
    final out = calloc<ffi.Pointer<_Stmt>>();
    final tail = calloc<ffi.Pointer<Utf8>>();
    try {
      final rc = _api.prepare(_db, text, -1, out, tail);
      if (rc != _ok) _fail(rc, sql);
      final stmt = out.value;
      try {
        if (stmt == ffi.nullptr) throw SqliteException('no statement to run', sql: sql);
        // prepare compiles the first statement and silently drops the rest.
        if (tail.value != ffi.nullptr && tail.value.toDartString().trim().isNotEmpty) {
          throw SqliteException('one statement at a time', sql: sql);
        }
        _bindAll(stmt, params, sql);
        return body(stmt);
      } finally {
        if (stmt != ffi.nullptr) _api.finalize(stmt);
      }
    } finally {
      calloc.free(text);
      calloc.free(out);
      calloc.free(tail);
    }
  }

  void _bindAll(ffi.Pointer<_Stmt> stmt, List<Object?> params, String sql) {
    final expected = _api.bindParameterCount(stmt);
    if (expected != params.length) {
      throw SqliteException('the statement takes $expected parameters, not ${params.length}', sql: sql);
    }
    for (var i = 0; i < params.length; i++) {
      final index = i + 1;
      final rc = switch (params[i]) {
        null => _api.bindNull(stmt, index),
        final bool b => _api.bindInt64(stmt, index, b ? 1 : 0),
        final int n => _api.bindInt64(stmt, index, n),
        final String s => _bindText(stmt, index, s),
        final other => throw ArgumentError.value(other, 'params[$i]', 'only null, bool, int and String bind'),
      };
      if (rc != _ok) _fail(rc, sql);
    }
  }

  int _bindText(ffi.Pointer<_Stmt> stmt, int index, String value) {
    final bytes = utf8.encode(value);
    // Never a null pointer: SQLite binds a null pointer as NULL, not as ''.
    final buffer = calloc<ffi.Uint8>(bytes.isEmpty ? 1 : bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      return _api.bindText(stmt, index, buffer, bytes.length, _transient);
    } finally {
      calloc.free(buffer);
    }
  }

  Object? _column(ffi.Pointer<_Stmt> stmt, int i, String sql) {
    switch (_api.columnType(stmt, i)) {
      case _typeNull:
        return null;
      case _typeInteger:
        return _api.columnInt64(stmt, i);
      case _typeText:
        // Text first, then its length: the order SQLite documents.
        final text = _api.columnText(stmt, i);
        return utf8.decode(text.asTypedList(_api.columnBytes(stmt, i)));
      default:
        throw SqliteException('column ${_api.columnName(stmt, i).toDartString()} holds a type the store never writes', sql: sql);
    }
  }

  Never _fail(int rc, String sql) => throw SqliteException(_api.errmsg(_db).toDartString(), code: rc, sql: sql);

  void _checkOpen() {
    if (_closed) throw StateError('the database at $path is closed');
  }
}

// -- the C API -----------------------------------------------------------

final class _Db extends ffi.Opaque {}

final class _Stmt extends ffi.Opaque {}

const _ok = 0;
const _row = 100;
const _done = 101;

const _typeInteger = 1;
const _typeText = 3;
const _typeNull = 5;

const _openReadWrite = 0x00000002;
const _openCreate = 0x00000004;

/// `SQLITE_TRANSIENT`: SQLite copies a bound value before the call returns,
/// so the buffer can be freed straight after.
const _transient = -1;

final _Api _api = _Api(_openLibrary());

ffi.DynamicLibrary _openLibrary() {
  final names = Platform.isMacOS
      ? const ['/usr/lib/libsqlite3.dylib', 'libsqlite3.dylib']
      : Platform.isWindows
      ? const ['winsqlite3.dll', 'sqlite3.dll']
      : const ['libsqlite3.so.0', 'libsqlite3.so'];
  for (final name in names) {
    try {
      return ffi.DynamicLibrary.open(name);
    } on ArgumentError {
      continue;
    }
  }
  throw SqliteException('the SQLite library is not installed; tried ${names.join(', ')}');
}

final class _Api {
  _Api(ffi.DynamicLibrary l)
    : open = l
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Pointer<_Db>>, ffi.Int32, ffi.Pointer<Utf8>),
            int Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Pointer<_Db>>, int, ffi.Pointer<Utf8>)
          >('sqlite3_open_v2'),
      close = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Db>), int Function(ffi.Pointer<_Db>)>('sqlite3_close_v2'),
      errmsg = l.lookupFunction<ffi.Pointer<Utf8> Function(ffi.Pointer<_Db>), ffi.Pointer<Utf8> Function(ffi.Pointer<_Db>)>('sqlite3_errmsg'),
      errstr = l.lookupFunction<ffi.Pointer<Utf8> Function(ffi.Int32), ffi.Pointer<Utf8> Function(int)>('sqlite3_errstr'),
      extendedResultCodes = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Db>, ffi.Int32), int Function(ffi.Pointer<_Db>, int)>(
        'sqlite3_extended_result_codes',
      ),
      busyTimeout = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Db>, ffi.Int32), int Function(ffi.Pointer<_Db>, int)>('sqlite3_busy_timeout'),
      getAutocommit = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Db>), int Function(ffi.Pointer<_Db>)>('sqlite3_get_autocommit'),
      changes = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Db>), int Function(ffi.Pointer<_Db>)>('sqlite3_changes'),
      prepare = l
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<_Db>, ffi.Pointer<Utf8>, ffi.Int32, ffi.Pointer<ffi.Pointer<_Stmt>>, ffi.Pointer<ffi.Pointer<Utf8>>),
            int Function(ffi.Pointer<_Db>, ffi.Pointer<Utf8>, int, ffi.Pointer<ffi.Pointer<_Stmt>>, ffi.Pointer<ffi.Pointer<Utf8>>)
          >('sqlite3_prepare_v2'),
      finalize = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>), int Function(ffi.Pointer<_Stmt>)>('sqlite3_finalize'),
      bindParameterCount = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>), int Function(ffi.Pointer<_Stmt>)>('sqlite3_bind_parameter_count'),
      bindNull = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>, ffi.Int32), int Function(ffi.Pointer<_Stmt>, int)>('sqlite3_bind_null'),
      bindInt64 = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>, ffi.Int32, ffi.Int64), int Function(ffi.Pointer<_Stmt>, int, int)>(
        'sqlite3_bind_int64',
      ),
      bindText = l
          .lookupFunction<
            ffi.Int32 Function(ffi.Pointer<_Stmt>, ffi.Int32, ffi.Pointer<ffi.Uint8>, ffi.Int32, ffi.IntPtr),
            int Function(ffi.Pointer<_Stmt>, int, ffi.Pointer<ffi.Uint8>, int, int)
          >('sqlite3_bind_text'),
      step = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>), int Function(ffi.Pointer<_Stmt>)>('sqlite3_step'),
      columnCount = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>), int Function(ffi.Pointer<_Stmt>)>('sqlite3_column_count'),
      columnName = l.lookupFunction<ffi.Pointer<Utf8> Function(ffi.Pointer<_Stmt>, ffi.Int32), ffi.Pointer<Utf8> Function(ffi.Pointer<_Stmt>, int)>(
        'sqlite3_column_name',
      ),
      columnType = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>, ffi.Int32), int Function(ffi.Pointer<_Stmt>, int)>('sqlite3_column_type'),
      columnInt64 = l.lookupFunction<ffi.Int64 Function(ffi.Pointer<_Stmt>, ffi.Int32), int Function(ffi.Pointer<_Stmt>, int)>('sqlite3_column_int64'),
      columnText = l.lookupFunction<ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<_Stmt>, ffi.Int32), ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<_Stmt>, int)>(
        'sqlite3_column_text',
      ),
      columnBytes = l.lookupFunction<ffi.Int32 Function(ffi.Pointer<_Stmt>, ffi.Int32), int Function(ffi.Pointer<_Stmt>, int)>('sqlite3_column_bytes'),
      libversion = l.lookupFunction<ffi.Pointer<Utf8> Function(), ffi.Pointer<Utf8> Function()>('sqlite3_libversion');

  final int Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Pointer<_Db>>, int, ffi.Pointer<Utf8>) open;
  final int Function(ffi.Pointer<_Db>) close;
  final ffi.Pointer<Utf8> Function(ffi.Pointer<_Db>) errmsg;
  final ffi.Pointer<Utf8> Function(int) errstr;
  final int Function(ffi.Pointer<_Db>, int) extendedResultCodes;
  final int Function(ffi.Pointer<_Db>, int) busyTimeout;
  final int Function(ffi.Pointer<_Db>) getAutocommit;
  final int Function(ffi.Pointer<_Db>) changes;
  final int Function(ffi.Pointer<_Db>, ffi.Pointer<Utf8>, int, ffi.Pointer<ffi.Pointer<_Stmt>>, ffi.Pointer<ffi.Pointer<Utf8>>) prepare;
  final int Function(ffi.Pointer<_Stmt>) finalize;
  final int Function(ffi.Pointer<_Stmt>) bindParameterCount;
  final int Function(ffi.Pointer<_Stmt>, int) bindNull;
  final int Function(ffi.Pointer<_Stmt>, int, int) bindInt64;
  final int Function(ffi.Pointer<_Stmt>, int, ffi.Pointer<ffi.Uint8>, int, int) bindText;
  final int Function(ffi.Pointer<_Stmt>) step;
  final int Function(ffi.Pointer<_Stmt>) columnCount;
  final ffi.Pointer<Utf8> Function(ffi.Pointer<_Stmt>, int) columnName;
  final int Function(ffi.Pointer<_Stmt>, int) columnType;
  final int Function(ffi.Pointer<_Stmt>, int) columnInt64;
  final ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<_Stmt>, int) columnText;
  final int Function(ffi.Pointer<_Stmt>, int) columnBytes;
  final ffi.Pointer<Utf8> Function() libversion;
}
