/// Tests for the `status` command verb (T-221). The snapshot *contents*
/// are assembled in main.dart from live kernel state (verified live); here
/// we cover the dispatch mechanics: the verb resolves (no longer exit 3),
/// returns the assembled map with exit 0, and is recomputed per request.
library;

import 'package:clide/clide.dart';
import 'package:clide/src/daemon/status_command.dart';
import 'package:test/test.dart';

void main() {
  IpcRequest req() => IpcRequest(id: '1', cmd: 'status', args: const {});

  test('status resolves and returns the assembled snapshot with exit 0', () async {
    final d = DaemonDispatcher();
    registerStatusCommand(d, () async => {'workspace': '/repo', 'focusedFile': null, 'panes': const []});
    final r = await d.dispatch(req());
    expect(r.ok, isTrue);
    expect(r.data['workspace'], '/repo');
    expect(r.data['panes'], isEmpty);
  });

  test('the snapshot is recomputed on every call (live, not cached)', () async {
    var n = 0;
    final d = DaemonDispatcher();
    registerStatusCommand(d, () async => {'n': ++n});
    expect((await d.dispatch(req())).data['n'], 1);
    expect((await d.dispatch(req())).data['n'], 2);
  });

  test('without registration, status is an unknown command (exit 3 / notFound)', () async {
    final d = DaemonDispatcher();
    final r = await d.dispatch(req());
    expect(r.ok, isFalse);
    expect(r.error?.kind, IpcErrorKind.notFound);
  });
}
