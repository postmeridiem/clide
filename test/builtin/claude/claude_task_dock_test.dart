/// Widget coverage for the docked task list (T-308): hidden when empty,
/// collapsed summary with the current in-progress item, expand/collapse, and
/// per-item status semantics.
library;

import 'package:clide/builtin/claude/src/claude_task_dock.dart';
import 'package:clide/builtin/claude/src/task_list.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  const tasks = [
    TaskItem(text: 'wire the dock', status: TaskStatus.completed),
    TaskItem(text: 'render the rows', status: TaskStatus.inProgress),
    TaskItem(text: 'write the tests', status: TaskStatus.pending),
  ];

  Future<void> pump(WidgetTester tester, List<TaskItem> items) async {
    await tester.pumpWidget(harness(
      f,
      Align(alignment: Alignment.topLeft, child: SizedBox(width: 400, child: ClaudeTaskDock(tasks: items))),
    ));
    await tester.pump();
  }

  testWidgets('renders nothing when there are no tasks', (tester) async {
    await pump(tester, const []);
    expect(find.byType(ClideText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed: a one-line summary + the current in-progress item; rows hidden', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, tasks);
    expect(find.text('3 tasks · 1 done'), findsOneWidget);
    expect(find.text('render the rows'), findsOneWidget); // current in-progress in the summary
    // The other rows aren't shown while collapsed.
    expect(find.text('wire the dock'), findsNothing);
    expect(find.text('write the tests'), findsNothing);
    expect(find.bySemanticsLabel('Claude task list, 3 tasks · 1 done, collapsed'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping expands to the full checklist with per-item status', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, tasks);
    await tester.tap(find.bySemanticsLabel('Claude task list, 3 tasks · 1 done, collapsed'));
    await tester.pump();

    expect(find.text('wire the dock'), findsOneWidget);
    expect(find.text('render the rows'), findsOneWidget);
    expect(find.text('write the tests'), findsOneWidget);
    // Per-item status announced for AT.
    expect(find.bySemanticsLabel('wire the dock, done'), findsOneWidget);
    expect(find.bySemanticsLabel('render the rows, in progress'), findsOneWidget);
    expect(find.bySemanticsLabel('write the tests, pending'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('singular task count reads "1 task"', (tester) async {
    await pump(tester, const [TaskItem(text: 'lonely', status: TaskStatus.pending)]);
    expect(find.text('1 task · 0 done'), findsOneWidget);
  });
}
