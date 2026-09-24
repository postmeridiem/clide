import 'dart:convert';
import 'dart:typed_data';

import 'package:clide/src/broker/store/postgres/wire.dart';
import 'package:test/test.dart';

List<int> int32(int v) => (ByteData(4)..setInt32(0, v)).buffer.asUint8List();

List<int> message(int type, List<int> body) => [type, ...int32(body.length + 4), ...body];

void main() {
  group('what the client sends', () {
    test('the TLS request and the startup message', () {
      expect(sslRequest(), [...int32(8), ...int32(80877103)]);
      final body = [...int32(196608), ...utf8.encode('user'), 0, ...utf8.encode('u'), 0, 0];
      expect(startupMessage({'user': 'u'}), [...int32(body.length + 4), ...body]);
    });

    test('Parse, Bind with NULL and UTF-8 values, Describe, Execute, Sync and Terminate', () {
      expect(parseMessage('SELECT 1'), message(0x50, [0, ...utf8.encode('SELECT 1'), 0, 0, 0]));
      final value = utf8.encode('ü');
      expect(bindMessage([null, 'ü']), message(0x42, [0, 0, 0, 0, 0, 2, ...int32(-1), ...int32(value.length), ...value, 0, 0]));
      expect(describePortalMessage(), message(0x44, [0x50, 0]));
      expect(executeMessage(), message(0x45, [0, ...int32(0)]));
      expect(syncMessage(), message(0x53, []));
      expect(terminateMessage(), message(0x58, []));
    });

    test('SASL and password messages', () {
      expect(saslInitialResponse('M', [1, 2]), message(0x70, [0x4D, 0, ...int32(2), 1, 2]));
      expect(saslResponse([3]), message(0x70, [3]));
      expect(passwordMessage('pw'), message(0x70, [...utf8.encode('pw'), 0]));
    });

    test('refuses a protocol string with a NUL byte', () {
      expect(() => parseMessage('SELECT 1\u0000; DROP TABLE t'), throwsArgumentError);
    });
  });

  group('the reader', () {
    test('frames messages split across chunks and several in one chunk', () {
      final reader = MessageReader();
      final both = [
        ...message(0x5A, [0x49]),
        ...message(0x43, utf8.encode('SELECT 1\u0000')),
      ];
      reader.add(both.sublist(0, 3));
      expect(reader.next(), isNull);
      reader.add(both.sublist(3));
      final first = reader.next()!;
      expect(
        [first.type, first.body],
        [
          0x5A,
          [0x49],
        ],
      );
      expect(decodeCommandComplete(reader.next()!.body), 'SELECT 1');
      expect(reader.next(), isNull);
    });

    test('keeps what is left over when it grows its buffer', () {
      final reader = MessageReader();
      final big = List<int>.generate(10000, (i) => i % 251);
      reader
        ..add(message(0x44, [1]).sublist(0, 2))
        ..add([
          ...message(0x44, [1]).sublist(2),
          ...message(0x44, big),
        ]);
      expect(reader.next()!.body, [1]);
      expect(reader.next()!.body, big);
    });

    test('refuses a length below four and one past the limit', () {
      expect(() => (MessageReader()..add([0x44, ...int32(3)])).next(), throwsA(isA<PostgresProtocolException>()));
      expect(
        () => (MessageReader(maxMessageBytes: 100)..add([0x44, ...int32(101)])).next(),
        throwsA(isA<PostgresProtocolException>().having((e) => e.message, 'message', contains('more than 100'))),
      );
    });
  });

  group('what the server sends', () {
    test('rows, errors, parameter status and string lists', () {
      final row = decodeDataRow(Uint8List.fromList([0, 2, ...int32(-1), ...int32(1), 0x41]));
      expect(row, [null, 'A']);
      expect(decodeFields(Uint8List.fromList([0x43, ...utf8.encode('42601'), 0, 0x4D, ...utf8.encode('bad'), 0, 0])), {'C': '42601', 'M': 'bad'});
      expect(decodeParameterStatus(Uint8List.fromList([...utf8.encode('application_name'), 0, 0])), ('application_name', ''));
      expect(decodeStringList(Uint8List.fromList([0, 0, 0, 10, ...utf8.encode('A'), 0, ...utf8.encode('B'), 0, 0]), 4), ['A', 'B']);
    });

    test('refuses a message shorter than its fields', () {
      expect(() => decodeDataRow(Uint8List.fromList([0, 1, 0, 0])), throwsA(isA<PostgresProtocolException>()));
      expect(() => decodeCommandComplete(Uint8List.fromList(utf8.encode('no terminator'))), throwsA(isA<PostgresProtocolException>()));
      expect(() => readInt32(Uint8List(2), 0), throwsA(isA<PostgresProtocolException>()));
    });

    test('counts changed rows from a completion tag', () {
      expect(
        [
          for (final tag in ['INSERT 0 3', 'DELETE 2', 'UPDATE 0', 'SELECT 5', 'CREATE TABLE', 'BEGIN', 'INSERT 0']) rowsChanged(tag),
        ],
        [3, 2, 0, 5, 0, 0, 0],
      );
    });
  });
}
