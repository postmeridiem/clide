/// Registers `log.level` — the live dev/prod verbosity toggle (T-433).
///
/// With no arg it reports the running [Logger]'s minimum level; with
/// `level=<name>` it sets the Logger AND persists `app.log.level` so the
/// choice survives a restart (resolved at boot by `resolveLogLevel`). The UI
/// half is the output dock's Level chip — D-6 parity. Flutter-free + trivially
/// testable: the handler takes the Logger and a persist callback.
library;

import 'package:clide/kernel/src/log.dart';

import '../ipc/envelope.dart';
import 'dispatcher.dart';

/// Persists the chosen level name (the owner wires this to
/// `settings.set('app.log.level', name)`).
typedef LogLevelPersist = Future<void> Function(String levelName);

void registerLogCommands(DaemonDispatcher d, Logger log, LogLevelPersist persist) {
  d.register('log.level', (req) async {
    final raw = req.args['level'];
    if (raw == null) {
      // Read: report the current level + the vocabulary.
      return IpcResponse.ok(id: req.id, data: {'level': log.minLevel.name, 'levels': LogLevel.values.map((l) => l.name).toList()});
    }
    final level = parseLogLevel(raw is String ? raw : raw.toString());
    if (level == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: 64, kind: 'bad_arg', message: 'unknown log level: $raw', hint: 'one of: ${LogLevel.values.map((l) => l.name).join(', ')}'),
      );
    }
    log.minLevel = level;
    await persist(level.name);
    return IpcResponse.ok(id: req.id, data: {'level': level.name});
  });
}
