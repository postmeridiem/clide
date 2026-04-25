/// Registers `git.*` command handlers on the daemon dispatcher.
///
/// Verbs follow D-006's subsystem contract. Every mutation emits a
/// `git.changed` event so subscribers (the git panel, `clide tail`)
/// can refresh.
library;

import '../git/client.dart';
import '../git/operations.dart' show GitException;
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import 'dispatcher.dart';

void registerGitCommands(
  DaemonDispatcher d,
  GitClient git,
  DaemonEventSink events,
) {
  d.register('git.status', (req) async {
    try {
      final status = await git.status();
      return IpcResponse.ok(id: req.id, data: status.toJson());
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.diff', (req) async {
    try {
      final staged = req.args['staged'] as bool? ?? false;
      final paths = _pathList(req.args['paths']);
      final diffs = await git.diff(staged: staged, paths: paths);
      return IpcResponse.ok(id: req.id, data: {
        'staged': staged,
        'diffs': [for (final d in diffs) d.toJson()],
      });
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stage', (req) async {
    final paths = _pathList(req.args['paths']);
    if (paths.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.stage requires paths',
          hint: 'pass {paths: ["file.txt"]}',
        ),
      );
    }
    try {
      await git.stage(paths);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'staged': paths});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stage-all', (req) async {
    try {
      await git.stage(const []);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'staged': 'all'});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.unstage', (req) async {
    final paths = _pathList(req.args['paths']);
    try {
      await git.unstage(paths);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'unstaged': paths});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stage-hunk', (req) async {
    final patch = req.args['patch'] as String?;
    if (patch == null || patch.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.stage-hunk requires a patch',
        ),
      );
    }
    try {
      await git.stageHunk(patch);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'applied': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.unstage-hunk', (req) async {
    final patch = req.args['patch'] as String?;
    if (patch == null || patch.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.unstage-hunk requires a patch',
        ),
      );
    }
    try {
      await git.unstageHunk(patch);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'applied': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.discard', (req) async {
    final paths = _pathList(req.args['paths']);
    if (paths.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.discard requires paths',
        ),
      );
    }
    try {
      await git.discard(paths);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'discarded': paths});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.commit', (req) async {
    final message = req.args['message'] as String?;
    if (message == null || message.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.commit requires a message',
        ),
      );
    }
    try {
      final hash = await git.commit(message);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'hash': hash});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stash', (req) async {
    final message = req.args['message'] as String?;
    final includeUntracked = req.args['includeUntracked'] as bool? ?? false;
    try {
      await git.stash(message: message, includeUntracked: includeUntracked);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'stashed': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stash-pop', (req) async {
    try {
      await git.stashPop();
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'popped': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.log', (req) async {
    try {
      final count = (req.args['count'] as num?)?.toInt() ?? 20;
      final entries = await git.log(count: count);
      return IpcResponse.ok(id: req.id, data: {
        'entries': [for (final e in entries) e.toJson()],
      });
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.pull', (req) async {
    try {
      final output = await git.pull();
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'output': output});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.push', (req) async {
    final remote = req.args['remote'] as String?;
    final branch = req.args['branch'] as String?;
    final setUpstream = req.args['setUpstream'] as bool? ?? false;
    try {
      final output = await git.push(remote: remote, branch: branch, setUpstream: setUpstream);
      return IpcResponse.ok(id: req.id, data: {'output': output});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.branches', (req) async {
    try {
      final b = await git.branches();
      return IpcResponse.ok(id: req.id, data: {
        'branches': [for (final e in b) {'name': e.name, 'current': e.current}],
      });
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.checkout', (req) async {
    final branch = req.args['branch'] as String?;
    if (branch == null || branch.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.userError,
          kind: IpcErrorKind.userError,
          message: 'git.checkout requires a branch',
        ),
      );
    }
    try {
      await git.checkout(branch);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'branch': branch});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });
}

List<String> _pathList(Object? raw) {
  if (raw is List) return raw.cast<String>();
  if (raw is String) return [raw];
  return const [];
}

void _emitChanged(DaemonEventSink events) {
  events.emit(IpcEvent(
    subsystem: 'git',
    kind: 'git.changed',
    timestamp: DateTime.now().toUtc(),
    data: const {},
  ));
}

IpcResponse _gitError(String id, GitException e) {
  return IpcResponse.err(
    id: id,
    error: IpcError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: e.message,
      hint: e.stderr.isNotEmpty ? e.stderr : null,
    ),
  );
}
