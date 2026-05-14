/// Drives every pql.* daemon handler with a PqlClient whose toolchain
/// points at a non-existent binary. Each underlying call throws
/// PqlException, exercising the catch branches in
/// `lib/src/daemon/pql_commands.dart` that the happy-path suite can't
/// reach.
library;

import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/toolchain.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/pql/client.dart';
import 'package:test/test.dart';

void main() {
  late DaemonDispatcher dispatcher;

  setUp(() {
    final toolchain = Toolchain();
    toolchain.applyResolved(const ResolvedPaths(pql: '/tmp/clide-no-such-pql-binary'));
    final pql = PqlClient(workDir: Directory.current, toolchain: toolchain);
    dispatcher = DaemonDispatcher();
    registerPqlCommands(dispatcher, pql);
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  // Each pql.* command, when the underlying binary is missing, should
  // surface a toolError with the pql operation name in the message.
  final commandsWithSimpleArgs = [
    ('pql.files', const <String, Object?>{}),
    ('pql.meta', const {'path': 'CLAUDE.md'}),
    ('pql.backlinks', const {'path': 'CLAUDE.md'}),
    ('pql.outlinks', const {'path': 'CLAUDE.md'}),
    ('pql.tags', const <String, Object?>{}),
    ('pql.schema', const <String, Object?>{}),
    ('pql.query', const {'query': 'SELECT name'}),
    ('pql.search', const {'terms': 'clide'}),
    ('pql.doctor', const <String, Object?>{}),
    ('pql.decisions.sync', const <String, Object?>{}),
    ('pql.decisions.list', const <String, Object?>{}),
    ('pql.decisions.read', const {'id': 'D-1'}),
    ('pql.decisions.show', const {'id': 'D-1'}),
    ('pql.tickets.list', const <String, Object?>{}),
    ('pql.tickets.show', const {'id': 'T-1'}),
    (
      'pql.tickets.status',
      const {
        'ids': ['T-1'],
        'status': 'done',
      }
    ),
    ('pql.tickets.board', const <String, Object?>{}),
    ('pql.plan.status', const <String, Object?>{}),
  ];

  for (final (cmd, args) in commandsWithSimpleArgs) {
    test('$cmd surfaces PqlException as a toolError', () async {
      final r = await call(cmd, args);
      expect(r.ok, isFalse, reason: cmd);
      expect(r.error?.kind, IpcErrorKind.toolError, reason: cmd);
    });
  }
}
