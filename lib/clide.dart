/// clide — Dart core library.
///
/// Shared by `bin/clide.dart` (CLI + daemon) and by the Flutter app
/// under `app/` (which depends on this package via `path: ../`).
///
/// See:
///   * `decisions/architecture.md` `D-005` — layout + language rationale.
///   * `decisions/architecture.md` `D-006` — CLI + event contract.
library;

export 'src/daemon/dispatcher.dart';
export 'src/daemon/files_commands.dart';
export 'src/daemon/pane_commands.dart';
export 'src/files/ignore.dart';
export 'src/files/listing.dart' show FileEntry, listDir;
export 'src/files/watcher.dart';
export 'src/ipc/envelope.dart';
export 'src/ipc/paths.dart';
export 'src/ipc/schema_v1.dart';
export 'src/ipc/server.dart';
export 'src/panes/event_sink.dart';
export 'src/panes/pane.dart' show Pane, PaneKind;
export 'src/panes/registry.dart' show PaneRegistry;
export 'src/pty/errors.dart' show PtyException;
export 'src/pty/pty.dart';

/// Build-time-stamped version string.
///
/// The Makefile's `build` target passes `--define=clideVersion=…` when
/// invoking `dart compile exe`, stamping `project.yaml`'s `version:`
/// plus the git short SHA and dirty marker.
const clideVersion = String.fromEnvironment(
  'clideVersion',
  defaultValue: '2.0.0-dev',
);

const clideCommit = String.fromEnvironment(
  'clideCommit',
  defaultValue: 'unknown',
);

const clideDate = String.fromEnvironment(
  'clideDate',
  defaultValue: 'unknown',
);
