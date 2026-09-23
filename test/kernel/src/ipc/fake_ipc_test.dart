/// Pins the test IPC fake's contract (T-638).
library;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_ipc.dart';

void main() {
  late FakeDaemonClient ipc;
  setUp(() => ipc = FakeDaemonClient(log: Logger(), events: DaemonBus()));
  tearDown(() => ipc.dispose());

  test('logs every request in order, stubbed or not', () async {
    ipc.stub('a', (_) async => IpcResponse.ok(id: '', data: const {}));
    await ipc.request('a', args: const {'x': 1});
    await ipc.request('b');
    expect(ipc.commands, ['a', 'b']);
    expect(ipc.callsTo('a'), [
      {'x': 1},
    ]);
  });

  test('lenient by default: an unstubbed command answers not-found', () async {
    final r = await ipc.request('nope');
    expect(r.error!.kind, IpcErrorKind.notFound);
  });

  test('strict: an unstubbed command fails loudly', () {
    ipc.strict = true;
    expect(() => ipc.request('nope', args: const {'id': 7}), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('"nope"'))));
  });

  test('requireConnection answers like the real client when disconnected', () async {
    ipc
      ..requireConnection = true
      ..stub('ping', (_) async => IpcResponse.ok(id: '', data: const {'pong': true}));
    final down = await ipc.request('ping');
    expect(down.ok, isFalse);
    expect(down.error!.message, 'daemon not connected');
    ipc.setConnected(true);
    expect((await ipc.request('ping')).ok, isTrue);
  });

  test('reconnects are recorded, never dialled, and notify', () async {
    var notified = 0;
    ipc.addListener(() => notified++);
    await ipc.reconnectAt('/tmp/other.sock');
    expect(ipc.reconnects, ['/tmp/other.sock']);
    expect(ipc.isConnected, isTrue);
    ipc.reconnectSucceeds = false;
    await ipc.reconnectAt('/tmp/third.sock');
    expect(ipc.isConnected, isFalse);
    expect(notified, greaterThan(0));
  });

  test('deferred replies can be answered out of order', () async {
    final d = ipc.defer('read');
    final first = ipc.request('read', args: const {'id': 1});
    final second = ipc.request('read', args: const {'id': 2});
    expect(d.pending.map((c) => c.args['id']), [1, 2]);

    d.calls[1].ok(const {'v': 'second'});
    expect((await second).data['v'], 'second');
    expect(d.pending.map((c) => c.args['id']), [1]);

    d.calls[0].err('boom');
    expect((await first).error!.message, 'boom');
    expect(d.pending, isEmpty);
  });
}
