import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/toolchain.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/pql/client.dart';
import 'package:test/test.dart';

void main() {
  late DaemonDispatcher dispatcher;
  late PqlClient pql;

  setUp(() {
    final toolchain = Toolchain();
    toolchain.applyResolved(Toolchain.resolvePaths(workspaceRoot: Directory.current.path));
    pql = PqlClient(workDir: Directory.current, toolchain: toolchain);
    dispatcher = DaemonDispatcher();
    registerPqlCommands(dispatcher, pql);
  });

  Future<IpcResponse> call(String cmd,
      [Map<String, Object?> args = const {}]) {
    return dispatcher.dispatch(IpcRequest(id: '1', cmd: cmd, args: args));
  }

  test('pql.files returns a list of files', () async {
    final r = await call('pql.files', {'limit': 3});
    expect(r.ok, isTrue);
    final files = r.data['files'] as List;
    expect(files, isNotEmpty);
    expect(files.length, lessThanOrEqualTo(3));
    final first = (files.first as Map).cast<String, Object?>();
    expect(first.containsKey('path'), isTrue);
    expect(first.containsKey('name'), isTrue);
  });

  test('pql.meta returns file metadata', () async {
    final r = await call('pql.meta', {'path': 'CLAUDE.md'});
    expect(r.ok, isTrue);
    expect(r.data['path'], 'CLAUDE.md');
    expect(r.data.containsKey('outlinks'), isTrue);
  });

  test('pql.meta without path returns error', () async {
    final r = await call('pql.meta');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('pql.outlinks returns links from a file', () async {
    final r = await call('pql.outlinks', {'path': 'CLAUDE.md'});
    expect(r.ok, isTrue);
    final links = r.data['links'] as List;
    expect(links, isNotEmpty);
  });

  test('pql.schema returns the frontmatter schema', () async {
    final r = await call('pql.schema');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('schema'), isTrue);
  });

  test('pql.doctor returns diagnostic report', () async {
    final r = await call('pql.doctor');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('vault'), isTrue);
    expect(r.data.containsKey('config'), isTrue);
    expect(r.data.containsKey('version'), isTrue);
  });

  test('pql.decisions.sync parses decisions', () async {
    final r = await call('pql.decisions.sync');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('synced'), isTrue);
    expect((r.data['synced'] as num).toInt(), greaterThan(0));
  });

  test('pql.decisions.list returns confirmed decisions', () async {
    await call('pql.decisions.sync');
    final r = await call('pql.decisions.list', {'type': 'confirmed'});
    expect(r.ok, isTrue);
    final decisions = r.data['decisions'] as List;
    expect(decisions, isNotEmpty);
  });

  test('pql.decisions.show returns a single decision', () async {
    await call('pql.decisions.sync');
    final r = await call('pql.decisions.show', {'id': 'D-001'});
    expect(r.ok, isTrue);
    expect(r.data['id'], 'D-001');
    expect(r.data['title'], isNotEmpty);
  });

  test('pql.decisions.show without id returns error', () async {
    final r = await call('pql.decisions.show');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('pql.decisions.coverage returns gaps', () async {
    await call('pql.decisions.sync');
    final r = await call('pql.decisions.coverage');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('gaps'), isTrue);
  });

  test('pql.tickets.board returns columns', () async {
    final r = await call('pql.tickets.board');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('columns'), isTrue);
  });

  test('pql.plan.status returns dashboard', () async {
    await call('pql.decisions.sync');
    final r = await call('pql.plan.status');
    expect(r.ok, isTrue);
    expect(r.data.containsKey('decisions'), isTrue);
    expect(r.data.containsKey('tickets'), isTrue);
  });

  test('pql.query without query returns error', () async {
    final r = await call('pql.query');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('pql.backlinks without path returns error', () async {
    final r = await call('pql.backlinks');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });
}
