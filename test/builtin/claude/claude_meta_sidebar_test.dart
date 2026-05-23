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

  ClaudeMetaSidebar sidebar({ClaudeStats stats = const ClaudeStats()}) => ClaudeMetaSidebar(
        statsLoader: () async => stats,
        pollInterval: Duration.zero,
      );

  testWidgets('shows the latest day + lifetime activity from stats', (tester) async {
    const stats = ClaudeStats(
      lastComputed: '2026-05-22',
      daily: [
        DailyActivity(date: '2026-05-01', messageCount: 100, sessionCount: 2, toolCallCount: 30),
        DailyActivity(date: '2026-05-22', messageCount: 250, sessionCount: 5, toolCallCount: 80),
      ],
    );
    await tester.pumpWidget(harness(f, sidebar(stats: stats)));
    await tester.pumpAndSettle();

    expect(find.text('2026-05-22'), findsOneWidget);
    expect(find.text('250 msgs  ·  5 sessions  ·  80 tools'), findsOneWidget);
    expect(find.text('Lifetime: 350 msgs over 2 days'), findsOneWidget);
    expect(find.text('No team active.'), findsOneWidget);
  });

  testWidgets('adds and removes team members from the roster', (tester) async {
    await tester.pumpWidget(harness(f, sidebar()));
    await tester.pumpAndSettle();

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
    expect(find.text('Scout'), findsOneWidget);
    expect(find.text('explorer  ·  opus 4.7'), findsOneWidget);

    f.services.events.emit(const TeamMemberLeft(team: 't', agentId: 'a1', paneId: '%1'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Scout'), findsNothing);
    expect(find.text('No team active.'), findsOneWidget);
  });

  testWidgets('folds live per-member status (mode + context) into the roster row', (tester) async {
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

  testWidgets('degrades to a no-activity message with empty stats', (tester) async {
    await tester.pumpWidget(harness(f, sidebar()));
    await tester.pumpAndSettle();
    expect(find.text('No activity recorded yet.'), findsOneWidget);
  });
}
