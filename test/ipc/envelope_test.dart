import 'package:clide/clide.dart';
import 'package:test/test.dart';

void main() {
  group('IpcRequest', () {
    test('encodes and decodes round-trip', () {
      final req = IpcRequest(
        id: '42',
        cmd: 'git.status',
        args: const {'path': '.'},
      );
      final line = req.encode();
      final decoded = IpcMessage.decode(line);
      expect(decoded, isA<IpcRequest>());
      final r = decoded as IpcRequest;
      expect(r.id, '42');
      expect(r.cmd, 'git.status');
      expect(r.args, {'path': '.'});
    });

    test('schema version is stamped', () {
      final encoded = IpcRequest(id: '1', cmd: 'ping').toJson();
      expect(encoded['v'], ipcSchemaVersion);
      expect(encoded['type'], 'request');
    });
  });

  group('IpcResponse.ok', () {
    test('encodes with data, no error', () {
      final r = IpcResponse.ok(id: '7', data: const {'pong': true});
      final json = r.toJson();
      expect(json['type'], 'response');
      expect(json['ok'], true);
      expect(json['data'], {'pong': true});
      expect(json.containsKey('error'), isFalse);
    });

    test('decode round-trips', () {
      final original = IpcResponse.ok(id: '7', data: const {'n': 42});
      final roundtripped = IpcMessage.decode(original.encode()) as IpcResponse;
      expect(roundtripped.ok, true);
      expect(roundtripped.id, '7');
      expect(roundtripped.data, {'n': 42});
      expect(roundtripped.error, isNull);
    });
  });

  group('IpcResponse.err', () {
    test('encodes with error payload, no data', () {
      final r = IpcResponse.err(
        id: '9',
        error: IpcError(
          code: IpcExitCode.notFound,
          kind: IpcErrorKind.notFound,
          message: 'missing',
          hint: 'try --help',
        ),
      );
      final json = r.toJson();
      expect(json['ok'], false);
      expect(json['error'], {
        'code': 3,
        'kind': 'not_found',
        'message': 'missing',
        'hint': 'try --help',
      });
      expect(json.containsKey('data'), isFalse);
    });

    test('decode preserves error fields', () {
      final original = IpcResponse.err(
        id: '9',
        error: IpcError(
          code: IpcExitCode.conflict,
          kind: IpcErrorKind.conflict,
          message: 'race',
        ),
      );
      final r = IpcMessage.decode(original.encode()) as IpcResponse;
      expect(r.ok, false);
      expect(r.error, isNotNull);
      expect(r.error!.code, IpcExitCode.conflict);
      expect(r.error!.kind, IpcErrorKind.conflict);
      expect(r.error!.message, 'race');
      expect(r.error!.hint, isNull);
    });
  });

  group('IpcEvent', () {
    test('serializes subsystem + kind + ts + data', () {
      final ts = DateTime.utc(2026, 4, 21, 12, 0, 0);
      final e = IpcEvent(
        subsystem: 'git',
        kind: 'status-changed',
        timestamp: ts,
        data: const {'staged': 3},
      );
      final json = e.toJson();
      expect(json['type'], 'event');
      expect(json['subsystem'], 'git');
      expect(json['kind'], 'status-changed');
      expect(json['ts'], '2026-04-21T12:00:00.000Z');
      expect(json['data'], {'staged': 3});
    });
  });

  group('IpcMessage.decode errors', () {
    test('throws on non-object line', () {
      expect(() => IpcMessage.decode('[]'), throwsA(isA<FormatException>()));
    });

    test('throws on unknown type', () {
      expect(
        () => IpcMessage.decode('{"type":"bogus","id":"1"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on malformed JSON', () {
      expect(() => IpcMessage.decode('{this is not json'), throwsA(isA<FormatException>()));
    });
  });
}
