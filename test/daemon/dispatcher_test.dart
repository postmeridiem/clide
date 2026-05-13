/// Unit tests for the daemon's command dispatcher.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/dispatcher.dart';
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

    test('clear removes user handlers but keeps ping + version', () async {
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
