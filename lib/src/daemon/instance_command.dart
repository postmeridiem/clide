/// Registers the `instance` command — this running clide's identity in one
/// round-trip (T-247): version, build stamp, pid, workspace root, and socket
/// path. It's the per-instance metadata the `clide instances` CLI verb
/// aggregates (by probing every live socket in the runtime dir), and it lets a
/// human or agent confirm *which* instance a given socket belongs to.
///
/// **The commit and build time are the load-bearing part.** `version` comes from
/// `pubspec.yaml`, so every build between two releases reports the same number —
/// which cost a live testing session when a relaunch quietly ran a two-hour-old
/// bundle and nothing on the machine could say so. The stamp makes staleness a
/// one-command check.
///
/// Thin + Flutter-free: the caller (main.dart) passes the values it already
/// holds at dispatcher-build time, so this stays trivially testable.
library;

import '../ipc/envelope.dart';
import 'dispatcher.dart';

void registerInstanceCommand(
  DaemonDispatcher d, {
  required String version,
  required int pid,
  required String workspace,
  required String socketPath,
  String? commit,
  String? builtAt,
}) {
  d.register(
    'instance',
    (req) async => IpcResponse.ok(
      id: req.id,
      data: {'version': version, 'commit': ?commit, 'builtAt': ?builtAt, 'pid': pid, 'workspace': workspace, 'socketPath': socketPath},
    ),
  );
}
