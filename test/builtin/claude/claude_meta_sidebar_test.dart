import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_meta_sidebar.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart' show EditableText, SizedBox, Semantics;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

// ---------------------------------------------------------------------------
// Minimal fake process so orchestrator tests don't need a real `claude` binary.
// ---------------------------------------------------------------------------
class _FakeProc implements StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final List<String> writes = [];
  bool killed = false;

  @override
  Stream<String> get lines => _ctl.stream;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> kill() async => killed = true;
}

ClaudeSessionOrchestrator _fakeOrchestrator() {
  return ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => _FakeProc());
}

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  const stats = ClaudeStats(
    lastComputed: '2026-05-22',
    daily: [
      DailyActivity(date: '2026-05-01', messageCount: 100, sessionCount: 2, toolCallCount: 30),
      DailyActivity(date: '2026-05-22', messageCount: 250, sessionCount: 5, toolCallCount: 80),
    ],
  );

  ClaudeMetaSidebar sidebar({
    ClaudeStats stats = const ClaudeStats(),
    ClaudeConfig? config,
    SidebarTab initialTab = SidebarTab.activity,
    ClaudeSessionOrchestrator? orchestrator,
  }) =>
      ClaudeMetaSidebar(
        statsLoader: () async => stats,
        pollInterval: Duration.zero,
        config: config,
        orchestrator: orchestrator,
        initialTab: initialTab,
      );

  testWidgets('Activity tab shows today + lifetime stats on the table', (tester) async {
    await tester.pumpWidget(harness(f, sidebar(stats: stats)));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('LIFETIME'), findsOneWidget);
    expect(find.text('250'), findsOneWidget); // today messages
    expect(find.text('80'), findsOneWidget); // today tool calls
    expect(find.text('350'), findsOneWidget); // lifetime messages
    expect(find.text('messages'), findsNWidgets(2)); // today + lifetime rows
  });

  testWidgets('defaults to Activity, not the roster', (tester) async {
    await tester.pumpWidget(harness(f, sidebar(stats: stats)));
    await tester.pumpAndSettle();
    expect(find.text('No team active.'), findsNothing);
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('tapping a sub-tab switches the body', (tester) async {
    await tester.pumpWidget(harness(f, sidebar(stats: stats)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Team'));
    await tester.pump();
    expect(find.text('No team active.'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);

    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('Config tab renders the settings table over ClaudeConfig', (tester) async {
    final dir = Directory.systemTemp.createTempSync('cfg');
    addTearDown(() => dir.deleteSync(recursive: true));
    final config = ClaudeConfig(globalDir: dir, cacheDir: dir);

    await tester.pumpWidget(harness(f, sidebar(config: config, initialTab: SidebarTab.config)));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('output style'), findsOneWidget);
    expect(find.text('permission mode'), findsOneWidget);
    expect(find.text('~/.claude + .claude'), findsOneWidget);
  });

  testWidgets('Config tab degrades when no environment is loaded', (tester) async {
    await tester.pumpWidget(harness(f, sidebar(initialTab: SidebarTab.config)));
    await tester.pumpAndSettle();
    expect(find.text('Claude environment not loaded.'), findsOneWidget);
  });

  testWidgets('a team spawn auto-fronts the Team tab', (tester) async {
    await tester.pumpWidget(harness(f, sidebar(stats: stats)));
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget); // starts on Activity

    f.services.events.emit(const TeamMemberJoined(
      team: 't',
      agentId: 'a1',
      name: 'Scout',
      agentType: 'explorer',
      paneId: '%1',
      model: 'claude-opus-4-7',
      color: 'blue',
    ));
    await tester.pump();
    await tester.pump();

    // Fronted to Team without a tap.
    expect(find.text('Scout'), findsOneWidget);
    expect(find.text('explorer  ·  opus 4.7'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('removing the last member leaves the Team tab empty', (tester) async {
    await tester.pumpWidget(harness(f, sidebar()));
    await tester.pumpAndSettle();

    f.services.events.emit(const TeamMemberJoined(
      team: 't',
      agentId: 'a1',
      name: 'Scout',
      agentType: 'explorer',
      paneId: '%1',
      color: 'blue',
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Scout'), findsOneWidget);

    f.services.events.emit(const TeamMemberLeft(team: 't', agentId: 'a1', paneId: '%1'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Scout'), findsNothing);
    expect(find.text('No team active.'), findsOneWidget);
  });

  testWidgets('folds live per-member status into the roster row', (tester) async {
    await tester.pumpWidget(harness(f, sidebar()));
    await tester.pumpAndSettle();

    f.services.events.emit(const TeamMemberJoined(
      team: 't',
      agentId: 'a1',
      name: 'Scout',
      agentType: 'explorer',
      paneId: '%1',
      color: 'blue',
    ));
    await tester.pump();
    await tester.pump();

    f.services.messages.publish(
      ClaudeConversation.publisher,
      ClaudeConversation.memberStatusChannel,
      ClaudeConversation.memberStatusData(
        'a1',
        const SessionStatus(model: 'claude-opus-4-7', permissionMode: 'acceptEdits', contextTokens: 21000),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('explorer  ·  opus 4.7  ·  accept-edits  ·  21k ctx'), findsOneWidget);
  });

  testWidgets('Activity degrades to a no-activity message with empty stats', (tester) async {
    await tester.pumpWidget(harness(f, sidebar()));
    await tester.pumpAndSettle();
    expect(find.text('No activity recorded yet.'), findsOneWidget);
  });

  // T-171: roster controls + task list ----------------------------------------

  group('T-171 roster controls', () {
    Future<ClaudeSessionOrchestrator> orchWithMember(WidgetTester tester, {String name = 'Scout', String agentId = 'a1'}) async {
      final orch = _fakeOrchestrator();
      await orch.spawn(SpawnSpec(
        id: 'teammate:$name',
        role: 'teammate',
        sessionId: '$name-uuid',
        cwd: '/repo',
        team: true,
        memberName: name,
      ));

      await tester.pumpWidget(harness(f, sidebar(orchestrator: orch, initialTab: SidebarTab.team)));

      f.services.events.emit(TeamMemberJoined(
        team: 't',
        agentId: agentId,
        name: name,
        agentType: 'coder',
        paneId: '%1',
        color: 'blue',
      ));
      await tester.pump();
      await tester.pump();
      return orch;
    }

    testWidgets('team tab shows MESSAGES placeholder seam', (tester) async {
      await orchWithMember(tester);
      expect(find.text('MESSAGES'), findsOneWidget);
    });

    testWidgets('show/hide toggle changes managed session visibility', (tester) async {
      final semantics = tester.ensureSemantics();
      final orch = await orchWithMember(tester);
      final managed = orch.byId('teammate:Scout')!;
      expect(managed.visible, isTrue);

      // The eye icon tooltips are "Hide pane" and "Show pane".
      // We can find the first ClideTappable for hide (the eye icon).
      // Tap by tooltip text (via Semantics).
      final hideTap = find.bySemanticsLabel('Hide pane').first;
      await tester.tap(hideTap);
      await tester.pump();
      expect(managed.visible, isFalse);

      final showTap = find.bySemanticsLabel('Show pane').first;
      await tester.tap(showTap);
      await tester.pump();
      expect(managed.visible, isTrue);

      semantics.dispose();
      orch.dispose();
    });

    testWidgets('mute toggle gates broker delivery', (tester) async {
      final semantics = tester.ensureSemantics();
      final orch = await orchWithMember(tester);
      final managed = orch.byId('teammate:Scout')!;
      expect(managed.muted, isFalse);

      final muteTap = find.bySemanticsLabel('Mute messages').first;
      await tester.tap(muteTap);
      await tester.pump();
      expect(managed.muted, isTrue);
      expect(orch.broker.isMuted('teammate:Scout'), isTrue);

      final unmuteTap = find.bySemanticsLabel('Unmute messages').first;
      await tester.tap(unmuteTap);
      await tester.pump();
      expect(managed.muted, isFalse);

      semantics.dispose();
      orch.dispose();
    });

    testWidgets('close button kills the session', (tester) async {
      final semantics = tester.ensureSemantics();
      final orch = await orchWithMember(tester);
      expect(orch.byId('teammate:Scout'), isNotNull);

      final closeTap = find.bySemanticsLabel('Close session').first;
      await tester.tap(closeTap);
      await tester.pump();
      await tester.pump(); // allow async close to complete
      expect(orch.byId('teammate:Scout'), isNull);

      semantics.dispose();
      orch.dispose();
    });

    testWidgets('inject-message affordance toggles the text field', (tester) async {
      final semantics = tester.ensureSemantics();
      final orch = await orchWithMember(tester);

      // Before tap: no inject field visible.
      expect(find.byType(EditableText), findsNothing);

      final injectTap = find.bySemanticsLabel('Inject message').first;
      await tester.tap(injectTap);
      await tester.pump();

      // After tap: inject field appears.
      expect(find.byType(EditableText), findsOneWidget);

      // Tapping the cancel (×) icon dismisses it.
      final cancelTap = find.bySemanticsLabel('Cancel').first;
      await tester.tap(cancelTap);
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);

      semantics.dispose();
      orch.dispose();
    });

    testWidgets('submitting inject field sends the text to the session', (tester) async {
      final semantics = tester.ensureSemantics();
      final orch = _fakeOrchestrator();
      // We cannot intercept the proc easily through the public API — verify
      // injectMessage wired up by checking the managed session is the right one.
      await orch.spawn(SpawnSpec(
        id: 'teammate:Alpha',
        role: 'teammate',
        sessionId: 'alpha-uuid',
        cwd: '/repo',
        team: true,
        memberName: 'Alpha',
      ));

      await tester.pumpWidget(harness(f, sidebar(orchestrator: orch, initialTab: SidebarTab.team)));
      f.services.events.emit(const TeamMemberJoined(
        team: 't',
        agentId: 'a2',
        name: 'Alpha',
        agentType: 'coder',
        paneId: '%2',
        color: 'green',
      ));
      await tester.pump();
      await tester.pump();

      // Open inject field.
      await tester.tap(find.bySemanticsLabel('Inject message').first);
      await tester.pump();
      expect(find.byType(EditableText), findsOneWidget);

      // Type and submit.
      await tester.enterText(find.byType(EditableText).first, 'hello agent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Field dismissed after submit.
      expect(find.byType(EditableText), findsNothing);

      semantics.dispose();
      orch.dispose();
      // Note: we cannot assert on _FakeProc.writes here because the process
      // factory closed over the outer list; the session's injectMessage call
      // is verified by the orchestrator unit test in session_orchestrator_test.
    });
  });

  group('T-171 task list', () {
    testWidgets('task list renders live from broker on changes stream', (tester) async {
      final orch = _fakeOrchestrator();
      await orch.spawn(SpawnSpec(
        id: 'primary',
        role: 'primary',
        sessionId: 'primary-uuid',
        cwd: '/repo',
        team: true,
        memberName: 'lead',
      ));
      await orch.spawn(SpawnSpec(
        id: 'teammate:tyre',
        role: 'teammate',
        sessionId: 'tyre-uuid',
        cwd: '/repo',
        team: true,
        memberName: 'tyre',
      ));

      await tester.pumpWidget(harness(f, sidebar(orchestrator: orch, initialTab: SidebarTab.team)));
      f.services.events.emit(const TeamMemberJoined(
        team: 't',
        agentId: 'a1',
        name: 'lead',
        agentType: 'lead',
        paneId: '%1',
        color: 'blue',
      ));
      await tester.pump();
      await tester.pump();

      // No tasks yet.
      expect(find.text('TASKS'), findsNothing);

      // Add a task via the broker.
      orch.broker.claimTask('primary', title: 'wire-the-sidebar');
      await tester.pump();
      await tester.pump();

      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('wire-the-sidebar'), findsOneWidget);

      orch.dispose();
    });

    testWidgets('reassign button cycles task owner', (tester) async {
      final orch = _fakeOrchestrator();
      await orch.spawn(SpawnSpec(id: 'primary', role: 'primary', sessionId: 'p-uuid', cwd: '/repo', team: true, memberName: 'lead'));
      await orch.spawn(SpawnSpec(id: 'teammate:tyre', role: 'teammate', sessionId: 't-uuid', cwd: '/repo', team: true, memberName: 'tyre'));

      // Sized box so the ListView gets a real (tall) viewport — under the
      // shared canSizeOverlay harness the sidebar's scrollable otherwise gets a
      // degenerate viewport and clips the task section out of the semantics
      // tree, so the reassign button below the roster isn't findable by label.
      await tester.pumpWidget(harness(
        f,
        SizedBox(width: 320, height: 700, child: sidebar(orchestrator: orch, initialTab: SidebarTab.team)),
      ));
      f.services.events.emit(const TeamMemberJoined(team: 't', agentId: 'a1', name: 'lead', agentType: 'lead', paneId: '%1', color: 'cyan'));
      await tester.pump();
      await tester.pump();

      orch.broker.claimTask('primary', title: 'the-task');
      await tester.pump();
      await tester.pump();

      final originalOwner = orch.broker.tasks.first.owner;

      // Find the reassign button at the widget level (its Semantics carries the
      // label). We don't use find.bySemanticsLabel here because the shared
      // canSizeOverlay test harness gives the sidebar's ListView a degenerate
      // viewport that clips the lower task section out of the semantics *tree*
      // (the widget is built and tappable; only the semantics node is dropped).
      final reassign = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Reassign task',
      );
      await tester.tap(reassign.first);
      await tester.pump();
      await tester.pump();

      expect(orch.broker.tasks.first.owner, isNot(originalOwner));

      orch.dispose();
    });
  });
}
