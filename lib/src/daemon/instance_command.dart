/// Registers the `instance` command — this running clide's identity in one
/// round-trip (T-247): version, pid, workspace root, and socket path. It's the
/// per-instance metadata the `clide instances` CLI verb aggregates (by probing
/// every live socket in the runtime dir), and it lets a human or agent confirm
/// *which* instance a given socket belongs to.
///
/// Thin + Flutter-free: the caller (main.dart) passes the values it already
/// holds at dispatcher-build time, so this stays trivially testable.
library;

import '../ipc/envelope.dart';
import 'dispatcher.dart';

void registerInstanceCommand(DaemonDispatcher d, {required String version, required int pid, required String workspace, required String socketPath}) {
  d.register('instance', (req) async => IpcResponse.ok(id: req.id, data: {'version': version, 'pid': pid, 'workspace': workspace, 'socketPath': socketPath}));
}
