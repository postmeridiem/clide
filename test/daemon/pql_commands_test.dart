import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/src/toolchain_paths.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:test/test.dart';

void main() {
  late DaemonDispatcher dispatcher;
  late PqlClient pql;

  setUp(() {
    final toolchain = ToolchainView.resolved(resolveToolchainPaths());
    pql = PqlClient(workDir: Directory.current, toolchain: toolchain);
    dispatcher = DaemonDispatcher();
    registerPqlCommands(dispatcher, pql);
  });

  Future<IpcResponse> call(String cmd, [Map<String, Object?> args = const {}]) {
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
    final r = await call('pql.decisions.show', {'id': 'D-1'});
    expect(r.ok, isTrue);
    expect(r.data['id'], 'D-1');
    expect(r.data['title'], isNotEmpty);
  });

  test('pql.decisions.show without id returns error', () async {
    final r = await call('pql.decisions.show');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
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

  test('pql.files with glob + limit narrows the result', () async {
    final r = await call('pql.files', {'glob': 'CLAUDE.md', 'limit': 1});
    expect(r.ok, isTrue);
    final files = r.data['files'] as List;
    expect(files.length, lessThanOrEqualTo(1));
  });

  test('pql.backlinks with a path returns links list', () async {
    final r = await call('pql.backlinks', {'path': 'CLAUDE.md'});
    expect(r.ok, isTrue);
    expect(r.data['links'], isA<List>());
  });

  test('pql.outlinks without path returns user_error', () async {
    final r = await call('pql.outlinks');
    expect(r.ok, isFalse);
    expect(r.error!.kind, 'user_error');
  });

  test('pql.tags returns a tag list (with limit)', () async {
    final r = await call('pql.tags', {'limit': 5});
    expect(r.ok, isTrue);
    expect(r.data['tags'], isA<List>());
  });

  test('pql.query with a DSL string returns results', () async {
    final r = await call('pql.query', {'query': 'SELECT name', 'limit': 2});
    expect(r.ok, isTrue);
    expect(r.data['results'], isA<List>());
  });

  test('pql.search with terms returns hits; missing terms is user_error', () async {
    final missing = await call('pql.search');
    expect(missing.ok, isFalse);
    expect(missing.error!.kind, 'user_error');
    final hit = await call('pql.search', {'terms': 'clide', 'limit': 2});
    expect(hit.ok, isTrue);
  });

  test('pql.decisions.read requires id; happy path returns the body', () async {
    final missing = await call('pql.decisions.read');
    expect(missing.ok, isFalse);
    expect(missing.error!.kind, 'user_error');
    final ok = await call('pql.decisions.read', {'id': 'D-1'});
    expect(ok.ok, isTrue);
    expect(ok.data['id'], 'D-1');
  });

  test('pql.decisions.show forwards withRefs / withTickets', () async {
    final r = await call('pql.decisions.show', {
      'id': 'D-1',
      'withRefs': true,
      'withTickets': true,
    });
    expect(r.ok, isTrue);
    expect(r.data['id'], 'D-1');
  });

  test('pql.decisions.list with a domain filter narrows', () async {
    final r = await call('pql.decisions.list', {'domain': 'architecture'});
    expect(r.ok, isTrue);
    final decisions = r.data['decisions'] as List;
    expect(decisions.every((d) => (d as Map)['domain'] == 'architecture'), isTrue);
  });

  test('pql.tickets.list with filters narrows + shows status', () async {
    final r = await call('pql.tickets.list', {
      'status': 'done',
      'team': 'whatever',
      'assigned': 'no-one',
      'decision': 'D-1',
    });
    expect(r.ok, isTrue);
    expect(r.data['tickets'], isA<List>());
  });

  test('pql.tickets.show requires id; happy path returns the row', () async {
    final missing = await call('pql.tickets.show');
    expect(missing.ok, isFalse);
    expect(missing.error!.kind, 'user_error');
    final ok = await call('pql.tickets.show', {
      'id': 'T-1',
      'withContext': true,
      'withBlockers': true,
    });
    expect(ok.ok, isTrue);
  });

  test('pql.tickets.status requires ids + status', () async {
    final missing = await call('pql.tickets.status');
    expect(missing.ok, isFalse);
    expect(missing.error!.kind, 'user_error');
    // Accept both List and String for ids.
    final justOne = await call('pql.tickets.status', {'ids': 'T-1'});
    expect(justOne.ok, isFalse); // status still missing
    expect(justOne.error!.kind, 'user_error');
  });

  test('pql.tickets.board with team filter', () async {
    final r = await call('pql.tickets.board', {'team': 'whatever'});
    expect(r.ok, isTrue);
    expect(r.data['columns'], isA<List>());
  });
}
