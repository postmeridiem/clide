/// pql CLI wrapper — shells out per D-003 (wrap, don't duplicate).
///
/// Every function runs `pql <subcommand>` as a subprocess, parses
/// the JSON stdout, and returns typed Dart maps. Errors surface as
/// [PqlException] with the stderr diagnostics attached.
library;

import 'dart:convert';
import 'dart:io';

import '../../kernel/src/toolchain_paths.dart';

class PqlException implements Exception {
  const PqlException(this.message, {this.exitCode = 1, this.stderr = ''});
  final String message;
  final int exitCode;
  final String stderr;

  @override
  String toString() => 'PqlException($exitCode): $message';
}

class PqlClient {
  PqlClient({required this.workDir, required this.toolchain});

  final Directory workDir;
  final ToolchainView toolchain;

  Future<List<Map<String, Object?>>> files({String? glob, int? limit}) async {
    final args = ['files'];
    if (glob != null) args.add(glob);
    if (limit != null) args.addAll(['--limit', '$limit']);
    return _runList(args);
  }

  Future<Map<String, Object?>> meta(String path) async {
    return _runObject(['meta', path]);
  }

  Future<List<Map<String, Object?>>> backlinks(String path) async {
    return _runList(['backlinks', path]);
  }

  Future<List<Map<String, Object?>>> outlinks(String path) async {
    return _runList(['outlinks', path]);
  }

  Future<List<Map<String, Object?>>> tags({int? limit}) async {
    final args = ['tags'];
    if (limit != null) args.addAll(['--limit', '$limit']);
    return _runList(args);
  }

  Future<List<Map<String, Object?>>> schema() async {
    return _runList(['schema']);
  }

  Future<List<Map<String, Object?>>> query(String dsl, {int? limit}) async {
    final args = ['query', dsl];
    if (limit != null) args.addAll(['--limit', '$limit']);
    return _runList(args);
  }

  Future<List<Map<String, Object?>>> search(String terms, {int? limit}) async {
    final args = ['search', terms];
    if (limit != null) args.addAll(['--limit', '$limit']);
    return _runList(args);
  }

  Future<Map<String, Object?>> doctor() async {
    return _runObject(['doctor']);
  }

  Future<Map<String, Object?>> decisionSync() async {
    return _runObject(['decisions', 'sync']);
  }

  Future<Object?> decisionValidate() async {
    return _runObject(['decisions', 'validate']);
  }

  Future<List<Map<String, Object?>>> decisionList({
    String? type,
    String? domain,
    String? status,
  }) async {
    final args = ['decisions', 'list'];
    if (type != null) args.addAll(['--type', type]);
    if (domain != null) args.addAll(['--domain', domain]);
    if (status != null) args.addAll(['--status', status]);
    return _runList(args);
  }

  Future<Map<String, Object?>> decisionShow(
    String id, {
    bool withRefs = false,
    bool withTickets = false,
  }) async {
    final args = ['decisions', 'show', id];
    if (withRefs) args.add('--with-refs');
    if (withTickets) args.add('--with-tickets');
    return _runObject(args);
  }

  Future<Map<String, Object?>> decisionRead(String id) async {
    return _runObject(['decisions', 'read', id]);
  }

  Future<List<Map<String, Object?>>> ticketList({
    String? status,
    String? team,
    String? assigned,
    String? decision,
  }) async {
    final args = ['ticket', 'list'];
    if (status != null) args.addAll(['--status', status]);
    if (team != null) args.addAll(['--team', team]);
    if (assigned != null) args.addAll(['--assigned', assigned]);
    if (decision != null) args.addAll(['--decision', decision]);
    return _runList(args);
  }

  Future<Map<String, Object?>> ticketShow(
    String id, {
    bool withContext = false,
    bool withBlockers = false,
  }) async {
    final args = ['ticket', 'show', id];
    if (withContext) args.add('--with-context');
    if (withBlockers) args.add('--with-blockers');
    return _runObject(args);
  }

  Future<List<Map<String, Object?>>> ticketSetStatus(List<String> ids, String status) async {
    return _runList(['ticket', 'status', ids.join(','), status]);
  }

  Future<List<Map<String, Object?>>> ticketBoard({String? team}) async {
    final args = ['ticket', 'board'];
    if (team != null) args.addAll(['--team', team]);
    return _runList(args);
  }

  Future<Map<String, Object?>> planStatus() async {
    return _runObject(['plan', 'status']);
  }

  // -------------------------------------------------------------------

  Future<List<Map<String, Object?>>> _runList(List<String> args) async {
    final result = await _run(args);
    if (result == null) return const [];
    if (result is List) {
      return [for (final e in result) (e as Map).cast<String, Object?>()];
    }
    return const [];
  }

  Future<Map<String, Object?>> _runObject(List<String> args) async {
    final result = await _run(args);
    if (result is Map) return result.cast<String, Object?>();
    return const {};
  }

  /// pql's exit code for a locked / unavailable planning DB (EX_UNAVAILABLE) —
  /// a transient SQLite-busy condition under concurrent access (T-350).
  static const int _kBusyExitCode = 69;
  static const int _kMaxAttempts = 4;

  Future<Object?> _run(List<String> args) async {
    for (var attempt = 1; attempt <= _kMaxAttempts; attempt++) {
      final ProcessResult r;
      try {
        r = await Process.run(
          toolchain.pql,
          args,
          workingDirectory: workDir.path,
        );
      } on ProcessException catch (e) {
        throw PqlException(
          'pql ${args.first}: ${e.message}',
          exitCode: e.errorCode,
          stderr: e.toString(),
        );
      }
      final stderr = (r.stderr as String).trim();
      // pql 1.5+ returns exit 0 with an empty `[]` for zero matches, so any
      // non-zero exit is a real error (older pql used exit 2 for empty).
      if (r.exitCode != 0) {
        // A transient db-busy / still-settling failure — a sidebar pane firing
        // its one-shot fetch too early at startup, or contention from
        // concurrent pql writes — would otherwise stick until a manual refresh.
        // Retry a few times with short backoff first. Genuine errors aren't
        // busy, so they still surface immediately. (T-350)
        if (attempt < _kMaxAttempts && _isTransient(r.exitCode, stderr)) {
          await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
          continue;
        }
        throw PqlException(
          'pql ${args.first} failed',
          exitCode: r.exitCode,
          stderr: stderr,
        );
      }
      final stdout = (r.stdout as String).trim();
      if (stdout.isEmpty) return null;
      return jsonDecode(stdout);
    }
    // Unreachable: the loop returns, continues, or throws on the final attempt.
    throw StateError('pql retry loop exhausted without a result');
  }

  /// Whether a non-zero pql exit looks like a transient db-busy / not-yet-ready
  /// condition worth retrying, vs. a genuine error to surface immediately.
  static bool _isTransient(int exitCode, String stderr) {
    if (exitCode == _kBusyExitCode) return true;
    final s = stderr.toLowerCase();
    return s.contains('database is locked') || s.contains('db busy') || s.contains('database busy') || s.contains('locked');
  }
}
