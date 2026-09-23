/// `clide claude restore` — reopen the workspace's secondary Claude sessions
/// from last time (T-589, D-114). The CLI half of the "Restore" offer above the
/// Claude tabs and the `claude.restore-sessions` palette command (D-6).
library;

import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';

/// [restore] reopens them and returns how many came back, or null when the
/// Claude tab isn't there to host them (it exists only once the UI is built).
void registerClaudeRestoreCommand(DaemonDispatcher d, int? Function() restore) {
  d.register('claude.restore', (req) async {
    final n = restore();
    if (n == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'the Claude tab is not open'),
      );
    }
    return IpcResponse.ok(id: req.id, data: {'restored': n});
  });
}
