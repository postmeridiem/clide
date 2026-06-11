/// Registers `search.*` command handlers (T-52, per D-79).
///
/// `search.grep` kicks off a workspace content search and returns a
/// `searchId` immediately; match batches stream back as `search.match`
/// events, terminated by `search.done` (or `search.error`). This
/// mirrors `files.watch`'s event-streaming shape. `search.cancel` stops
/// an in-flight search by id.
library;

import 'dart:async';
import 'dart:io';

import '../files/ignore.dart';
import '../files/path_safety.dart';
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import '../search/grep_engine.dart';
import '../search/match.dart';
import '../search/replace_engine.dart';
import 'dispatcher.dart';

/// Owns in-flight searches and streams their results onto the event
/// sink. One instance per workspace, constructed alongside the other
/// daemon services.
class SearchService {
  SearchService({required this.root, required this.ignore, required this.events, this.useIsolates = true});

  final Directory root;
  final IgnoreSet ignore;
  final DaemonEventSink events;

  /// Whether the engine fans work across isolates. Tests set this false
  /// for deterministic, in-process runs.
  final bool useIsolates;

  final Map<String, CancelToken> _active = {};
  int _seq = 0;

  /// Begin a search; returns the id that scopes its stream of events.
  String start(SearchQuery query) {
    final id = 'search-${_seq++}';
    final cancel = CancelToken();
    _active[id] = cancel;
    unawaited(_run(id, query, cancel));
    return id;
  }

  /// Cancel an in-flight search (no-op if already finished).
  void cancel(String id) {
    _active.remove(id)?.cancel();
  }

  /// Compute (preview) or perform (apply) a search-and-replace.
  ///
  /// Preview returns per-file before/after edits without touching disk.
  /// Apply writes each changed file's new content through the workspace
  /// path-safety guard. The clean-git-tree safety gate is enforced by
  /// the caller (the UI checks `git.status` before requesting apply).
  Future<Map<String, Object?>> replace(SearchQuery query, String replacement, {required bool apply}) async {
    final files = await computeReplacements(root: root, ignore: ignore, query: query, replacement: replacement);
    if (!apply) {
      return {
        'apply': false,
        'files': [for (final f in files) f.toJson()],
        'fileCount': files.length,
        'totalCount': files.fold<int>(0, (s, f) => s + f.count),
      };
    }
    final rootPath = root.absolute.path;
    var changed = 0;
    var total = 0;
    for (final f in files) {
      final newContent = rewriteFileContent(rootPath, f.path, query, replacement);
      if (newContent == null) continue;
      final String abs;
      try {
        abs = resolveUnderRootFollowingSymlinks(root, f.path);
      } on PathOutsideRoot {
        continue;
      }
      try {
        File(abs).writeAsStringSync(newContent);
        changed++;
        total += f.count;
      } catch (_) {
        // skip unwritable files; the rest still apply
      }
    }
    return {'apply': true, 'filesChanged': changed, 'totalCount': total};
  }

  Future<void> _run(String id, SearchQuery query, CancelToken cancel) async {
    try {
      await for (final batch in grepWorkspace(root: root, ignore: ignore, query: query, cancel: cancel, useIsolates: useIsolates)) {
        if (cancel.isCancelled) break;
        _emit('search.match', {
          'searchId': id,
          'matches': [for (final m in batch) m.toJson()],
        });
      }
      _emit('search.done', {'searchId': id, 'cancelled': cancel.isCancelled});
    } on FormatException catch (e) {
      _emit('search.error', {'searchId': id, 'message': 'invalid regex: ${e.message}'});
    } catch (e) {
      _emit('search.error', {'searchId': id, 'message': '$e'});
    } finally {
      _active.remove(id);
    }
  }

  void _emit(String kind, Map<String, Object?> data) {
    events.emit(IpcEvent(subsystem: 'search', kind: kind, timestamp: DateTime.now().toUtc(), data: data));
  }
}

const CommandSchema _grepSchema = CommandSchema(
  positional: ['pattern'],
  args: {
    'pattern': ArgSpec(required: true),
    'regex': ArgSpec(type: ArgType.boolean),
    'ignoreCase': ArgSpec(type: ArgType.boolean),
    'include': ArgSpec(type: ArgType.stringList),
    'exclude': ArgSpec(type: ArgType.stringList),
  },
);

const CommandSchema _replaceSchema = CommandSchema(
  positional: ['pattern', 'replacement'],
  args: {
    'pattern': ArgSpec(required: true),
    'replacement': ArgSpec(),
    'regex': ArgSpec(type: ArgType.boolean),
    'ignoreCase': ArgSpec(type: ArgType.boolean),
    'include': ArgSpec(type: ArgType.stringList),
    'exclude': ArgSpec(type: ArgType.stringList),
    'apply': ArgSpec(type: ArgType.boolean),
  },
);

void registerSearchCommands(DaemonDispatcher d, SearchService search) {
  d.register('search.grep', (req) async {
    final query = SearchQuery.fromJson(req.args);
    if (query.pattern.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: 'search.grep requires a non-empty pattern'),
      );
    }
    final id = search.start(query);
    return IpcResponse.ok(id: req.id, data: {'searchId': id});
  }, schema: _grepSchema);

  d.register('search.replace', (req) async {
    final query = SearchQuery.fromJson(req.args);
    final replacement = (req.args['replacement'] as String?) ?? '';
    final apply = req.args['apply'] == true;
    if (query.pattern.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: 'search.replace requires a non-empty pattern'),
      );
    }
    try {
      final result = await search.replace(query, replacement, apply: apply);
      return IpcResponse.ok(id: req.id, data: result);
    } on FormatException catch (e) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: 'invalid regex: ${e.message}'),
      );
    }
  }, schema: _replaceSchema);

  d.register('search.cancel', (req) async {
    final id = req.args['searchId'] as String?;
    if (id == null || id.isEmpty) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: 'search.cancel requires a searchId'),
      );
    }
    search.cancel(id);
    return IpcResponse.ok(id: req.id, data: {'cancelled': id});
  });
}
