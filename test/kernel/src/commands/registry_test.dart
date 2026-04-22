import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

CommandContribution _cmd(String name, Future<IpcResponse> Function() run) =>
    CommandContribution(
      id: name,
      command: name,
      title: 'cmd $name',
      run: (_) => run(),
    );

void main() {
  group('CommandRegistry', () {
    test('register exposes the command; all enumerates', () {
      final r = CommandRegistry();
      r.register(_cmd('a', () async => IpcResponse.ok(id: '', data: const {})));
      r.register(_cmd('b', () async => IpcResponse.ok(id: '', data: const {})));
      expect(r.all.map((c) => c.command).toList(), ['a', 'b']);
      expect(r.get('a'), isNotNull);
    });

    test('execute returns the handler response', () async {
      final r = CommandRegistry();
      r.register(
        _cmd(
          'ping',
          () async => IpcResponse.ok(id: '', data: const {'pong': true}),
        ),
      );
      final resp = await r.execute('ping');
      expect(resp.ok, true);
      expect(resp.data['pong'], true);
    });

    test('execute on unknown returns NotFound error', () async {
      final r = CommandRegistry();
      final resp = await r.execute('missing');
      expect(resp.ok, false);
      expect(resp.error!.code, IpcExitCode.notFound);
    });

    test('unregister removes the command', () {
      final r = CommandRegistry();
      r.register(_cmd('x', () async => IpcResponse.ok(id: '', data: const {})));
      r.unregister('x');
      expect(r.get('x'), isNull);
    });
  });
}
