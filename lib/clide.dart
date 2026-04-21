/// clide — Dart core library.
///
/// Shared by `bin/clide.dart` (CLI + daemon) and by the Flutter app
/// under `app/` (which depends on this package via `path: ../`).
///
/// See:
///   * docs/ADRs/0005-dart-core-ptyc-peer.md — layout + language rationale.
///   * docs/ADRs/0006-cli-and-event-surface.md — CLI + event contract.
library;

export 'src/daemon/dispatcher.dart';
export 'src/ipc/envelope.dart';
export 'src/ipc/paths.dart';
export 'src/ipc/schema_v1.dart';
export 'src/ipc/server.dart';

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
