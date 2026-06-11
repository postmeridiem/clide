/// Registers `files.*` command handlers + wires a [FileWatcher]
/// into the event bus.
library;

import 'dart:io';

import '../files/ignore.dart';
import '../files/listing.dart';
import '../files/path_safety.dart';
import '../files/pql_config.dart';
import '../files/watcher.dart';
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import 'dispatcher.dart';

/// Positional schema binding `clide files <verb> <path>` to args['path']
/// (T-232, via D-74 normalize). Non-required — the handlers keep their own
/// path checks — so the only effect is the positional→named mapping.
const _pathArg = CommandSchema(positional: ['path'], args: {'path': ArgSpec()});

/// Cap on `files.read` response size. UI doesn't render multi-MB
/// blobs usefully and a single uncapped call can OOM. Range/stream
/// reads will land as a separate command (T-104 follow-up).
const int _filesReadMaxBytes = 10 * 1024 * 1024;

/// Daemon-side state for the `files` subsystem. Holds one
/// [FileWatcher] rooted at the workspace and a resolved [IgnoreSet].
class FilesService {
  FilesService({required this.root, required this.events, IgnoreSet? ignore, this.extraReadRoots = const []}) : ignore = ignore ?? _defaultIgnore(root);

  /// Build from the current working directory, walking up to the git
  /// root if present. Falls back to CWD otherwise.
  factory FilesService.atCwd({required DaemonEventSink events}) {
    final root = _resolveWorkspaceRoot(Directory.current);
    return FilesService(root: root, events: events);
  }

  final Directory root;
  final IgnoreSet ignore;
  final DaemonEventSink events;

  /// Trusted read-only roots outside the workspace that `files.read`
  /// also accepts (the Claude config dirs, D-80). Writes ignore these.
  final List<Directory> extraReadRoots;

  FileWatcher? _watcher;

  Future<void> startWatching() async {
    if (_watcher != null) return;
    final w = FileWatcher(root: root, ignore: ignore);
    _watcher = w;
    await w.start();
    w.stream.listen((change) {
      events.emit(IpcEvent(subsystem: 'files', kind: 'files.changed', timestamp: DateTime.now().toUtc(), data: change.toJson()));
    });
  }

  Future<void> shutdown() async {
    await _watcher?.stop();
    _watcher = null;
  }
}

void registerFilesCommands(DaemonDispatcher d, FilesService files) {
  d.register('files.root', (req) async => IpcResponse.ok(id: req.id, data: {'path': files.root.absolute.path, 'ignorePatterns': files.ignore.length}));

  d.register('files.read', (req) async {
    final path = req.args['path'] as String?;
    if (path == null || path.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'files.read requires a path'),
      );
    }
    final String absPath;
    try {
      // Follow symlinks + re-check containment so a `config -> /etc/shadow`
      // symlink can't be read (T-102). Accepts the workspace root plus
      // the trusted extra read roots (Claude config dirs, D-80).
      absPath = resolveUnderRootsFollowingSymlinks(files.root, files.extraReadRoots, path);
    } on PathOutsideRoot {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: $path'),
      );
    }
    final file = File(absPath);
    if (!file.existsSync()) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'file not found: $path'),
      );
    }
    // Cap response size so a single IPC call can't OOM the UI on a
    // multi-gigabyte log file. Caller can paginate / stream via a
    // future range-read variant when that ships.
    final length = file.lengthSync();
    if (length > _filesReadMaxBytes) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'file too large: $path ($length bytes; cap $_filesReadMaxBytes)'),
      );
    }
    final content = file.readAsStringSync();
    return IpcResponse.ok(id: req.id, data: {'path': path, 'content': content});
  }, schema: _pathArg);

  d.register('files.ls', (req) async {
    final dir = (req.args['path'] as String?) ?? '';
    if (dir.isNotEmpty) {
      try {
        resolveUnderRootFollowingSymlinks(files.root, dir);
      } on PathOutsideRoot {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: $dir'),
        );
      }
    }
    final entries = await listDir(root: files.root, dir: dir, ignore: files.ignore);
    return IpcResponse.ok(
      id: req.id,
      data: {
        'path': dir,
        'entries': [for (final e in entries) e.toJson()],
      },
    );
  }, schema: _pathArg);

  d.register('files.walk', (req) async {
    final result = await walkFiles(root: files.root, ignore: files.ignore);
    return IpcResponse.ok(
      id: req.id,
      data: {
        'files': [for (final e in result.files) e.path],
        'truncated': result.truncated,
      },
    );
  });

  d.register('files.watch', (req) async {
    await files.startWatching();
    return IpcResponse.ok(id: req.id, data: const {'subscribed': true});
  });
}

// ---------------------------------------------------------------------------

Directory _resolveWorkspaceRoot(Directory start) {
  Directory cur = start.absolute;
  for (var i = 0; i < 64; i++) {
    final g = Directory('${cur.path}/.git');
    if (g.existsSync()) return cur;
    final parent = cur.parent;
    if (parent.path == cur.path) break;
    cur = parent;
  }
  return start.absolute;
}

/// Build the default IgnoreSet: clide's always-hide list layered under
/// the `ignore_files:` chain from `.pql/config.yaml` (per D-4), in
/// order, later files winning. clide owns that config key (D-3) and
/// [readIgnoreFiles] resolves it (defaulting to `.gitignore` —
/// plus `.clideignore` when present — when the config is absent).
IgnoreSet _defaultIgnore(Directory root) {
  final contents = <String>[];
  for (final name in readIgnoreFiles(root)) {
    final f = File('${root.path}/$name');
    if (f.existsSync()) contents.add(f.readAsStringSync());
  }
  final user = IgnoreSet.parse(contents);
  // Merge: built-in patterns first, user patterns last. "Last match
  // wins" semantics give the user the ability to un-ignore via `!`
  // in a future extension of the matcher.
  return IgnoreSet([...IgnoreSet.builtin().patterns, ...user.patterns]);
}
