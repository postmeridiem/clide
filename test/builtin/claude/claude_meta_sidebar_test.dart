import 'dart:io';

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_meta_sidebar.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

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
  }) =>
      ClaudeMetaSidebar(
        statsLoader: () async => stats,
        pollInterval: Duration.zero,
        config: config,
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
}
