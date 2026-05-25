import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

ToolPrompt permissionPrompt() => const ToolPrompt(
      promptId: 'req-1',
      toolName: 'Write',
      displayName: 'Write',
      description: 'banana.txt',
      input: {'file_path': '/tmp/banana.txt', 'content': 'banana'},
    );

ToolPrompt questionPrompt({bool multi = false}) => ToolPrompt(
      promptId: 'req-q',
      toolName: 'AskUserQuestion',
      displayName: 'AskUserQuestion',
      input: {
        'questions': [
          {
            'question': 'Do you prefer cats or dogs?',
            'header': 'Pet',
            'multiSelect': multi,
            'options': [
              {'label': 'Cats', 'description': 'cat person'},
              {'label': 'Dogs', 'description': 'dog person'},
            ],
          },
        ],
      },
    );

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('permission card: Allow returns AllowTool echoing the input', (tester) async {
    ToolDecision? decision;
    String? id;
    await tester.pumpWidget(harness(
      f,
      ToolPromptCard(
        prompt: permissionPrompt(),
        onResolve: (p, d) {
          id = p;
          decision = d;
        },
      ),
    ));
    await tester.pump();

    expect(find.text('permission · Write'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pump();

    expect(id, 'req-1');
    expect(decision, isA<AllowTool>());
    expect((decision as AllowTool).updatedInput['content'], 'banana');
  });

  testWidgets('permission card: Deny returns DenyTool with a message', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(
      f,
      ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, d) => decision = d),
    ));
    await tester.pump();

    await tester.tap(find.text('Deny'));
    await tester.pump();

    expect(decision, isA<DenyTool>());
    expect((decision as DenyTool).message, isNotEmpty);
  });

  testWidgets('question card: Submit is gated until an option is picked, then returns answers', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(
      f,
      ToolPromptCard(prompt: questionPrompt(), onResolve: (_, d) => decision = d),
    ));
    await tester.pump();

    expect(find.text('Do you prefer cats or dogs?'), findsOneWidget);

    // Submit before choosing → no-op (disabled).
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(decision, isNull);

    await tester.tap(find.textContaining('Dogs'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(decision, isA<AllowTool>());
    final answers = (decision as AllowTool).updatedInput['answers'] as Map;
    expect(answers['Do you prefer cats or dogs?'], 'Dogs');
  });

  testWidgets('question card: multi-select joins chosen labels comma-separated', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(
      f,
      ToolPromptCard(prompt: questionPrompt(multi: true), onResolve: (_, d) => decision = d),
    ));
    await tester.pump();

    await tester.tap(find.textContaining('Cats'));
    await tester.pump();
    await tester.tap(find.textContaining('Dogs'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    final answers = (decision as AllowTool).updatedInput['answers'] as Map;
    expect(answers['Do you prefer cats or dogs?'], 'Cats, Dogs');
  });
}
