/// A scripted stand-in for a Postgres server, for the client's refusals and
/// error paths that a real server will not produce on demand. Each
/// connection it accepts runs the test's script against a [FakeClient].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final class ScriptedServer {
  ScriptedServer._(this._server);

  /// Listens on a free loopback port. When [script] returns, the server
  /// closes that connection.
  static Future<ScriptedServer> start(Future<void> Function(FakeClient client) script) async {
    final server = ScriptedServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((socket) async {
      final client = FakeClient._(socket);
      server.clients.add(client);
      try {
        await script(client);
      } on Object catch (e) {
        server.errors.add(e);
      } finally {
        client._close();
      }
    });
    return server;
  }

  final ServerSocket _server;

  /// Every connection accepted, oldest first.
  final clients = <FakeClient>[];

  /// What the scripts threw; a test expecting a clean run checks it is empty.
  final errors = <Object>[];

  int get port => _server.port;

  Future<void> close() => _server.close();
}

/// The client's side of one connection, as the scripted server sees it.
final class FakeClient {
  FakeClient._(this._socket) {
    _socket.listen(
      (data) {
        _buffer.addAll(data);
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
      onError: (Object _) {
        _closed = true;
        _wake();
      },
    );
    // A write after the client dropped the connection fails, and dart:io
    // reports that through `done`. It is the client leaving, as above.
    unawaited(
      _socket.done.then<void>(
        (_) {},
        onError: (Object _) {
          _closed = true;
          _wake();
        },
      ),
    );
  }

  final Socket _socket;
  final _buffer = <int>[];
  bool _closed = false;
  Completer<void>? _arrived;

  /// The type of every typed message the client sent.
  final received = <int>[];

  /// The startup message's parameters.
  Future<Map<String, String>> startup({List<int> sslAnswer = const [0x4E]}) async {
    while (true) {
      final length = await _int32();
      final code = await _int32();
      final rest = await _take(length - 8);
      if (code == 80877103) {
        _socket.add(sslAnswer);
        continue;
      }
      if (code != 196608) throw StateError('not a startup message');
      final strings = _cstrings(rest);
      return {for (var i = 0; i + 1 < strings.length; i += 2) strings[i]: strings[i + 1]};
    }
  }

  /// The next typed message.
  Future<(int, Uint8List)> read() async {
    final type = (await _take(1)).single;
    final length = await _int32();
    final body = Uint8List.fromList(await _take(length - 4));
    received.add(type);
    return (type, body);
  }

  /// Waits until the client has closed the connection.
  Future<void> untilClosed() async {
    while (!_closed) {
      await _nextData();
      _buffer.clear();
    }
  }

  void send(int type, [List<int> body = const []]) => _socket.add([type, ..._int32Bytes(body.length + 4), ...body]);

  void sendRaw(List<int> bytes) => _socket.add(bytes);

  void authentication(int code, [List<int> extra = const []]) => send(0x52, [..._int32Bytes(code), ...extra]);

  void parameter(String name, String value) => send(0x53, [..._cstring(name), ..._cstring(value)]);

  void ready([String status = 'I']) => send(0x5A, [status.codeUnitAt(0)]);

  void error(String code, String message) => send(0x45, [
    0x53, ..._cstring('ERROR'), //
    0x43, ..._cstring(code),
    0x4D, ..._cstring(message),
    0,
  ]);

  /// AuthenticationOk, the settings a server reports, and ReadyForQuery.
  void signedIn({String encoding = 'UTF8'}) {
    authentication(0);
    parameter('client_encoding', encoding);
    parameter('application_name', '');
    send(0x4B, [..._int32Bytes(1), ..._int32Bytes(2)]);
    ready();
  }

  /// The server's side of SCRAM-SHA-256 for [password], written apart from
  /// the client's. [wrongSignature] ends with a signature no verifier makes;
  /// [skipFinal] sends AuthenticationOk in place of the final message.
  Future<void> scram(String password, {bool wrongSignature = false, bool skipFinal = false}) async {
    authentication(10, [..._cstring('SCRAM-SHA-256'), 0]);
    final (_, initial) = await read();
    final strings = _cstrings(initial);
    if (strings.first != 'SCRAM-SHA-256') throw StateError('the client chose ${strings.first}');
    final mechanismEnd = initial.indexOf(0) + 1;
    final first = utf8.decode(initial.sublist(mechanismEnd + 4));
    final firstBare = first.substring(first.indexOf(',', first.indexOf(',') + 1) + 1);
    final clientNonce = firstBare.split(',').firstWhere((a) => a.startsWith('r=')).substring(2);
    final salt = List<int>.generate(16, (i) => i * 7);
    final serverFirst = 'r=${clientNonce}scripted,s=${base64.encode(salt)},i=4096';
    authentication(11, utf8.encode(serverFirst));

    final (_, finalBody) = await read();
    final clientFinal = utf8.decode(finalBody);
    final cut = clientFinal.lastIndexOf(',p=');
    final withoutProof = clientFinal.substring(0, cut);
    final proof = base64.decode(clientFinal.substring(cut + 3));
    final salted = _pbkdf2(utf8.encode(password), salt, 4096);
    final storedKey = sha256.convert(_hmac(salted, utf8.encode('Client Key'))).bytes;
    final authMessage = utf8.encode('$firstBare,$serverFirst,$withoutProof');
    final clientSignature = _hmac(storedKey, authMessage);
    final recovered = [for (var i = 0; i < proof.length; i++) proof[i] ^ clientSignature[i]];
    if (!_same(sha256.convert(recovered).bytes, storedKey)) {
      error('28P01', 'password authentication failed for user "u"');
      return;
    }
    if (skipFinal) return;
    final signature = wrongSignature ? List<int>.filled(32, 7) : _hmac(_hmac(salted, utf8.encode('Server Key')), authMessage);
    authentication(12, utf8.encode('v=${base64.encode(signature)}'));
  }

  /// Reads one extended-query cycle, up to its Sync, and answers it:
  /// with rows, or with an error. Answers the statement's SQL.
  Future<String> query({
    List<(String, int)> columns = const [],
    List<List<String?>> rows = const [],
    String tag = 'SELECT 0',
    String? errorCode,
    String status = 'I',
    void Function()? before,
  }) async {
    String? sql;
    while (true) {
      final (type, body) = await read();
      if (type == 0x50) sql = _cstrings(body)[1];
      if (type == 0x53) break;
      if (type == 0x58) throw StateError('the client ended the session mid-statement');
    }
    before?.call();
    if (errorCode != null) {
      error(errorCode, 'a scripted failure');
    } else {
      send(0x31);
      send(0x32);
      if (columns.isEmpty) {
        send(0x6E);
      } else {
        send(0x54, [
          ..._int16Bytes(columns.length),
          for (final (name, oid) in columns) ...[
            ..._cstring(name),
            ..._int32Bytes(0),
            ..._int16Bytes(0),
            ..._int32Bytes(oid),
            ..._int16Bytes(-1),
            ..._int32Bytes(-1),
            ..._int16Bytes(0),
          ],
        ]);
      }
      for (final row in rows) {
        send(0x44, [
          ..._int16Bytes(row.length),
          for (final value in row) ...(value == null ? _int32Bytes(-1) : [..._int32Bytes(utf8.encode(value).length), ...utf8.encode(value)]),
        ]);
      }
      send(0x43, _cstring(tag));
    }
    ready(status);
    return sql ?? '';
  }

  Future<List<int>> _take(int n) async {
    while (_buffer.length < n) {
      if (_closed) throw StateError('the client closed the connection');
      await _nextData();
    }
    final out = _buffer.sublist(0, n);
    _buffer.removeRange(0, n);
    return out;
  }

  Future<int> _int32() async => ByteData.sublistView(Uint8List.fromList(await _take(4))).getInt32(0);

  Future<void> _nextData() => (_arrived = Completer<void>()).future;

  void _wake() {
    final arrived = _arrived;
    _arrived = null;
    arrived?.complete();
  }

  void _close() {
    _socket.destroy();
  }
}

List<int> _int32Bytes(int v) => (ByteData(4)..setInt32(0, v)).buffer.asUint8List();

List<int> _int16Bytes(int v) => (ByteData(2)..setInt16(0, v)).buffer.asUint8List();

List<int> _cstring(String s) => [...utf8.encode(s), 0];

List<String> _cstrings(List<int> bytes) {
  final strings = <String>[];
  var start = 0;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0) {
      strings.add(utf8.decode(bytes.sublist(start, i)));
      start = i + 1;
    }
  }
  return strings;
}

List<int> _hmac(List<int> key, List<int> message) => Hmac(sha256, key).convert(message).bytes;

List<int> _pbkdf2(List<int> password, List<int> salt, int iterations) {
  var block = _hmac(password, [...salt, 0, 0, 0, 1]);
  final out = List<int>.of(block);
  for (var i = 1; i < iterations; i++) {
    block = _hmac(password, block);
    for (var j = 0; j < out.length; j++) {
      out[j] ^= block[j];
    }
  }
  return out;
}

bool _same(List<int> a, List<int> b) => a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
