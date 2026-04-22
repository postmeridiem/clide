/// clide — Dart core library.
///
/// Shared by `bin/clide.dart` (CLI + daemon) and by the Flutter app
/// under `app/` (which depends on this package via `path: ../`).
///
/// See:
///   * `decisions/architecture.md` `D-005` — layout + language rationale.
///   * `decisions/architecture.md` `D-006` — CLI + event contract.
library;

// Flutter-app-visible surface. Deliberately **does not** export the
// `pty/` or `panes/registry.dart` modules — those import `dart:ffi`
// and pull in the PTY machinery that only runs on desktop. The
// daemon entrypoint (`bin/clide.dart`) imports them via deep paths.
//
// `Pane` + `PaneKind` + the event-sink interfaces travel here because
// they're pure data types that both the app and the daemon reference.

export 'src/daemon/dispatcher.dart';
export 'src/editor/buffer.dart';
export 'src/files/ignore.dart';
export 'src/files/listing.dart' show FileEntry, listDir;
export 'src/git/diff.dart' show GitDiff, GitHunk, DiffLine, DiffLineKind;
export 'src/git/operations.dart' show GitLogEntry, GitException;
export 'src/git/status.dart'
    show GitStatus, GitFileStatus, GitFileState, GitConflictType;
export 'src/pql/client.dart' show PqlClient, PqlException;
export 'src/ipc/envelope.dart';
export 'src/ipc/paths.dart';
export 'src/ipc/schema_v1.dart';
export 'src/ipc/server.dart';
export 'src/panes/event_sink.dart';
export 'src/panes/pane.dart' show Pane, PaneKind;

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
