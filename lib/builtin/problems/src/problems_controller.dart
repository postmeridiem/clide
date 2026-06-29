/// State model for the problems panel.
///
/// Aggregates diagnostic information from pql.doctor and
/// pql.decisions.validate (via pql.decisions.sync which reports
/// broken refs). Refreshes on demand.
library;

import 'dart:async';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/env/supporter_binaries.dart';
import 'package:flutter/foundation.dart';

class Problem {
  const Problem({required this.source, required this.message, this.hint});
  final String source;
  final String message;
  final String? hint;

  Map<String, Object?> toJson() => {'source': source, 'message': message, if (hint != null) 'hint': hint};
}

class ProblemsController extends ChangeNotifier {
  ProblemsController({required this.ipc});

  final DaemonClient ipc;

  List<Problem> _problems = const [];
  List<Problem> get problems => _problems;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    final found = <Problem>[];

    final doctor = await ipc.request('pql.doctor');
    if (doctor.ok) {
      final db = (doctor.data['db'] as Map?)?.cast<String, Object?>();
      if (db != null && db['exists'] == false) {
        found.add(const Problem(source: 'pql', message: 'pql index database not found', hint: 'Run pql to build the index.'));
      }
      final skill = (doctor.data['skill'] as Map?)?.cast<String, Object?>();
      if (skill != null) {
        final project = (skill['project'] as Map?)?.cast<String, Object?>();
        if (project != null) {
          final state = project['state'] as String?;
          if (state == 'stale') {
            found.add(const Problem(source: 'pql', message: 'pql skill is stale — newer version available', hint: 'Run: pql skill install'));
          } else if (state == 'missing') {
            found.add(const Problem(source: 'pql', message: 'pql skill not installed', hint: 'Run: pql init --with-skill=yes'));
          }
        }
      }
    } else {
      found.add(Problem(source: 'pql', message: 'pql doctor failed', hint: doctor.error?.message));
    }

    final sync = await ipc.request('pql.decisions.sync');
    if (sync.ok) {
      final broken = (sync.data['broken'] as num?)?.toInt() ?? 0;
      if (broken > 0) {
        found.add(Problem(source: 'decisions', message: '$broken broken cross-reference(s) in governance/', hint: 'Run: pql decisions validate'));
      }
    }

    found.addAll(supporterToolProblems(activeSupporterBinaries));

    _loading = false;
    _error = null;
    _problems = found;
    notifyListeners();
  }
}

/// Problems for STALE supporter-binary pins (T-495 / D-104): an explicit tool
/// path that no longer points at a file — a real misconfig (a tool moved on an
/// upgrade). A merely-unfound optional tool isn't flagged; its use-time
/// userError covers that. Pure + testable.
List<Problem> supporterToolProblems(SupporterBinaries? tools) {
  if (tools == null) return const [];
  return [
    for (final name in knownSupporterTools)
      if (tools.isStalePin(name))
        Problem(source: 'tools', message: 'configured path for "$name" is missing', hint: 'Re-detect, or update its path in settings (app.tools).'),
  ];
}
