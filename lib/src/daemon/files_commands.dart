/// Registers `files.*` command handlers + wires a [FileWatcher]
/// into the event bus.
library;

import 'dart:io';

import '../files/ignore.dart';
import '../files/listing.dart';
import '../files/path_safety.dart';
import '../files/watcher.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import 'dispatcher.dart';

/// Daemon-side state for the `files` subsystem. Holds one
/// [FileWatcher] rooted at the workspace and a resolved [IgnoreSet].
class FilesService {
  FilesService({
    required this.root,
    required this.events,
    IgnoreSet? ignore,
  }) : ignore = ignore ?? _defaultIgnore(root);

  /// Build from the current working directory, walking up to the git
  /// root if present. Falls back to CWD otherwise.
  factory FilesService.atCwd({required DaemonEventSink events}) {
    final root = _resolveWorkspaceRoot(Directory.current);
    return FilesService(root: root, events: events);
  }

  final Directory root;
  final IgnoreSet ignore;
  final DaemonEventSink events;

  FileWatcher? _watcher;

  Future<void> startWatching() async {
    if (_watcher != null) return;
    final w = FileWatcher(root: root, ignore: ignore);
    _watcher = w;
    await w.start();
    w.stream.listen((change) {
      events.emit(IpcEvent(
        subsystem: 'files',
        kind: 'files.changed',
        timestamp: DateTime.now().toUtc(),
        data: change.toJson(),
      ));
    });
  }

  Future<void> shutdown() async {
    await _watcher?.stop();
    _watcher = null;
  }
}

void registerFilesCommands(DaemonDispatcher d, FilesService files) {
  d.register(
      'files.root',
      (req) async => IpcResponse.ok(
            id: req.id,
            data: {
              'path': files.root.absolute.path,
              'ignorePatterns': files.ignore.length,
            },
          ));

  d.register('files.read', (req) async {
    final path = req.args['path'] as String?;
    if (path == null || path.isEmpty) {
      return IpcResponse.err(id: req.id, error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'files.read requires a path'));
    }
    final String absPath;
    try {
      absPath = resolveUnderRoot(files.root, path);
    } on PathOutsideRoot {
      return IpcResponse.err(id: req.id, error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: $path'));
    }
    final file = File(absPath);
    if (!file.existsSync()) {
      return IpcResponse.err(id: req.id, error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'file not found: $path'));
    }
    final content = file.readAsStringSync();
    return IpcResponse.ok(id: req.id, data: {'path': path, 'content': content});
  });

  d.register('files.ls', (req) async {
    final dir = (req.args['path'] as String?) ?? '';
    if (dir.isNotEmpty) {
      try {
        resolveUnderRoot(files.root, dir);
      } on PathOutsideRoot {
        return IpcResponse.err(id: req.id, error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: $dir'));
      }
    }
    final entries = await listDir(
      root: files.root,
      dir: dir,
      ignore: files.ignore,
    );
    return IpcResponse.ok(
      id: req.id,
      data: {
        'path': dir,
        'entries': [for (final e in entries) e.toJson()],
      },
    );
  });

  d.register('files.watch', (req) async {
    await files.startWatching();
    return IpcResponse.ok(
      id: req.id,
      data: const {'subscribed': true},
    );
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

/// Build the default IgnoreSet: clide's always-hide list + any
/// `.gitignore` + `.clideignore` at the workspace root.
///
/// D-004 compliance note: this covers the single-file-at-root case.
/// Full layering across arbitrary paths from `.pql/config.yaml`'s
/// `ignore_files:` is future work — see Q-024 (to be recorded).
IgnoreSet _defaultIgnore(Directory root) {
  final contents = <String>[];
  for (final name in ['.gitignore', '.clideignore']) {
    final f = File('${root.path}/$name');
    if (f.existsSync()) contents.add(f.readAsStringSync());
  }
  final user = IgnoreSet.parse(contents);
  // Merge: built-in patterns first, user patterns last. "Last match
  // wins" semantics give the user the ability to un-ignore via `!`
  // in a future extension of the matcher.
  return IgnoreSet([
    ...IgnoreSet.builtin().patterns,
    ...user.patterns,
  ]);
}
