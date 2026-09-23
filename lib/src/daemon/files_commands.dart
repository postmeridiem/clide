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
import '../ipc/content_args.dart';
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
/// The user-scope Claude dirs `files read` may reach outside the workspace
/// (D-80): `~/.claude/{skills,agents,commands}` under [home], those that
/// exist. Never `~/.claude` itself — it holds Claude's credentials and
/// settings, and files read is pre-approved for agents (D-115).
List<Directory> claudeConfigReadRoots(String? home) {
  if (home == null || home.isEmpty) return const [];
  return [
    for (final d in const ['skills', 'agents', 'commands'])
      if (Directory('$home/.claude/$d').existsSync()) Directory('$home/.claude/$d'),
  ];
}

class FilesService {
  FilesService({required this.root, required this.events, IgnoreSet? ignore, this.extraReadRoots = const []}) : ignore = ignore ?? _defaultIgnore(root);

  /// Build from the current working directory, walking up to the git
  /// root if present. Falls back to CWD otherwise.
  factory FilesService.atCwd({required DaemonEventSink events}) {
    final root = resolveWorkspaceRoot(Directory.current);
    return FilesService(root: root, events: events);
  }

  final Directory root;
  final IgnoreSet ignore;
  final DaemonEventSink events;

  /// Trusted read-only roots outside the workspace that `files.read`
  /// also accepts (the Claude config dirs, D-80). Writes ignore these.
  final List<Directory> extraReadRoots;

  FileWatcher? _watcher;

  final List<void Function(FileChange change)> _changeListeners = [];

  /// Hear every change the workspace watcher reports, in-process — for
  /// subsystems that react to files on disk (the editor re-resolving
  /// `.editorconfig`, T-291) without a watcher of their own. Only fires once
  /// [startWatching] has run.
  void addChangeListener(void Function(FileChange change) listener) => _changeListeners.add(listener);

  Future<void> startWatching() async {
    if (_watcher != null) return;
    final w = FileWatcher(root: root, ignore: ignore);
    _watcher = w;
    await w.start();
    w.stream.listen((change) {
      events.emit(IpcEvent(subsystem: 'files', kind: 'files.changed', timestamp: DateTime.now().toUtc(), data: change.toJson()));
      for (final listener in _changeListeners) {
        listener(change);
      }
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
    final String content;
    try {
      final length = file.lengthSync();
      if (length > _filesReadMaxBytes) {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'file too large: $path ($length bytes; cap $_filesReadMaxBytes)'),
        );
      }
      content = file.readAsStringSync();
    } on FileSystemException catch (e) {
      // Not UTF-8, unreadable, or deleted between the exists check and the
      // read — a clean tool error rather than a dispatch crash (T-81 #17).
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'files.read failed: ${e.message}', hint: path),
      );
    }
    return IpcResponse.ok(id: req.id, data: {'path': path, 'content': content});
  }, schema: _pathArg);

  d.register(
    'files.write',
    (req) async {
      final path = req.args['path'] as String?;
      if (path == null || path.isEmpty) {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'files.write requires a path'),
        );
      }
      final String absPath;
      try {
        // Workspace root only — deliberately NOT the extraReadRoots widening
        // files.read gets (D-80): those are trusted for reading, not writing.
        absPath = resolveForWriteUnderRoot(files.root, path);
      } on PathOutsideRoot {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'path outside workspace: $path'),
        );
      }
      if (isProtectedWritePath(files.root, absPath)) {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(
            code: IpcExitCode.userError,
            kind: IpcErrorKind.userError,
            message: 'protected path: $path',
            hint: 'files write never writes under .git/ or .claude/ (D-115) — edit those yourself',
          ),
        );
      }
      final content = contentFromArgs(req.args);
      try {
        await File(absPath).writeAsString(content);
      } on FileSystemException catch (e) {
        return IpcResponse.err(
          id: req.id,
          error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'files.write failed: ${e.message}', hint: path),
        );
      }
      return IpcResponse.ok(id: req.id, data: {'path': path, 'bytes': content.length});
    },
    // `clide files write <path> [text]` — content also accepts
    // `--content_b64` for anything a shell argument can't carry.
    schema: const CommandSchema(positional: ['path', 'text'], args: {'path': ArgSpec(), 'text': ArgSpec(), 'content_b64': ArgSpec()}),
  );

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

Directory resolveWorkspaceRoot(Directory start) {
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

/// Pick the workspace root to boot the daemon at.
///
/// Prefer the launch CWD when it's inside a git repo. Otherwise — desktop
/// launches start in HOME, which isn't a repo — fall back to the last opened
/// project so pql/git/files target the real workspace from the very first
/// request. Booting at HOME instead makes pql run there and hit a stale
/// `~/.pql/pql.db`, so the ticket/decision sidebars error on first load and
/// only recover once the project is (re)opened. Falls back to [cwdRoot] when
/// there's no valid last project. (T-352)
Directory resolveStartupWorkspace({required Directory cwdRoot, required String? lastProject, required bool Function(Directory) isGitRepo}) {
  if (isGitRepo(cwdRoot)) return cwdRoot;
  if (lastProject != null && lastProject.isNotEmpty) {
    final dir = Directory(lastProject);
    if (isGitRepo(dir)) return dir;
  }
  return cwdRoot;
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
