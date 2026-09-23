import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

CommandContribution _cmd(String name, Future<IpcResponse> Function() run) =>
    CommandContribution(id: name, command: name, title: 'cmd $name', run: (_) => run());

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
      r.register(_cmd('ping', () async => IpcResponse.ok(id: '', data: const {'pong': true})));
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

    // T-637 (#14): a second register used to overwrite silently, and the
    // first owner's unregister then removed the second owner's command.
    test('registering a taken id throws and keeps the first owner', () {
      final r = CommandRegistry();
      final first = _cmd('dup', () async => IpcResponse.ok(id: '', data: const {}));
      r.register(first);
      expect(() => r.register(_cmd('dup', () async => IpcResponse.ok(id: '', data: const {}))), throwsStateError);
      expect(r.get('dup'), same(first));
    });

    test('unregister with an owner leaves a different registration alone', () {
      final r = CommandRegistry();
      final stale = _cmd('y', () async => IpcResponse.ok(id: '', data: const {}));
      final current = _cmd('y', () async => IpcResponse.ok(id: '', data: const {}));
      r.register(stale);
      r.unregister('y', owner: stale);
      r.register(current);
      r.unregister('y', owner: stale);
      expect(r.get('y'), same(current));
      r.unregister('y', owner: current);
      expect(r.get('y'), isNull);
    });
  });
}
