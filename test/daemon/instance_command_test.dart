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

  test('it carries the build stamp, which is what actually identifies a build', () async {
    // The version alone answers "which release", and every build between two
    // releases shares it — which cost a live testing session when a relaunch
    // quietly ran a two-hour-old bundle and nothing could say so.
    final d = DaemonDispatcher();
    registerInstanceCommand(d, version: '1.2.3', commit: 'abc1234', builtAt: '2026-08-11T15:36:18Z', pid: 1, workspace: '/repo', socketPath: '/s.sock');
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'instance', args: const {}));

    expect(r.data['commit'], 'abc1234');
    expect(r.data['builtAt'], '2026-08-11T15:36:18Z');
  });

  test('an unstamped build omits the keys rather than reporting unknown', () async {
    // Absent is honest; a placeholder would be a value someone could compare.
    final d = DaemonDispatcher();
    registerInstanceCommand(d, version: '1.2.3', pid: 1, workspace: '/repo', socketPath: '/s.sock');
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'instance', args: const {}));

    expect(r.data.containsKey('commit'), isFalse);
    expect(r.data.containsKey('builtAt'), isFalse);
  });

  test('version carries it too, so one round-trip answers "which build"', () async {
    final d = DaemonDispatcher();
    final r = await d.dispatch(IpcRequest(id: '1', cmd: 'version', args: const {}));

    expect(r.data['version'], clideVersion);
    expect(r.data['commit'], clideCommit);
    expect(r.data['builtAt'], clideDate);
  });
}
