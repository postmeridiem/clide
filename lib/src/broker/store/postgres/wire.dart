/// The Postgres frontend/backend protocol, version 3: the messages the
/// broker's store sends, and a reader for what the server answers
/// (D-121). Parameters and results are in text format throughout.
library;

import 'dart:convert';
import 'dart:typed_data';

/// The server broke the protocol, or sent something the client refuses.
class PostgresProtocolException implements Exception {
  PostgresProtocolException(this.message);

  final String message;

  @override
  String toString() => 'PostgresProtocolException: $message';
}

// -- what the client sends ------------------------------------------------------

/// Asks the server whether it will speak TLS. It answers one byte.
Uint8List sslRequest() =>
    (_Writer()
          ..int32(8)
          ..int32(80877103))
        .bytes;

/// Opens a session: protocol 3.0 and the startup parameters.
Uint8List startupMessage(Map<String, String> parameters) {
  final body = _Writer()..int32(196608);
  parameters.forEach((name, value) {
    body
      ..cstring(name)
      ..cstring(value);
  });
  body.byte(0);
  final payload = body.bytes;
  return (_Writer()
        ..int32(payload.length + 4)
        ..raw(payload))
      .bytes;
}

/// A password in clear text, which the client sends only over TLS.
Uint8List passwordMessage(String password) => _message(0x70, _Writer()..cstring(password));

/// The first SASL message: the mechanism and its first response.
Uint8List saslInitialResponse(String mechanism, List<int> response) => _message(
  0x70,
  _Writer()
    ..cstring(mechanism)
    ..int32(response.length)
    ..raw(response),
);

/// A later SASL message.
Uint8List saslResponse(List<int> response) => _message(0x70, _Writer()..raw(response));

/// Parses [sql] into the unnamed statement, letting the server infer the
/// parameters' types.
Uint8List parseMessage(String sql) => _message(
  0x50,
  _Writer()
    ..cstring('')
    ..cstring(sql)
    ..int16(0),
);

/// Binds [values], in text format, to the unnamed statement as the unnamed
/// portal, asking for text-format results. A null value binds SQL NULL.
Uint8List bindMessage(List<String?> values) {
  final body = _Writer()
    ..cstring('')
    ..cstring('')
    ..int16(0)
    ..int16(values.length);
  for (final value in values) {
    if (value == null) {
      body.int32(-1);
    } else {
      final bytes = utf8.encode(value);
      body
        ..int32(bytes.length)
        ..raw(bytes);
    }
  }
  body.int16(0);
  return _message(0x42, body);
}

/// Asks for the unnamed portal's row description.
Uint8List describePortalMessage() => _message(
  0x44,
  _Writer()
    ..byte(0x50)
    ..cstring(''),
);

/// Runs the unnamed portal to completion.
Uint8List executeMessage() => _message(
  0x45,
  _Writer()
    ..cstring('')
    ..int32(0),
);

/// Ends an extended-query cycle; the server answers ReadyForQuery.
Uint8List syncMessage() => _message(0x53, _Writer());

/// Ends the session.
Uint8List terminateMessage() => _message(0x58, _Writer());

Uint8List _message(int type, _Writer body) {
  final payload = body.bytes;
  return (_Writer()
        ..byte(type)
        ..int32(payload.length + 4)
        ..raw(payload))
      .bytes;
}

// -- what the server sends ------------------------------------------------------

/// Backend message types the client acts on.
abstract final class Backend {
  static const authentication = 0x52; // R
  static const parameterStatus = 0x53; // S
  static const backendKeyData = 0x4B; // K
  static const readyForQuery = 0x5A; // Z
  static const errorResponse = 0x45; // E
  static const noticeResponse = 0x4E; // N
  static const notification = 0x41; // A
  static const parseComplete = 0x31; // 1
  static const bindComplete = 0x32; // 2
  static const noData = 0x6E; // n
  static const rowDescription = 0x54; // T
  static const dataRow = 0x44; // D
  static const commandComplete = 0x43; // C
  static const emptyQuery = 0x49; // I
  static const negotiateProtocolVersion = 0x76; // v
}

/// One message from the server: its type byte and its body.
final class BackendMessage {
  const BackendMessage(this.type, this.body);

  final int type;
  final Uint8List body;
}

/// Frames the server's byte stream into messages.
final class MessageReader {
  MessageReader({this.maxMessageBytes = 16 * 1024 * 1024});

  /// The largest message accepted. The store's rows are small; a larger
  /// claim is a broken or hostile server.
  final int maxMessageBytes;

  Uint8List _buffer = Uint8List(4096);
  int _start = 0;
  int _end = 0;

  void add(List<int> data) {
    if (_end + data.length > _buffer.length) {
      final live = _end - _start;
      final needed = live + data.length;
      final next = needed > _buffer.length ~/ 2 ? Uint8List(needed * 2) : _buffer;
      next.setRange(0, live, _buffer, _start);
      _buffer = next;
      _start = 0;
      _end = live;
    }
    _buffer.setRange(_end, _end + data.length, data);
    _end += data.length;
  }

  /// The next complete message, or null until one has arrived.
  BackendMessage? next() {
    if (_end - _start < 5) return null;
    final length = ByteData.sublistView(_buffer, _start + 1, _start + 5).getInt32(0);
    if (length < 4) throw PostgresProtocolException('a message claims a length of $length');
    if (length > maxMessageBytes) throw PostgresProtocolException('a message claims $length bytes, more than $maxMessageBytes');
    if (_end - _start < 1 + length) return null;
    final message = BackendMessage(_buffer[_start], Uint8List.fromList(_buffer.sublist(_start + 5, _start + 1 + length)));
    _start += 1 + length;
    if (_start == _end) _start = _end = 0;
    return message;
  }
}

/// One column of a result, from a RowDescription.
final class ColumnInfo {
  const ColumnInfo(this.name, this.typeOid);

  final String name;
  final int typeOid;
}

List<ColumnInfo> decodeRowDescription(Uint8List body) {
  final r = _Reader(body);
  return [
    for (var n = r.int16(); n > 0; n--)
      () {
        final name = r.cstring();
        r.skip(4 + 2); // table oid, column number
        final type = r.int32();
        r.skip(2 + 4 + 2); // type size, type modifier, format
        return ColumnInfo(name, type);
      }(),
  ];
}

/// A row's values in text format; null for SQL NULL.
List<String?> decodeDataRow(Uint8List body) {
  final r = _Reader(body);
  return [
    for (var n = r.int16(); n > 0; n--)
      () {
        final length = r.int32();
        return length < 0 ? null : utf8.decode(r.take(length));
      }(),
  ];
}

String decodeCommandComplete(Uint8List body) => _Reader(body).cstring();

/// A ParameterStatus: the setting's name and its value, which may be empty.
(String, String) decodeParameterStatus(Uint8List body) {
  final r = _Reader(body);
  return (r.cstring(), r.cstring());
}

/// How many rows a command changed, from its completion tag:
/// `INSERT 0 2`, `DELETE 3`, `UPDATE 1`; zero for a command such as
/// `CREATE TABLE` that changes none.
int rowsChanged(String tag) {
  final words = tag.split(' ');
  final count = switch (words.first) {
    'INSERT' when words.length == 3 => words[2],
    'DELETE' || 'UPDATE' || 'SELECT' || 'MERGE' || 'MOVE' || 'FETCH' || 'COPY' when words.length == 2 => words[1],
    _ => '0',
  };
  return int.tryParse(count) ?? 0;
}

/// An ErrorResponse's or NoticeResponse's fields, by their type byte.
Map<String, String> decodeFields(Uint8List body) {
  final r = _Reader(body);
  final fields = <String, String>{};
  while (true) {
    final code = r.byte();
    if (code == 0) return fields;
    fields[String.fromCharCode(code)] = r.cstring();
  }
}

/// The null-terminated strings in [body] from [offset], up to an empty one.
List<String> decodeStringList(Uint8List body, int offset) {
  final r = _Reader(body)..skip(offset);
  final strings = <String>[];
  while (true) {
    final s = r.cstring();
    if (s.isEmpty) return strings;
    strings.add(s);
  }
}

int readInt32(Uint8List body, int offset) {
  if (body.length < offset + 4) throw PostgresProtocolException('a message is shorter than its fields');
  return ByteData.sublistView(body).getInt32(offset);
}

// -- byte helpers -----------------------------------------------------------------

final class _Writer {
  final _out = BytesBuilder(copy: false);

  Uint8List get bytes => _out.toBytes();

  void byte(int b) => _out.addByte(b);

  void int16(int v) => _out.add((ByteData(2)..setInt16(0, v)).buffer.asUint8List());

  void int32(int v) => _out.add((ByteData(4)..setInt32(0, v)).buffer.asUint8List());

  void cstring(String s) {
    final bytes = utf8.encode(s);
    if (bytes.contains(0)) throw ArgumentError.value(s, 's', 'a protocol string cannot hold a NUL byte');
    _out
      ..add(bytes)
      ..addByte(0);
  }

  void raw(List<int> bytes) => _out.add(bytes);
}

final class _Reader {
  _Reader(this._body);

  final Uint8List _body;
  int _at = 0;

  void _need(int n) {
    if (_at + n > _body.length) throw PostgresProtocolException('a message is shorter than its fields');
  }

  int byte() {
    _need(1);
    return _body[_at++];
  }

  int int16() {
    _need(2);
    final v = ByteData.sublistView(_body, _at, _at + 2).getInt16(0);
    _at += 2;
    return v;
  }

  int int32() {
    _need(4);
    final v = ByteData.sublistView(_body, _at, _at + 4).getInt32(0);
    _at += 4;
    return v;
  }

  void skip(int n) {
    _need(n);
    _at += n;
  }

  Uint8List take(int n) {
    _need(n);
    final bytes = Uint8List.sublistView(_body, _at, _at + n);
    _at += n;
    return bytes;
  }

  String cstring() {
    final end = _body.indexOf(0, _at);
    if (end < 0) throw PostgresProtocolException('a string in a message is not terminated');
    final s = utf8.decode(Uint8List.sublistView(_body, _at, end));
    _at = end + 1;
    return s;
  }
}
