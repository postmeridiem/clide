/// Registers `pql.*` command handlers on the daemon dispatcher.
///
/// Thin pass-through to [PqlClient] — the daemon is a JSON relay
/// between the IPC socket and the pql CLI. Per D-003, clide wraps
/// pql; it never re-implements.
library;

import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../pql/client.dart';
import 'dispatcher.dart';

void registerPqlCommands(DaemonDispatcher d, PqlClient pql) {
  d.register('pql.files', (req) async {
    try {
      final glob = req.args['glob'] as String?;
      final limit = (req.args['limit'] as num?)?.toInt();
      final files = await pql.files(glob: glob, limit: limit);
      return IpcResponse.ok(id: req.id, data: {'files': files});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.meta', (req) async {
    final path = req.args['path'] as String?;
    if (path == null || path.isEmpty) {
      return _userError(req.id, 'pql.meta requires a path');
    }
    try {
      final meta = await pql.meta(path);
      return IpcResponse.ok(id: req.id, data: meta);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.backlinks', (req) async {
    final path = req.args['path'] as String?;
    if (path == null || path.isEmpty) {
      return _userError(req.id, 'pql.backlinks requires a path');
    }
    try {
      final links = await pql.backlinks(path);
      return IpcResponse.ok(id: req.id, data: {'links': links});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.outlinks', (req) async {
    final path = req.args['path'] as String?;
    if (path == null || path.isEmpty) {
      return _userError(req.id, 'pql.outlinks requires a path');
    }
    try {
      final links = await pql.outlinks(path);
      return IpcResponse.ok(id: req.id, data: {'links': links});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.tags', (req) async {
    try {
      final limit = (req.args['limit'] as num?)?.toInt();
      final tags = await pql.tags(limit: limit);
      return IpcResponse.ok(id: req.id, data: {'tags': tags});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.schema', (req) async {
    try {
      final schema = await pql.schema();
      return IpcResponse.ok(id: req.id, data: {'schema': schema});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.query', (req) async {
    final dsl = req.args['query'] as String?;
    if (dsl == null || dsl.isEmpty) {
      return _userError(req.id, 'pql.query requires a query string');
    }
    try {
      final limit = (req.args['limit'] as num?)?.toInt();
      final results = await pql.query(dsl, limit: limit);
      return IpcResponse.ok(id: req.id, data: {'results': results});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.search', (req) async {
    final terms = req.args['terms'] as String?;
    if (terms == null || terms.isEmpty) {
      return _userError(req.id, 'pql.search requires a terms string');
    }
    try {
      final limit = (req.args['limit'] as num?)?.toInt();
      final results = await pql.search(terms, limit: limit);
      return IpcResponse.ok(id: req.id, data: {'results': results});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.doctor', (req) async {
    try {
      final report = await pql.doctor();
      return IpcResponse.ok(id: req.id, data: report);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.decisions.sync', (req) async {
    try {
      final result = await pql.decisionSync();
      return IpcResponse.ok(id: req.id, data: result);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.decisions.list', (req) async {
    try {
      final results = await pql.decisionList(
        type: req.args['type'] as String?,
        domain: req.args['domain'] as String?,
        status: req.args['status'] as String?,
      );
      return IpcResponse.ok(id: req.id, data: {'decisions': results});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.decisions.read', (req) async {
    final id = req.args['id'] as String?;
    if (id == null || id.isEmpty) {
      return _userError(req.id, 'pql.decisions.read requires an id');
    }
    try {
      final result = await pql.decisionRead(id);
      return IpcResponse.ok(id: req.id, data: result);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.decisions.show', (req) async {
    final id = req.args['id'] as String?;
    if (id == null || id.isEmpty) {
      return _userError(req.id, 'pql.decisions.show requires an id');
    }
    try {
      final result = await pql.decisionShow(
        id,
        withRefs: req.args['withRefs'] as bool? ?? false,
        withTickets: req.args['withTickets'] as bool? ?? false,
      );
      return IpcResponse.ok(id: req.id, data: result);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.decisions.coverage', (req) async {
    try {
      final gaps = await pql.decisionCoverage();
      return IpcResponse.ok(id: req.id, data: {'gaps': gaps});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.tickets.list', (req) async {
    try {
      final results = await pql.ticketList(
        status: req.args['status'] as String?,
        team: req.args['team'] as String?,
        assigned: req.args['assigned'] as String?,
        decision: req.args['decision'] as String?,
      );
      return IpcResponse.ok(id: req.id, data: {'tickets': results});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.tickets.show', (req) async {
    final id = req.args['id'] as String?;
    if (id == null || id.isEmpty) {
      return _userError(req.id, 'pql.tickets.show requires an id');
    }
    try {
      final result = await pql.ticketShow(
        id,
        withContext: req.args['withContext'] as bool? ?? false,
        withBlockers: req.args['withBlockers'] as bool? ?? false,
      );
      return IpcResponse.ok(id: req.id, data: result);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.tickets.status', (req) async {
    final rawIds = req.args['ids'];
    final ids = rawIds is List ? rawIds.cast<String>() : rawIds is String ? [rawIds] : <String>[];
    final status = req.args['status'] as String?;
    if (ids.isEmpty || status == null || status.isEmpty) {
      return _userError(req.id, 'pql.tickets.status requires ids and status');
    }
    try {
      final result = await pql.ticketSetStatus(ids, status);
      return IpcResponse.ok(id: req.id, data: {'tickets': result});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.tickets.board', (req) async {
    try {
      final board = await pql.ticketBoard(
        team: req.args['team'] as String?,
      );
      return IpcResponse.ok(id: req.id, data: {'columns': board});
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });

  d.register('pql.plan.status', (req) async {
    try {
      final status = await pql.planStatus();
      return IpcResponse.ok(id: req.id, data: status);
    } on PqlException catch (e) {
      return _pqlError(req.id, e);
    }
  });
}

IpcResponse _userError(String id, String message) {
  return IpcResponse.err(
    id: id,
    error: IpcError(
      code: IpcExitCode.userError,
      kind: IpcErrorKind.userError,
      message: message,
    ),
  );
}

IpcResponse _pqlError(String id, PqlException e) {
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
