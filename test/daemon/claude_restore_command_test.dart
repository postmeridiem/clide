/// `clide claude restore` (T-589): reports how many sessions came back, or
/// that there's no Claude tab to put them in. Flutter-free.
library;

import 'package:clide/src/daemon/claude_restore_command.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:test/test.dart';

void main() {
  Future<IpcResponse> call(int? Function() restore) {
    final d = DaemonDispatcher();
    registerClaudeRestoreCommand(d, restore);
    return d.dispatch(IpcRequest(id: '1', cmd: 'claude.restore'));
  }

  test('reports how many sessions came back', () async {
    final r = await call(() => 2);
    expect(r.ok, isTrue);
    expect(r.data, {'restored': 2});
  });

  test('without a Claude tab it says so', () async {
    final r = await call(() => null);
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('Claude tab'));
  });
}
