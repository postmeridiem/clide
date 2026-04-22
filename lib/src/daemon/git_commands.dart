/// Registers `git.*` command handlers on the daemon dispatcher.
///
/// Verbs follow D-006's subsystem contract. Every mutation emits a
/// `git.changed` event so subscribers (the git panel, `clide tail`)
/// can refresh.
library;

import 'dart:io';

import '../git/diff.dart';
import '../git/operations.dart';
import '../git/status.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import 'dispatcher.dart';

void registerGitCommands(
  DaemonDispatcher d,
  Directory workDir,
  DaemonEventSink events,
) {
  d.register('git.status', (req) async {
    final status = await gitStatus(workDir);
    return IpcResponse.ok(id: req.id, data: status.toJson());
  });

  d.register('git.diff', (req) async {
    final staged = req.args['staged'] as bool? ?? false;
    final paths = _pathList(req.args['paths']);
    final diffs = await gitDiff(workDir, staged: staged, paths: paths);
    return IpcResponse.ok(id: req.id, data: {
      'staged': staged,
      'diffs': [for (final d in diffs) d.toJson()],
    });
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
      await gitStage(workDir, paths);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: {'staged': paths});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stage-all', (req) async {
    try {
      await gitStage(workDir, const []);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'staged': 'all'});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.unstage', (req) async {
    final paths = _pathList(req.args['paths']);
    try {
      await gitUnstage(workDir, paths);
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
      await gitStageHunk(workDir, patch);
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
      await gitUnstageHunk(workDir, patch);
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
      await gitDiscard(workDir, paths);
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
      final hash = await gitCommit(workDir, message);
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
      await gitStash(workDir, message: message, includeUntracked: includeUntracked);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'stashed': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.stash-pop', (req) async {
    try {
      await gitStashPop(workDir);
      _emitChanged(events);
      return IpcResponse.ok(id: req.id, data: const {'popped': true});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.log', (req) async {
    final count = (req.args['count'] as num?)?.toInt() ?? 20;
    final entries = await gitLog(workDir, count: count);
    return IpcResponse.ok(id: req.id, data: {
      'entries': [for (final e in entries) e.toJson()],
    });
  });

  d.register('git.pull', (req) async {
    try {
      final output = await gitPull(workDir);
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
      final output = await gitPush(
        workDir,
        remote: remote,
        branch: branch,
        setUpstream: setUpstream,
      );
      return IpcResponse.ok(id: req.id, data: {'output': output});
    } on GitException catch (e) {
      return _gitError(req.id, e);
    }
  });

  d.register('git.branches', (req) async {
    final branches = await gitBranches(workDir);
    return IpcResponse.ok(id: req.id, data: {
      'branches': [
        for (final b in branches)
          {'name': b.name, 'current': b.current},
      ],
    });
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
      await gitCheckout(workDir, branch);
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
