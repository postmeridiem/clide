/// Unit tests for the daemon's command dispatcher.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/ipc/command_schema.dart';
import 'package:test/test.dart';

IpcRequest _req(String cmd, {String id = '1', Map<String, Object?> args = const {}}) {
  return IpcRequest(id: id, cmd: cmd, args: args);
}

void main() {
  group('DaemonDispatcher', () {
    test('ping is registered by default and returns pong + version', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('ping'));
      expect(r.ok, isTrue);
      expect(r.data['pong'], isTrue);
      expect(r.data['version'], isNotNull);
      expect(r.data['ts'], isA<String>());
    });

    test('version returns the bundled version string', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('version'));
      expect(r.ok, isTrue);
      expect(r.data['version'], clideVersion);
    });

    test('dispatching an unknown command produces a not-found error', () async {
      final d = DaemonDispatcher();
      final r = await d.dispatch(_req('nonsense'));
      expect(r.ok, isFalse);
      expect(r.error?.kind, IpcErrorKind.notFound);
      expect(r.error?.message, contains('unknown command'));
    });

    test('register routes a new handler', () async {
      final d = DaemonDispatcher();
      d.register('echo', (req) async {
        return IpcResponse.ok(id: req.id, data: {'echo': req.args['text']});
      });
      final r = await d.dispatch(_req('echo', args: {'text': 'hi'}));
      expect(r.ok, isTrue);
      expect(r.data['echo'], 'hi');
    });

    test('isEmpty is true for a fresh dispatcher (ping + version only)', () {
      final d = DaemonDispatcher();
      expect(d.isEmpty, isTrue);
      d.register('something', (req) async => IpcResponse.ok(id: req.id, data: const {}));
      expect(d.isEmpty, isFalse);
    });

    test('capabilities reflects the live registry with schemas (T-248)', () async {
      final d = DaemonDispatcher();
      d.register('echo', (req) async => IpcResponse.ok(id: req.id, data: const {}));
      d.register(
        'pane.resize',
        (req) async => IpcResponse.ok(id: req.id, data: const {}),
        schema: const CommandSchema(
          positional: ['id', 'cols'],
          args: {
            'id': ArgSpec(required: true),
            'cols': ArgSpec(type: ArgType.number, min: 1),
          },
        ),
      );

      final r = await d.dispatch(_req('capabilities'));
      expect(r.ok, isTrue);
      final commands = r.data['commands'] as Map<String, Object?>;
      // Built-ins + the two just registered are all discoverable.
      expect(commands.keys, containsAll(['ping', 'version', 'capabilities', 'echo', 'pane.resize']));

      // Subsystem/verb split.
      final resize = commands['pane.resize'] as Map<String, Object?>;
      expect(resize['subsystem'], 'pane');
      expect(resize['verb'], 'resize');
      expect(resize['positional'], ['id', 'cols']);
      final args = resize['args'] as Map<String, Object?>;
      expect((args['id'] as Map)['required'], true);
      expect((args['cols'] as Map)['type'], 'number');
      expect((args['cols'] as Map)['min'], 1);

      // A schema-less command carries no positional/args keys.
      final echo = commands['echo'] as Map<String, Object?>;
      expect(echo['subsystem'], '');
      expect(echo.containsKey('args'), isFalse);
    });

    test('clear removes user handlers but keeps the built-ins', () async {
      final d = DaemonDispatcher();
      d.register('extra', (req) async => IpcResponse.ok(id: req.id, data: const {}));
      expect(d.isEmpty, isFalse);
      d.clear();
      expect(d.isEmpty, isTrue);
      // ping still works
      final r = await d.dispatch(_req('ping'));
      expect(r.ok, isTrue);
      // 'extra' is gone
      final r2 = await d.dispatch(_req('extra'));
      expect(r2.ok, isFalse);
    });
  });
}
