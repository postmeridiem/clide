import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

ToolPrompt permissionPrompt({List<dynamic> suggestions = const []}) => ToolPrompt(
      promptId: 'req-1',
      toolName: 'Write',
      displayName: 'Write',
      description: 'banana.txt',
      input: const {'file_path': '/tmp/banana.txt', 'content': 'banana'},
      permissionSuggestions: suggestions,
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

ToolPrompt twoQuestionPrompt() => const ToolPrompt(
      promptId: 'req-2q',
      toolName: 'AskUserQuestion',
      displayName: 'AskUserQuestion',
      input: {
        'questions': [
          {
            'question': 'Which pet?',
            'header': 'Pet',
            'multiSelect': false,
            'options': [
              {'label': 'Cats', 'description': ''},
              {'label': 'Dogs', 'description': ''},
            ],
          },
          {
            'question': 'How eaten?',
            'header': 'Eaten',
            'multiSelect': false,
            'options': [
              {'label': 'Fresh', 'description': ''},
              {'label': 'Smoothie', 'description': ''},
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

  testWidgets('permission card shows the command being permitted', (tester) async {
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, __) {})));
    await tester.pump();
    expect(find.byType(ClideCodeBlock), findsOneWidget);
  });

  testWidgets('permission card: Bash renders the command as a shell code block, not JSON', (tester) async {
    const prompt = ToolPrompt(
      promptId: 'req-b',
      toolName: 'Bash',
      displayName: 'Bash',
      description: 'Read IDE lock files',
      input: {'command': 'cat ~/.claude/ide/97632.lock', 'description': 'Read IDE lock files'},
    );
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
    await tester.pump();

    final block = tester.widget<ClideCodeBlock>(find.byType(ClideCodeBlock));
    expect(block.language, 'bash');
    expect(block.source, 'cat ~/.claude/ide/97632.lock');
    // The raw `description` key shouldn't bleed into the body — it's already
    // shown above as the prompt's description line.
    expect(find.textContaining('"description"'), findsNothing);
  });

  testWidgets('permission card: Bash shows background/timeout footer when set', (tester) async {
    const prompt = ToolPrompt(
      promptId: 'req-b2',
      toolName: 'Bash',
      displayName: 'Bash',
      description: 'long task',
      input: {'command': 'sleep 30', 'run_in_background': true, 'timeout': 60000},
    );
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
    await tester.pump();
    expect(find.text('background · timeout 60000ms'), findsOneWidget);
  });

  testWidgets('permission card: unknown tool falls back to JSON', (tester) async {
    const prompt = ToolPrompt(
      promptId: 'req-x',
      toolName: 'NovelTool',
      displayName: 'NovelTool',
      input: {'foo': 'bar'},
    );
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
    await tester.pump();
    final block = tester.widget<ClideCodeBlock>(find.byType(ClideCodeBlock));
    expect(block.language, 'json');
    expect(block.source, contains('"foo"'));
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

  testWidgets('permission: no "don\'t ask again" button without a suggestion', (tester) async {
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, __) {})));
    await tester.pump();
    expect(find.text("Allow & don't ask again"), findsNothing);
  });

  testWidgets('permission: "don\'t ask again" shows with a suggestion and returns updatedPermissions', (tester) async {
    ToolDecision? decision;
    const sugg = [
      {'type': 'setMode', 'mode': 'acceptEdits', 'destination': 'session'}
    ];
    await tester.pumpWidget(harness(
      f,
      ToolPromptCard(prompt: permissionPrompt(suggestions: sugg), onResolve: (_, d) => decision = d),
    ));
    await tester.pump();

    expect(find.text("Allow & don't ask again"), findsOneWidget);
    await tester.tap(find.text("Allow & don't ask again"));
    await tester.pump();
    expect((decision as AllowTool).updatedPermissions, hasLength(1));
  });

  testWidgets('permission: a typed note rides Deny as the message', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'write it under docs/ instead');
    await tester.pump();
    await tester.tap(find.text('Deny'));
    await tester.pump();
    expect((decision as DenyTool).message, 'write it under docs/ instead');
  });

  testWidgets('permission: a typed note rides Allow as a follow-up note', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'fyi: sandbox only');
    await tester.pump();
    await tester.tap(find.text('Allow'));
    await tester.pump();
    expect((decision as AllowTool).followUpNote, 'fyi: sandbox only');
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

  testWidgets('question card: "Other…" free-text becomes the answer value', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: questionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();

    await tester.tap(find.text('○ Other…'));
    await tester.pump();
    // Two fields now: [0] = the Other free-text, [1] = the per-choice note.
    await tester.enterText(find.byType(EditableText).first, 'Kiwi');
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    final answers = (decision as AllowTool).updatedInput['answers'] as Map;
    expect(answers['Do you prefer cats or dogs?'], 'Kiwi'); // not the word "Other"
  });

  testWidgets('question card: a per-choice note is appended to the label', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: questionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();

    await tester.tap(find.textContaining('Dogs'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'only big ones'); // the note field
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    final answers = (decision as AllowTool).updatedInput['answers'] as Map;
    expect(answers['Do you prefer cats or dogs?'], 'Dogs — only big ones');
  });

  testWidgets('multi-question: steps through to review, then submits both answers', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: twoQuestionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();

    // Stepper nav shows numbered headers; only question 1 is visible.
    expect(find.textContaining('1 · Pet'), findsOneWidget);
    expect(find.text('Which pet?'), findsOneWidget);
    expect(find.text('How eaten?'), findsNothing);

    await tester.tap(find.textContaining('Dogs'));
    await tester.pump();
    await tester.tap(find.text('Next ›'));
    await tester.pump();

    expect(find.text('How eaten?'), findsOneWidget);
    await tester.tap(find.textContaining('Fresh'));
    await tester.pump();
    await tester.tap(find.text('Review ›'));
    await tester.pump();

    // Review screen lists both answers; submit delivers them.
    expect(find.text('Review your answers'), findsOneWidget);
    await tester.tap(find.text('Submit answers'));
    await tester.pump();

    final answers = (decision as AllowTool).updatedInput['answers'] as Map;
    expect(answers['Which pet?'], 'Dogs');
    expect(answers['How eaten?'], 'Fresh');
  });

  testWidgets('question card: "chat instead" denies the prompt', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: questionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();

    await tester.tap(find.text('chat instead'));
    await tester.pump();
    expect(decision, isA<DenyTool>());
  });
}
