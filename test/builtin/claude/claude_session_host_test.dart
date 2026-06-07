/// Host-level behaviour for the Claude session tabs (T-269): an in-place
/// workspace switch (Open Project/Folder) must reset to a lone primary tab —
/// the previous repo's secondaries/forks don't belong in the new workspace.
///
/// The embedded [ClaudePane]s take the "daemon not connected" path under the
/// fake IPC, so no real `claude` process is spawned; this exercises the host's
/// tab bookkeeping in isolation.
library;

import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

Widget _host(KernelFixture f, Key key) => Directionality(
      textDirection: TextDirection.ltr,
      child: ClideKernel(
        services: f.services,
        child: ClideTheme(
          controller: f.services.theme,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                // Bounded size so the reorderable tab strip's Draggable has a
                // real width and the Overlay below isn't asked to self-size.
                width: 800,
                height: 600,
                child: Overlay(
                  initialEntries: [OverlayEntry(builder: (_) => ClaudeSessionHost(key: key))],
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('in-place workspace switch drops secondaries, keeps primary (T-269)', (tester) async {
    final key = GlobalKey<ClaudeSessionHostState>();
    await tester.pumpWidget(_host(f, key));
    await tester.pump();
    final state = key.currentState!;

    state.addSecondary();
    state.addSecondary();
    await tester.pump();
    expect(state.tabIds, ['primary', 'secondary-1', 'secondary-2']);

    // Establish the baseline workspace; the first ProjectOpened is the initial
    // open, not a switch, so it must NOT reset anything. (It also resolves each
    // pane's "wait for project" so no spawn timer outlives the widget tree.)
    f.services.events.emit(const ProjectOpened(path: '/repo-a'));
    await tester.pump();
    expect(state.tabIds, ['primary', 'secondary-1', 'secondary-2']);

    // Switch to a different repo in place → back to just the primary.
    f.services.events.emit(const ProjectOpened(path: '/repo-b'));
    await tester.pump();
    expect(state.tabIds, ['primary']);

    // The secondary counter resets, so the next secondary is index 1 again.
    // The redundant /repo-b emit resolves the new pane's wait without a reset.
    state.addSecondary();
    f.services.events.emit(const ProjectOpened(path: '/repo-b'));
    await tester.pump();
    expect(state.tabIds, ['primary', 'secondary-1']);
  });

  testWidgets('re-opening the same workspace is not a switch (no reset) (T-269)', (tester) async {
    final key = GlobalKey<ClaudeSessionHostState>();
    await tester.pumpWidget(_host(f, key));
    await tester.pump();
    final state = key.currentState!;

    f.services.events.emit(const ProjectOpened(path: '/repo-a'));
    await tester.pump();
    state.addSecondary();
    await tester.pump();

    // Same path again — a redundant re-open must keep the secondary.
    f.services.events.emit(const ProjectOpened(path: '/repo-a'));
    await tester.pump();
    expect(state.tabIds, ['primary', 'secondary-1']);
  });
}
