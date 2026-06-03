/// Registers the `status` command — a one-shot orientation snapshot
/// (T-221, Gap 6 of self-analysis.md). It is the natural first call an
/// agent makes: active pane, focused file + selection, git summary, and
/// layout, in one round-trip, with exit 0.
///
/// The handler is intentionally thin: the snapshot is assembled by the
/// caller (main.dart), which holds the live kernel + subsystem state
/// (PanelRegistry, LayoutArrangement, EditorRegistry, GitClient,
/// ReaderNavRegistry). This file just exposes the verb and wraps the
/// assembled map, so it stays Flutter-free and trivially testable.
library;

import '../ipc/envelope.dart';
import 'dispatcher.dart';

/// Builds the orientation snapshot at request time. Returns a JSON-able map.
typedef StatusSnapshot = Future<Map<String, Object?>> Function();

void registerStatusCommand(DaemonDispatcher d, StatusSnapshot snapshot) {
  d.register('status', (req) async => IpcResponse.ok(id: req.id, data: await snapshot()));
}
