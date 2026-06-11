/// TerminalPane lifecycle tests.
///
/// T-366: disposing the pane must send `pane.close` for its backend
/// pane. The pre-fix code looked the kernel up from dispose() — an
/// illegal ancestor lookup whose throw was swallowed — so the close
/// was never sent and the backend PTY + daemon pane leaked.
library;

import 'package:clide/builtin/terminal/src/terminal_pane.dart';
import 'package:clide/clide.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture fixture;

  setUp(() async {
    fixture = await KernelFixture.create();
  });

  tearDown(() async {
    await fixture.dispose();
  });

  testWidgets('disposing the pane sends pane.close for the spawned pane', (tester) async {
    final closed = <String>[];
    fixture.ipc.setConnected(true);
    fixture.ipc.stub('pane.spawn', (args) async => IpcResponse.ok(id: 'r1', data: {'id': 'pane-7', 'pid': 4321}));
    fixture.ipc.stub('pane.close', (args) async {
      closed.add(args['id'] as String);
      return IpcResponse.ok(id: 'r2');
    });

    await tester.pumpWidget(harness(fixture, const TerminalPane()));
    // First pump runs the post-frame spawn; second flushes its await.
    await pumpAsync(tester);
    expect(find.textContaining('pane-7'), findsOneWidget, reason: 'spawn should complete and surface the pane id');

    // Tear the tree down — Overlay keeps its initialEntries across
    // rebuilds, so swapping the harness child would NOT dispose the
    // pane; unmounting the whole tree does. State.dispose() must fire
    // pane.close.
    await tester.pumpWidget(const SizedBox());
    await pumpAsync(tester);

    expect(closed, ['pane-7']);
  });

  testWidgets('disposing before spawn completes sends no close', (tester) async {
    final closed = <String>[];
    fixture.ipc.setConnected(false); // spawn bails out: no pane id
    fixture.ipc.stub('pane.close', (args) async {
      closed.add(args['id'] as String);
      return IpcResponse.ok(id: 'r1');
    });

    await tester.pumpWidget(harness(fixture, const TerminalPane()));
    await pumpAsync(tester);
    await tester.pumpWidget(const SizedBox());
    await pumpAsync(tester);

    expect(closed, isEmpty);
  });
}
