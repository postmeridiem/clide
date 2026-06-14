/// Unit tests for [PqlController] — search, DSL query, markdown listing,
/// view/mode switching, and error handling. Previously untested; brought
/// under test when the pql search surface merged into the Search tab
/// (T-201).
library;

import 'package:clide/builtin/pql/src/pql_controller.dart';
import 'package:clide/clide.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);
IpcResponse _err(String m) => IpcResponse.err(
  id: '',
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: m),
);

void main() {
  late KernelFixture f;
  late PqlController c;

  setUp(() async {
    f = await KernelFixture.create();
    c = PqlController(ipc: f.ipc);
  });
  tearDown(() async {
    c.dispose();
    await f.dispose();
  });

  test('defaults to query view + search mode', () {
    expect(c.view, PqlView.query);
    expect(c.searchMode, SearchMode.search);
    expect(c.results, isEmpty);
  });

  test('search with empty terms clears without an IPC call', () async {
    var called = false;
    f.ipc.stub('pql.search', (_) async {
      called = true;
      return _ok(const {'results': []});
    });
    await c.search('   ');
    expect(called, isFalse);
    expect(c.results, isEmpty);
  });

  test('search populates ranked results', () async {
    f.ipc.stub(
      'pql.search',
      (args) async => _ok({
        'results': [
          {'path': 'a.md', 'score': 0.8},
        ],
      }),
    );
    await c.search('term');
    expect(c.results.single['path'], 'a.md');
    expect(c.error, isNull);
  });

  test('search surfaces an error', () async {
    f.ipc.stub('pql.search', (_) async => _err('boom'));
    await c.search('term');
    expect(c.error, 'boom');
    expect(c.results, isEmpty);
  });

  test('runQuery ignores empty input', () async {
    var called = false;
    f.ipc.stub('pql.query', (_) async {
      called = true;
      return _ok(const {'results': []});
    });
    await c.runQuery('  ');
    expect(called, isFalse);
  });

  test('runQuery populates rows; error surfaces', () async {
    f.ipc.stub(
      'pql.query',
      (args) async => _ok({
        'results': [
          {'name': 'T-1'},
        ],
      }),
    );
    await c.runQuery("type = 'ticket'");
    expect(c.results.single['name'], 'T-1');

    f.ipc.stub('pql.query', (_) async => _err('bad dsl'));
    await c.runQuery('nope');
    expect(c.error, 'bad dsl');
    expect(c.results, isEmpty);
  });

  test('loadMarkdownFiles populates + errors', () async {
    f.ipc.stub(
      'pql.files',
      (args) async => _ok({
        'files': [
          {'path': 'docs/x.md'},
        ],
      }),
    );
    await c.loadMarkdownFiles();
    expect(c.results.single['path'], 'docs/x.md');

    f.ipc.stub('pql.files', (_) async => _err('no fs'));
    await c.loadMarkdownFiles();
    expect(c.error, 'no fs');
  });

  test('switchView(markdown) changes view and auto-loads', () async {
    var filesCalls = 0;
    f.ipc.stub('pql.files', (_) async {
      filesCalls++;
      return _ok(const {'files': []});
    });
    c.switchView(PqlView.markdown);
    expect(c.view, PqlView.markdown);
    await pumpEventQueue();
    expect(filesCalls, 1);
    // Switching to the same view is a no-op.
    c.switchView(PqlView.markdown);
    expect(filesCalls, 1);
  });

  test('setSearchMode + toggleSearchMode flip the mode and clear results', () async {
    f.ipc.stub(
      'pql.search',
      (_) async => _ok({
        'results': [
          {'path': 'a.md', 'score': 0.5},
        ],
      }),
    );
    await c.search('x');
    expect(c.results, isNotEmpty);
    c.setSearchMode(SearchMode.dsl);
    expect(c.searchMode, SearchMode.dsl);
    expect(c.results, isEmpty);
    c.toggleSearchMode();
    expect(c.searchMode, SearchMode.search);
    c.setSearchMode(SearchMode.search); // no-op when unchanged
    expect(c.searchMode, SearchMode.search);
  });

  test('clearError clears a set error', () async {
    f.ipc.stub('pql.search', (_) async => _err('e'));
    await c.search('x');
    expect(c.error, 'e');
    c.clearError();
    expect(c.error, isNull);
    c.clearError(); // no-op
    expect(c.error, isNull);
  });

  test('loadPlanStatus stores the status payload', () async {
    f.ipc.stub('pql.plan.status', (_) async => _ok(const {'tickets': 5}));
    await c.loadPlanStatus();
    expect(c.planStatus['tickets'], 5);
  });
}
