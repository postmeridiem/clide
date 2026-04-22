/// State model for the pql sidebar panel.
///
/// Manages schema cache, query execution, file listing, and
/// decision/ticket views. All data comes through pql.* IPC verbs.
library;

import 'dart:async';

import 'package:clide_app/kernel/kernel.dart';
import 'package:flutter/foundation.dart';

enum PqlView { files, query, decisions, tickets }

class PqlController extends ChangeNotifier {
  PqlController({required this.ipc});

  final DaemonClient ipc;

  PqlView _view = PqlView.files;
  PqlView get view => _view;

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  List<Map<String, Object?>> _results = const [];
  List<Map<String, Object?>> get results => _results;

  Map<String, Object?> _planStatus = const {};
  Map<String, Object?> get planStatus => _planStatus;

  void switchView(PqlView v) {
    if (_view == v) return;
    _view = v;
    _results = const [];
    _error = null;
    notifyListeners();
    switch (v) {
      case PqlView.files:
        unawaited(loadFiles());
      case PqlView.decisions:
        unawaited(loadDecisions());
      case PqlView.tickets:
        unawaited(loadTickets());
      case PqlView.query:
        break;
    }
  }

  Future<void> loadFiles({String? glob}) async {
    _loading = true;
    notifyListeners();

    final r = await ipc.request('pql.files', args: {
      if (glob != null) 'glob': glob,
      'limit': 200,
    });

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return;
    }
    _error = null;
    _results = _castList(r.data['files']);
    notifyListeners();
  }

  Future<void> runQuery(String dsl) async {
    if (dsl.trim().isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final r = await ipc.request('pql.query', args: {
      'query': dsl,
      'limit': 200,
    });

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message;
      _results = const [];
      notifyListeners();
      return;
    }
    _results = _castList(r.data['results']);
    notifyListeners();
  }

  Future<void> loadDecisions() async {
    _loading = true;
    notifyListeners();

    await ipc.request('pql.decisions.sync');
    final r = await ipc.request('pql.decisions.list');

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return;
    }
    _error = null;
    _results = _castList(r.data['decisions']);
    notifyListeners();
  }

  Future<void> loadTickets() async {
    _loading = true;
    notifyListeners();

    final r = await ipc.request('pql.tickets.board');

    _loading = false;
    if (!r.ok) {
      _error = r.error?.message;
      notifyListeners();
      return;
    }
    _error = null;
    _results = _castList(r.data['columns']);
    notifyListeners();
  }

  Future<void> loadPlanStatus() async {
    final r = await ipc.request('pql.plan.status');
    if (r.ok) {
      _planStatus = r.data;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  static List<Map<String, Object?>> _castList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) (e as Map).cast<String, Object?>()];
  }
}
