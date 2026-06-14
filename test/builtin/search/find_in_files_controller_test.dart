/// Unit tests for [FindInFilesController] — query state, streamed match
/// accumulation, grouping, stale-id filtering, cancel, and open (T-52).
library;

import 'package:clide/builtin/search/src/find_in_files_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/search/match.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

void main() {
  late KernelFixture f;
  FindInFilesController? ctrl;

  setUp(() async {
    f = await KernelFixture.create();
    f.ipc.stub('search.grep', (_) async => _ok({'searchId': 's1'}));
    f.ipc.stub('search.cancel', (_) async => _ok(const {}));
    f.ipc.stub('editor.open', (_) async => _ok(const {}));
  });
  tearDown(() async {
    ctrl?.dispose();
    ctrl = null;
    await f.dispose();
  });

  FindInFilesController make() => ctrl = FindInFilesController(ipc: f.ipc, events: f.services.events);

  void emitMatch(String id, List<Map<String, Object?>> matches) {
    f.services.events.emit(DaemonEvent(subsystem: 'search', kind: 'search.match', data: {'searchId': id, 'matches': matches}, ts: DateTime.now().toUtc()));
  }

  Map<String, Object?> m(String path, int line) => {'path': path, 'line': line, 'matchStart': 0, 'matchEnd': 3, 'preview': 'foo bar'};

  test('run sends search.grep with the current options and sets running', () async {
    Map<String, Object?>? sent;
    f.ipc.stub('search.grep', (args) async {
      sent = args;
      return _ok({'searchId': 's1'});
    });
    final c = make()
      ..setRegex(true)
      ..setIgnoreCase(true);
    c.include = '*.dart';
    await c.run('foo');
    expect(sent!['pattern'], 'foo');
    expect(sent!['regex'], isTrue);
    expect(sent!['ignoreCase'], isTrue);
    expect(sent!['include'], ['*.dart']);
  });

  test('empty pattern clears without dispatching a search', () async {
    var called = false;
    f.ipc.stub('search.grep', (_) async {
      called = true;
      return _ok({'searchId': 's1'});
    });
    final c = make();
    await c.run('   ');
    expect(called, isFalse);
    expect(c.running, isFalse);
  });

  test('streamed matches accumulate and group by file', () async {
    final c = make();
    await c.run('foo');
    emitMatch('s1', [m('a.dart', 1), m('a.dart', 5), m('b.dart', 2)]);
    await pumpEventQueue();
    expect(c.matchCount, 3);
    final g = c.grouped();
    expect(g.keys, containsAll(['a.dart', 'b.dart']));
    expect(g['a.dart'], hasLength(2));
    expect(c.fileCount, 2);
  });

  test('matches from a stale search id are ignored', () async {
    final c = make();
    await c.run('foo'); // activeSearchId == s1
    emitMatch('OLD', [m('z.dart', 9)]);
    await pumpEventQueue();
    expect(c.matchCount, 0);
  });

  test('search.done clears running', () async {
    final c = make();
    await c.run('foo');
    f.services.events.emit(
      DaemonEvent(subsystem: 'search', kind: 'search.done', data: const {'searchId': 's1', 'cancelled': false}, ts: DateTime.now().toUtc()),
    );
    await pumpEventQueue();
    expect(c.running, isFalse);
    expect(c.done, isTrue);
  });

  test('search.error surfaces the message', () async {
    final c = make();
    await c.run('(bad');
    f.services.events.emit(
      DaemonEvent(subsystem: 'search', kind: 'search.error', data: const {'searchId': 's1', 'message': 'invalid regex: x'}, ts: DateTime.now().toUtc()),
    );
    await pumpEventQueue();
    expect(c.error, contains('invalid regex'));
    expect(c.running, isFalse);
  });

  test('re-running clears prior results', () async {
    final c = make();
    await c.run('foo');
    emitMatch('s1', [m('a.dart', 1)]);
    await pumpEventQueue();
    expect(c.matchCount, 1);
    await c.run('bar');
    expect(c.matchCount, 0); // cleared on new run
  });

  test('openMatch issues editor.open with the line', () async {
    Map<String, Object?>? sent;
    f.ipc.stub('editor.open', (args) async {
      sent = args;
      return _ok(const {});
    });
    final c = make();
    c.openMatch(const SearchMatch(path: 'a.dart', line: 7, matchStart: 0, matchEnd: 3, preview: 'foo'));
    await pumpEventQueue();
    expect(sent!['path'], 'a.dart');
    expect(sent!['line'], 7);
  });

  test('cancel stops running', () async {
    final c = make();
    await c.run('foo');
    expect(c.running, isTrue);
    c.cancel();
    expect(c.running, isFalse);
  });

  test('a failed search.grep surfaces the error', () async {
    f.ipc.stub(
      'search.grep',
      (_) async => IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: 'nope'),
      ),
    );
    final c = make();
    await c.run('foo');
    expect(c.error, 'nope');
    expect(c.running, isFalse);
  });

  test('exclude setter feeds the next search', () async {
    Map<String, Object?>? sent;
    f.ipc.stub('search.grep', (args) async {
      sent = args;
      return _ok({'searchId': 's1'});
    });
    final c = make();
    c.exclude = 'build/** , *.g.dart';
    await c.run('foo');
    expect(sent!['exclude'], ['build/**', '*.g.dart']);
  });

  test('setReplacement updates the field and notifies', () {
    final c = make();
    var n = 0;
    c.addListener(() => n++);
    c.setReplacement('baz');
    expect(c.replacement, 'baz');
    expect(n, 1);
    c.setReplacement('baz'); // no change
    expect(n, 1);
  });

  test('isWorkingTreeClean reflects git.status clean flag', () async {
    f.ipc.stub('git.status', (_) async => _ok(const {'clean': true}));
    expect(await make().isWorkingTreeClean(), isTrue);
    f.ipc.stub('git.status', (_) async => _ok(const {'clean': false}));
    expect(await make().isWorkingTreeClean(), isFalse);
  });

  test('applyReplace sends apply, returns the summary, and refreshes', () async {
    Map<String, Object?>? sent;
    var grepCalls = 0;
    f.ipc.stub('search.replace', (args) async {
      sent = args;
      return _ok(const {'apply': true, 'filesChanged': 3, 'totalCount': 7});
    });
    f.ipc.stub('search.grep', (_) async {
      grepCalls++;
      return _ok({'searchId': 's1'});
    });
    final c = make();
    c.setReplacement('baz');
    await c.run('foo'); // grepCalls == 1
    final res = await c.applyReplace();
    expect(sent!['apply'], isTrue);
    expect(sent!['replacement'], 'baz');
    expect(res.files, 3);
    expect(res.count, 7);
    expect(grepCalls, 2); // applyReplace re-runs the search
  });
}
