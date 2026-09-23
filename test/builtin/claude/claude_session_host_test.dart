/// Host-level behaviour for the Claude session tabs (T-269): an in-place
/// workspace switch (Open Project/Folder) must reset to a lone primary tab —
/// the previous repo's secondaries/forks don't belong in the new workspace.
///
/// The embedded [ClaudePane]s take the "daemon not connected" path under the
/// fake IPC, so no real `claude` process is spawned; this exercises the host's
/// tab bookkeeping in isolation.
library;

import 'dart:convert';

import 'package:clide/builtin/claude/src/claude_session_host.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_restore.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/update/self_update.dart' show startedByRelaunch;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

Widget _host(KernelFixture f, Key key, {bool Function(String root, String id)? transcriptExists}) => Directionality(
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
              initialEntries: [
                OverlayEntry(
                  builder: (_) => ClaudeSessionHost(key: key, transcriptExists: transcriptExists),
                ),
              ],
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

  testWidgets('tracks the active tab on the orchestrator (T-295)', (tester) async {
    final orch = ClaudeSessionOrchestrator(
      processFactory: ({required sessionArgs, required cwd, env}) async => throw UnsupportedError('no spawn in this test'),
    );
    activeSessionOrchestrator = orch;
    addTearDown(() {
      activeSessionOrchestrator = null;
      orch.dispose();
    });
    final key = GlobalKey<ClaudeSessionHostState>();
    await tester.pumpWidget(_host(f, key));
    await tester.pump();
    final state = key.currentState!;
    expect(orch.activeSessionId, 'primary');

    state.addSecondary(); // a new tab activates itself
    await tester.pump();
    expect(orch.activeSessionId, 'secondary-1');

    // Resolve the panes' "wait for project" so no timer outlives the tree.
    f.services.events.emit(const ProjectOpened(path: '/repo-a'));
    await tester.pump();
  });

  // T-589 / D-114: the secondary tabs are remembered per workspace and offered
  // back — or, after an update restart, brought straight back.
  group('restoring last time\'s sessions', () {
    const root = '/repo-a';
    const a = '11111111-1111-4111-8111-111111111111';
    const b = '22222222-2222-4222-8222-222222222222';
    const gone = '33333333-3333-4333-8333-333333333333';
    bool onDisk(String _, String id) => id != gone;

    Future<ClaudeSessionHostState> mountWith(WidgetTester tester, List<String> remembered) async {
      await tester.runAsync(() => f.services.settings.set<String>(SecondarySessionStore.keyFor(root), jsonEncode(remembered)));
      final key = GlobalKey<ClaudeSessionHostState>();
      await tester.pumpWidget(_host(f, key, transcriptExists: onDisk));
      await tester.pump();
      f.services.events.emit(const ProjectOpened(path: root));
      await tester.pump(); // the event lands
      await tester.pump(); // and its setState draws
      return key.currentState!;
    }

    /// Resolve the restored panes' "wait for project" timers (a re-open of the
    /// same path is not a switch), so none outlives the test.
    Future<void> settle(WidgetTester tester, [String path = root]) async {
      f.services.events.emit(ProjectOpened(path: path));
      await tester.pump();
      await tester.pump();
    }

    List<String> saved(String r) => SecondarySessionStore(f.services.settings, transcriptExists: (_, _) => true).restorable(r);

    tearDown(() => startedByRelaunch = false);

    testWidgets('offers the sessions whose transcripts survive; Restore reopens them in order', (tester) async {
      final state = await mountWith(tester, [a, gone, b]);
      expect(state.offeredSessions, [a, b], reason: 'a session without a transcript is dropped silently');
      expect(find.byKey(const Key('claude-restore-offer')), findsOneWidget);
      expect(state.tabIds, ['primary'], reason: 'nothing comes back unasked');

      await tester.tap(find.byKey(const Key('claude-restore-yes')));
      await tester.pump();
      expect(state.tabIds, ['primary', 'secondary-1', 'secondary-2']);
      expect(find.byKey(const Key('claude-restore-offer')), findsNothing);
      expect(saved(root), [a, b], reason: 'the restored tabs are remembered as they are');
      await settle(tester);
    });

    testWidgets('Not now leaves the tabs alone and forgets nothing', (tester) async {
      final state = await mountWith(tester, [a, b]);
      await tester.tap(find.byKey(const Key('claude-restore-no')));
      await tester.pump();
      expect(state.tabIds, ['primary']);
      expect(find.byKey(const Key('claude-restore-offer')), findsNothing);
      expect(saved(root), [a, b], reason: 'still there for the palette command / `clide claude restore`');
      expect(state.restoreSessions(saved(root)), 2);
      await tester.pump();
      expect(state.tabIds, hasLength(3));
      await settle(tester);
    });

    testWidgets('a window an update restarted gets them back without being asked', (tester) async {
      startedByRelaunch = true;
      final state = await mountWith(tester, [a, b]);
      expect(state.tabIds, ['primary', 'secondary-1', 'secondary-2']);
      expect(state.offeredSessions, isEmpty);
      expect(find.byKey(const Key('claude-restore-offer')), findsNothing);
      await settle(tester);
    });

    testWidgets('restoring twice never duplicates a session', (tester) async {
      final state = await mountWith(tester, [a]);
      expect(state.restoreSessions(), 1);
      await tester.pump();
      expect(state.restoreSessions([a]), 0);
      await settle(tester);
    });

    testWidgets('switching workspace keeps the old list and offers the new one', (tester) async {
      await tester.runAsync(() => f.services.settings.set<String>(SecondarySessionStore.keyFor('/repo-b'), jsonEncode([b])));
      final state = await mountWith(tester, [a]);
      state.restoreSessions();
      await tester.pump();
      f.services.events.emit(const ProjectOpened(path: '/repo-b'));
      await tester.pump();
      await tester.pump();
      expect(state.tabIds, ['primary']);
      expect(saved(root), [a], reason: 'the switch is not the user closing tabs');
      expect(state.offeredSessions, [b]);
      await settle(tester, '/repo-b');
    });
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
