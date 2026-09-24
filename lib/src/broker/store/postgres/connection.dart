/// clide's Postgres client (D-121): the part of the protocol the broker's
/// store uses, and nothing more. It speaks the extended query protocol with
/// the unnamed statement and portal, text values both ways, SCRAM-SHA-256
/// to sign in, and TLS verified by default.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../environment.dart';
import '../location.dart';
import '../sql.dart';
import 'scram.dart';
import 'wire.dart';

/// The server reported an error for a statement. The connection stays
/// usable.
class PostgresException implements Exception {
  PostgresException(this.message, {this.code, this.detail});

  final String message;

  /// The SQLSTATE, such as `23505` for a unique violation.
  final String? code;
  final String? detail;

  @override
  String toString() => 'PostgresException${code == null ? '' : '($code)'}: $message${detail == null ? '' : ' ($detail)'}';
}

/// The connection could not be made, or was lost.
class PostgresConnectionException implements Exception {
  PostgresConnectionException(this.message);

  final String message;

  @override
  String toString() => 'PostgresConnectionException: $message';
}

/// A connection to the Postgres database that holds the broker's store.
/// Statements run one at a time; a lost connection is opened again before
/// the next statement, unless a transaction was open on it.
final class PostgresConnection implements SqlConnection {
  PostgresConnection._(this._location, this._password, this._startup, this._timeout);

  /// Connects to [location] and signs in with [password], which comes from
  /// the environment (D-121). [startupParameters] become run-time settings
  /// for the session; the tests give each test its own `search_path`.
  static Future<PostgresConnection> open(
    PostgresLocation location, {
    String? password,
    Map<String, String> startupParameters = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (password != null && password.codeUnits.any((c) => c < 0x20 || c > 0x7e)) {
      throw BrokerConfigException(
        '${StoreLocation.passwordVariable} must be printable ASCII: this client does not normalize a password the way the server does (SASLprep).',
      );
    }
    final connection = PostgresConnection._(location, password, startupParameters, timeout);
    connection._session = await connection._connect();
    return connection;
  }

  final PostgresLocation _location;
  final String? _password;
  final Map<String, String> _startup;
  final Duration _timeout;

  /// Orders calls, and holds them back while a transaction runs.
  final CallQueue _calls = CallQueue();

  /// Keeps one exchange on the wire at a time, even among a transaction's
  /// own statements.
  final CallQueue _wire = CallQueue();

  _Session? _session;
  bool _transactionOpen = false;
  bool _closed = false;

  /// Serializes a migration across brokers; released when its transaction
  /// ends. The value spells "clide-mg".
  static const _migrationLock = 0x636C6964652D6D67;

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) => _calls.run(() async => rowsChanged((await _exchange(sql, params)).tag));

  @override
  Future<List<Map<String, Object?>>> select(String sql, [List<Object?> params = const []]) => _calls.run(() async {
    final result = await _exchange(sql, params);
    return [
      for (final row in result.rows) {for (var i = 0; i < result.columns.length; i++) result.columns[i].name: _value(result.columns[i], row[i])},
    ];
  });

  @override
  Future<T> transaction<T>(Future<T> Function() body, {bool exclusive = false}) => _calls.hold(() async {
    await _exchange('BEGIN', const []);
    _transactionOpen = true;
    try {
      if (exclusive) await _exchange(r'SELECT pg_advisory_xact_lock($1)', const [_migrationLock]);
      final result = await body();
      // A transaction that failed inside answers COMMIT with ROLLBACK.
      final tag = (await _exchange('COMMIT', const [])).tag;
      _transactionOpen = false;
      if (tag != 'COMMIT') throw PostgresException('the transaction failed and was rolled back');
      return result;
    } catch (_) {
      await _rollbackQuietly();
      rethrow;
    } finally {
      _transactionOpen = false;
    }
  });

  @override
  Future<void> close() => _calls.run(() async {
    _closed = true;
    await _wire.run(() async {
      final session = _session;
      _session = null;
      await session?.close();
    });
  });

  Future<void> _rollbackQuietly() async {
    if (_session?.inTransaction != true) return;
    try {
      await _exchange('ROLLBACK', const []);
    } catch (_) {
      await _drop();
    }
  }

  /// One statement: Parse, Bind, Describe, Execute and Sync, then every
  /// message up to ReadyForQuery. A server error leaves the session in step
  /// and usable; anything else ends the session.
  Future<_Result> _exchange(String sql, List<Object?> params) => _wire.run(() async {
    final session = await _liveSession();
    final messages = [
      parseMessage(sql),
      bindMessage([for (final p in params) _text(p)]),
      describePortalMessage(),
      executeMessage(),
      syncMessage(),
    ];
    try {
      session.send(messages);
      return await session.collect(_timeout);
    } on PostgresException {
      rethrow;
    } catch (e) {
      await _drop();
      throw PostgresConnectionException('the connection to the store was lost: ${_describe(e)}');
    }
  });

  Future<_Session> _liveSession() async {
    if (_closed) throw StateError('the connection to the store is closed');
    final session = _session;
    if (session != null && !session.broken) return session;
    if (_transactionOpen) throw PostgresConnectionException('the connection to the store was lost during a transaction');
    await _drop();
    return _session = await _connect();
  }

  Future<void> _drop() async {
    final session = _session;
    _session = null;
    await session?.close();
  }

  Future<_Session> _connect() async {
    Socket socket;
    try {
      socket = await Socket.connect(_location.host, _location.port, timeout: _timeout);
    } on SocketException catch (e) {
      throw PostgresConnectionException('the server at ${_location.host}:${_location.port} cannot be reached: ${_describe(e)}');
    }
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      if (_location.sslMode != SslMode.disable) socket = await _secure(socket);
      final session = _Session(socket);
      session.send([
        startupMessage({'user': _location.user, 'database': _location.database, 'application_name': 'clide-broker', 'client_encoding': 'UTF8', ..._startup}),
      ]);
      await _signIn(session);
      return session;
    } catch (e) {
      socket.destroy();
      if (e is BrokerConfigException || e is PostgresException || e is PostgresProtocolException || e is PostgresConnectionException) rethrow;
      final what = e is TimeoutException ? 'did not answer in time' : 'dropped the connection: ${_describe(e)}';
      throw PostgresConnectionException('the server at ${_location.host}:${_location.port} $what');
    }
  }

  /// Asks for TLS and completes the handshake on the same socket.
  Future<Socket> _secure(Socket socket) async {
    final answered = Completer<Uint8List>();
    late final StreamSubscription<Uint8List> subscription;
    subscription = socket.listen(
      (data) {
        subscription.pause();
        if (!answered.isCompleted) answered.complete(data);
      },
      onError: (Object e) {
        if (!answered.isCompleted) answered.completeError(e);
      },
      onDone: () {
        if (!answered.isCompleted) answered.completeError(const SocketException('the server closed the connection'));
      },
    );
    socket.add(sslRequest());
    final answer = await answered.future.timeout(_timeout);
    // Bytes after the one-byte answer arrived before TLS, so they are
    // refused rather than read as if TLS had protected them.
    if (answer.length != 1) throw PostgresProtocolException('the server sent more than its one-byte answer to the TLS request');
    if (answer[0] == 0x4E) {
      throw BrokerConfigException(
        "The store's Postgres server does not offer TLS. If it runs on a private network, add ?sslmode=disable to ${StoreLocation.variable}.",
      );
    }
    if (answer[0] != 0x53) throw PostgresProtocolException('the server answered the TLS request with neither S nor N');

    final verify = _location.sslMode == SslMode.verifyFull;
    final SecurityContext context;
    final rootCert = _location.sslRootCert;
    if (rootCert == null) {
      context = SecurityContext.defaultContext;
    } else {
      try {
        context = SecurityContext(withTrustedRoots: false)..setTrustedCertificates(rootCert);
      } on Object catch (e) {
        throw BrokerConfigException('The sslrootcert in ${StoreLocation.variable} cannot be read as PEM certificates: ${_describe(e)}');
      }
    }
    try {
      return await SecureSocket.secure(socket, host: _location.host, context: context, onBadCertificate: verify ? null : (_) => true).timeout(_timeout);
    } on HandshakeException catch (e) {
      final checked = verify ? ' The certificate is checked against the trusted roots and the host name (sslmode=verify-full).' : '';
      throw PostgresConnectionException('TLS with the server at ${_location.host} failed: ${_describe(e)}.$checked');
    }
  }

  /// Answers the server's authentication requests until it is ready.
  Future<void> _signIn(_Session session) async {
    final verifiedTls = _location.sslMode == SslMode.verifyFull;
    ScramClient? scram;
    var scramDone = false;
    while (true) {
      final message = await session.next(_timeout);
      switch (message.type) {
        case Backend.authentication:
          final code = readInt32(message.body, 0);
          switch (code) {
            case 0: // AuthenticationOk
              if (scram != null && !scramDone) throw PostgresProtocolException('the server ended SCRAM before proving itself');
              if (_password != null && scram == null && !verifiedTls) {
                throw BrokerConfigException(
                  "The store's Postgres server let the broker in without proving who it is. With a password set, the server must use scram-sha-256, or the connection must use sslmode=verify-full.",
                );
              }
            case 3: // AuthenticationCleartextPassword
              if (!verifiedTls) {
                throw BrokerConfigException(
                  "The store's Postgres server asked for the password in clear text, which the broker sends only over sslmode=verify-full. Use scram-sha-256 on the server.",
                );
              }
              session.send([passwordMessage(_requirePassword())]);
            case 5: // AuthenticationMD5Password
              throw BrokerConfigException(
                "The store's Postgres server asked for an MD5 password hash, which the broker refuses. Store the role's password as SCRAM-SHA-256.",
              );
            case 10: // AuthenticationSASL
              if (!decodeStringList(message.body, 4).contains(ScramClient.mechanism)) {
                throw BrokerConfigException("The store's Postgres server offers no SCRAM-SHA-256 sign-in.");
              }
              final client = scram = ScramClient(_requirePassword());
              session.send([saslInitialResponse(ScramClient.mechanism, utf8.encode(client.clientFirstMessage))]);
            case 11: // AuthenticationSASLContinue
              final client = scram ?? (throw PostgresProtocolException('the server continued a SCRAM exchange that had not started'));
              session.send([saslResponse(utf8.encode(_scram(() => client.clientFinalMessage(utf8.decode(message.body.sublist(4))))))]);
            case 12: // AuthenticationSASLFinal
              final client = scram ?? (throw PostgresProtocolException('the server finished a SCRAM exchange that had not started'));
              _scram(() => client.verifyServerFinal(utf8.decode(message.body.sublist(4))));
              scramDone = true;
            default:
              throw BrokerConfigException(
                "The store's Postgres server asked for a sign-in method the broker does not support (code $code). Use scram-sha-256.",
              );
          }
        case Backend.errorResponse:
          throw _signInError(decodeFields(message.body));
        case Backend.parameterStatus:
          final (name, value) = decodeParameterStatus(message.body);
          session.parameters[name] = value;
        case Backend.backendKeyData || Backend.noticeResponse:
          break;
        case Backend.readyForQuery:
          session.status = message.body.isEmpty ? 0x49 : message.body[0];
          final encoding = session.parameters['client_encoding'];
          if (encoding != null && encoding != 'UTF8') throw PostgresProtocolException('the server did not accept UTF8 as the client encoding');
          return;
        case Backend.negotiateProtocolVersion:
          throw PostgresProtocolException('the server does not speak protocol 3.0 as the broker asked');
        default:
          throw PostgresProtocolException('an unexpected message during sign-in, type ${String.fromCharCode(message.type)}');
      }
    }
  }

  String _requirePassword() =>
      _password ??
      (throw BrokerConfigException("The store's Postgres server asks for a password. Set ${StoreLocation.passwordVariable} where the container runs."));

  static T _scram<T>(T Function() step) {
    try {
      return step();
    } on ScramException catch (e) {
      throw PostgresConnectionException('SCRAM sign-in failed: ${e.message}');
    }
  }

  static Exception _signInError(Map<String, String> fields) {
    final code = fields['C'];
    final message = fields['M'] ?? 'no message';
    return switch (code) {
      '28P01' => BrokerConfigException("The store's Postgres server refused the user or the password (28P01)."),
      '28000' || '3D000' || '42501' => BrokerConfigException("The store's Postgres server refused the connection ($code): $message"),
      _ => PostgresException(message, code: code, detail: fields['D']),
    };
  }
}

/// One live connection: its socket, and the messages read from it.
final class _Session {
  _Session(this._socket) {
    _subscription = _socket.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _subscription;
  final _reader = MessageReader();
  final parameters = <String, String>{};
  Completer<void>? _arrived;
  Object? _failure;

  /// The last ReadyForQuery's status: `I` idle, `T` in a transaction, `E` in
  /// a failed one.
  int status = 0x49;

  bool get broken => _failure != null;
  bool get inTransaction => status != 0x49;

  void send(List<Uint8List> messages) {
    for (final m in messages) {
      _socket.add(m);
    }
  }

  Future<BackendMessage> next(Duration timeout) async {
    while (true) {
      final BackendMessage? message;
      try {
        message = _reader.next();
      } on PostgresProtocolException catch (e) {
        _failure ??= e;
        rethrow;
      }
      if (message != null) return message;
      final failure = _failure;
      if (failure != null) throw failure;
      final arrived = _arrived = Completer<void>();
      try {
        await arrived.future.timeout(timeout);
      } on TimeoutException {
        _failure ??= TimeoutException('the store did not answer in time', timeout);
        rethrow;
      }
    }
  }

  /// Reads one statement's answer, up to and including ReadyForQuery.
  Future<_Result> collect(Duration timeout) async {
    var columns = const <ColumnInfo>[];
    final rows = <List<String?>>[];
    var tag = '';
    PostgresException? error;
    while (true) {
      final message = await next(timeout);
      switch (message.type) {
        case Backend.parseComplete || Backend.bindComplete || Backend.noData || Backend.emptyQuery:
          break;
        case Backend.rowDescription:
          columns = decodeRowDescription(message.body);
        case Backend.dataRow:
          rows.add(decodeDataRow(message.body));
        case Backend.commandComplete:
          tag = decodeCommandComplete(message.body);
        case Backend.errorResponse:
          final fields = decodeFields(message.body);
          error ??= PostgresException(fields['M'] ?? 'no message', code: fields['C'], detail: fields['D']);
        case Backend.readyForQuery:
          status = message.body.isEmpty ? 0x49 : message.body[0];
          if (error != null) throw error;
          return _Result(columns, rows, tag);
        case Backend.parameterStatus:
          final (name, value) = decodeParameterStatus(message.body);
          parameters[name] = value;
        case Backend.noticeResponse || Backend.notification:
          break;
        default:
          final unexpected = PostgresProtocolException('an unexpected message, type ${String.fromCharCode(message.type)}');
          _failure ??= unexpected;
          throw unexpected;
      }
    }
  }

  Future<void> close() async {
    _failure ??= StateError('closed');
    try {
      _socket.add(terminateMessage());
      await _socket.flush().timeout(const Duration(seconds: 2));
    } catch (_) {
      // The server may already be gone; the socket is destroyed either way.
    }
    _socket.destroy();
    await _subscription.cancel();
  }

  void _onData(Uint8List data) {
    _reader.add(data);
    _wake();
  }

  void _onError(Object error) {
    _failure ??= error;
    _wake();
  }

  void _onDone() {
    _failure ??= const SocketException('the server closed the connection');
    _wake();
  }

  void _wake() {
    final arrived = _arrived;
    _arrived = null;
    arrived?.complete();
  }
}

final class _Result {
  const _Result(this.columns, this.rows, this.tag);

  final List<ColumnInfo> columns;
  final List<List<String?>> rows;
  final String tag;
}

String? _text(Object? value) => switch (value) {
  null => null,
  final bool b => b ? '1' : '0',
  final int n => '$n',
  final String s => s,
  final other => throw ArgumentError.value(other, 'params', 'only null, bool, int and String bind'),
};

/// A text-format value as the store reads it: integers as `int`, text as
/// `String`. The store reads no other type.
Object? _value(ColumnInfo column, String? text) {
  if (text == null) return null;
  return switch (column.typeOid) {
    20 || 21 || 23 => int.parse(text), // int8, int2, int4
    25 || 1043 || 19 || 1042 => text, // text, varchar, name, bpchar
    2278 => null, // void
    _ => throw PostgresException('column ${column.name} has type ${column.typeOid}, which the store never reads'),
  };
}

String _describe(Object e) => switch (e) {
  SocketException(:final osError?, :final message) => osError.message.isNotEmpty ? osError.message : message,
  TlsException(:final osError?, :final message) => osError.message.isNotEmpty ? osError.message : message,
  SocketException(:final message) || TlsException(:final message) => message,
  PostgresProtocolException(:final message) || PostgresConnectionException(:final message) => message,
  TimeoutException() => 'no answer in time',
  _ => '$e',
};
