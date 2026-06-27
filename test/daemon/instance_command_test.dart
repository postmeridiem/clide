/// Tests for the `instance` command verb (T-247) — this clide's identity
/// (version / pid / workspace / socket path), the per-instance metadata the
/// `clide instances` CLI verb aggregates. Covers the dispatch mechanics
/// independent of the C client.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/instance_command.dart';
import 'package:test/test.dart';

void main() {
  test('instance resolves and returns version/pid/workspace/socketPath', () async {
    final d = DaemonDispatcher();
    registerInstanceCommand(d, version: '1.2.3', pid: 4242, workspace: '/repo', socketPath: '/run/user/1000/clide/abc.sock');
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'instance', args: const {}));
    expect(r.ok, isTrue);
    expect(r.data, {'version': '1.2.3', 'pid': 4242, 'workspace': '/repo', 'socketPath': '/run/user/1000/clide/abc.sock'});
  });
}
