/// pql CLI wrapper — shells out per D-003 (wrap, don't duplicate).
///
/// Every function runs `pql <subcommand>` as a subprocess, parses
/// the JSON stdout, and returns typed Dart maps. Errors surface as
/// [PqlException] with the stderr diagnostics attached.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class PqlException implements Exception {
  const PqlException(this.message, {this.exitCode = 1, this.stderr = ''});
  final String message;
  final int exitCode;
  final String stderr;

  @override
  String toString() => 'PqlException($exitCode): $message';
}

class PqlClient {
  PqlClient({required this.workDir, this.pqlBinary = 'pql'});

  final Directory workDir;
  final String pqlBinary;

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

  Future<List<Map<String, Object?>>> decisionCoverage() async {
    return _runList(['decisions', 'coverage']);
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
    bool withDecision = false,
    bool withBlockers = false,
  }) async {
    final args = ['ticket', 'show', id];
    if (withDecision) args.add('--with-decision');
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

  Future<Object?> _run(List<String> args) async {
    final r = await Process.run(
      pqlBinary,
      args,
      workingDirectory: workDir.path,
    );
    final stderr = (r.stderr as String).trim();
    // Exit 2 = zero matches — valid empty result, not an error.
    if (r.exitCode != 0 && r.exitCode != 2) {
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
}
