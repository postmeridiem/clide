/// Direct tests for ActivityTabView (T-415): the USAGE block renders parsed
/// /usage values; the empty state still shows under the control strip.
library;

import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show ClaudeUsage;
import 'package:clide/builtin/claude/src/meta_sidebar/activity_tab.dart';
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('renders the USAGE block from parsed /usage values', (tester) async {
    const usage = ClaudeUsage(session: '15% used · resets Jun 12, 3:39pm', week: '53% used · resets Jun 15, 6:59pm', weekSonnet: '0% used');
    await tester.pumpWidget(harness(f, const ActivityTabView(stats: ClaudeStats(), primaryStatus: null, config: null, usage: usage)));
    await tester.pump();

    expect(find.text('USAGE'), findsOneWidget);
    expect(find.text('15% used · resets Jun 12, 3:39pm'), findsOneWidget);
    expect(find.text('53% used · resets Jun 15, 6:59pm'), findsOneWidget);
    expect(find.text('0% used'), findsOneWidget);
  });

  testWidgets('no stats and no usage → the control strip plus the placeholder', (tester) async {
    await tester.pumpWidget(harness(f, const ActivityTabView(stats: ClaudeStats(), primaryStatus: null, config: null)));
    await tester.pump();

    expect(find.text('SESSION'), findsOneWidget); // controls always present
    expect(find.text('No activity recorded yet.'), findsOneWidget);
    expect(find.text('USAGE'), findsNothing);
  });

  testWidgets('renders a WORKFLOWS row per live run with its done/total count (T-416)', (tester) async {
    var run = const WorkflowRun(toolUseId: 'x1', name: 'parallel-words');
    run = run.foldEvent({
      'subtype': 'task_progress',
      'tool_use_id': 'x1',
      'workflow_progress': [
        {'type': 'workflow_agent', 'index': 1, 'label': 'a', 'state': 'done'},
        {'type': 'workflow_agent', 'index': 2, 'label': 'b', 'state': 'start'},
      ],
    });
    await tester.pumpWidget(harness(f, ActivityTabView(stats: const ClaudeStats(), primaryStatus: null, config: null, workflows: {'x1': run})));
    await tester.pump();

    expect(find.text('WORKFLOWS'), findsOneWidget);
    expect(find.text('parallel-words'), findsOneWidget);
    expect(find.text('1/2 agents'), findsOneWidget);
  });

  testWidgets('no workflows → no WORKFLOWS section', (tester) async {
    await tester.pumpWidget(harness(f, const ActivityTabView(stats: ClaudeStats(), primaryStatus: null, config: null)));
    await tester.pump();
    expect(find.text('WORKFLOWS'), findsNothing);
  });
}
