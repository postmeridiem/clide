/// Tests DiffController's load + focus behaviour (T-233): loading hydrates the
/// diff list and clears stale focus; focus() records a path, notifies, and
/// reloads; git.changed refreshes.
library;

import 'package:clide/builtin/diff/src/diff_controller.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ipc.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

Map<String, Object?> _file(String path) => {'path': path, 'hunks': const []};

void main() {
  late DaemonBus bus;
  late FakeDaemonClient ipc;
  late DiffController c;
  late int diffCalls;

  setUp(() {
    bus = DaemonBus();
    ipc = FakeDaemonClient(log: Logger(), events: bus);
    diffCalls = 0;
    ipc.stub('git.diff', (_) async {
      diffCalls++;
      return _ok({
        'diffs': [_file('lib/a.dart'), _file('lib/b.dart')],
      });
    });
    c = DiffController(ipc: ipc, events: bus);
  });

  tearDown(() async {
    c.dispose();
    await bus.dispose();
  });

  test('load hydrates the diff list', () async {
    await c.load();
    expect(c.diffs.map((d) => d['path']), ['lib/a.dart', 'lib/b.dart']);
    expect(c.error, isNull);
  });

  test('focus records the path, notifies, and reloads', () async {
    await c.load();
    final before = diffCalls;
    var notified = 0;
    c.addListener(() => notified++);

    c.focus('lib/b.dart');
    expect(c.focusPath, 'lib/b.dart');
    expect(notified, greaterThan(0));
    // focus() reloads so the latest edits to that file are present.
    await pumpEventQueue();
    expect(diffCalls, greaterThan(before));
  });

  test('a focus whose file leaves the diff is dropped on reload', () async {
    c.focus('lib/gone.dart');
    expect(c.focusPath, 'lib/gone.dart');
    // The reload triggered by focus() returns a list without that file.
    await pumpEventQueue();
    expect(c.focusPath, isNull);
  });

  test('a focus that stays in the diff survives reload', () async {
    c.focus('lib/a.dart');
    await pumpEventQueue();
    expect(c.focusPath, 'lib/a.dart');
  });

  test('git.changed refreshes the diff', () async {
    await c.load();
    final before = diffCalls;
    bus.emit(DaemonEvent(subsystem: 'git', kind: 'git.changed', data: const {}, ts: DateTime.now().toUtc()));
    await pumpEventQueue();
    expect(diffCalls, greaterThan(before));
  });

  test('a git.diff error surfaces on the controller', () async {
    ipc.stub(
      'git.diff',
      (_) async => IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'boom'),
      ),
    );
    await c.load();
    expect(c.error, 'boom');
  });
}
