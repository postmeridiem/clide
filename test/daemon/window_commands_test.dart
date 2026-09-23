/// `window.show|hide` and `app.quit [--all]` (T-590, D-110): the CLI half of
/// the tray menu, over a fake [WindowHost].
library;

import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/window_commands.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:test/test.dart';

class _FakeHost implements WindowHost {
  bool canShow = true;
  bool canHide = true;
  final calls = <String>[];

  @override
  Future<bool> show() async {
    calls.add('show');
    return canShow;
  }

  @override
  Future<bool> hide() async {
    calls.add('hide');
    return canHide;
  }

  @override
  Future<bool> quit({required bool all}) async {
    calls.add(all ? 'quitAll' : 'quit');
    return true;
  }
}

void main() {
  late DaemonDispatcher d;
  late _FakeHost host;
  WindowHost? current;

  setUp(() {
    d = DaemonDispatcher();
    host = _FakeHost();
    current = host;
    registerWindowCommands(d, () => current, quitGrace: const Duration(milliseconds: 5));
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) => d.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));

  test('window.show shows the window', () async {
    final r = await call('window.show');
    expect(r.ok, isTrue);
    expect(r.data['shown'], isTrue);
    expect(host.calls, ['show']);
  });

  test('window.hide hides it', () async {
    final r = await call('window.hide');
    expect(r.ok, isTrue);
    expect(r.data['hidden'], isTrue);
  });

  test('window.hide is refused when nothing could bring the window back', () async {
    host.canHide = false;
    final r = await call('window.hide');
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('no tray'));
  });

  test('window.show reports an unsupported platform as an error', () async {
    host.canShow = false;
    expect((await call('window.show')).ok, isFalse);
  });

  test('app.quit answers first, then quits this window', () async {
    final r = await call('app.quit');
    expect(r.ok, isTrue);
    expect(r.data['quitting'], 'this');
    expect(host.calls, isEmpty, reason: 'the reply goes out before the process does');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(host.calls, ['quit']);
  });

  test('app.quit --all quits every window', () async {
    final r = await call('app.quit', {'all': true});
    expect(r.data['quitting'], 'all');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(host.calls, ['quitAll']);
  });

  test('no host (headless) is a clear error for every verb', () async {
    current = null;
    for (final cmd in ['window.show', 'window.hide', 'app.quit']) {
      final r = await call(cmd);
      expect(r.ok, isFalse, reason: cmd);
      expect(r.error!.message, contains('unavailable'), reason: cmd);
    }
  });
}
