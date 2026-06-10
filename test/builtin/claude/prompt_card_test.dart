import 'package:clide/builtin/claude/src/prompt_card.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
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
    expect(find.text('1. Allow'), findsOneWidget);
    expect(find.text('2. Deny'), findsOneWidget);

    await tester.tap(find.text('1. Allow'));
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

  testWidgets('permission card: Write suppresses the description line when it duplicates file_path', (tester) async {
    const prompt = ToolPrompt(
      promptId: 'req-w',
      toolName: 'Write',
      displayName: 'Write',
      // Claude often sends the path itself as the description for Write —
      // the body already shows it via _pathLine, so the line above should
      // be suppressed to avoid printing the same path twice.
      description: '/tmp/clide-ux-test.txt',
      input: {'file_path': '/tmp/clide-ux-test.txt', 'content': 'hello'},
    );
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
    await tester.pump();

    // The path should appear exactly once (in _pathLine, inside the body).
    expect(find.text('/tmp/clide-ux-test.txt'), findsOneWidget);
  });

  testWidgets('permission card: Write keeps the description line when it adds info', (tester) async {
    const prompt = ToolPrompt(
      promptId: 'req-w2',
      toolName: 'Write',
      displayName: 'Write',
      description: 'banana.txt',
      input: {'file_path': '/tmp/banana.txt', 'content': 'banana'},
    );
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
    await tester.pump();

    expect(find.text('banana.txt'), findsOneWidget);
    expect(find.text('/tmp/banana.txt'), findsOneWidget);
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

    await tester.tap(find.text('2. Deny'));
    await tester.pump();

    expect(decision, isA<DenyTool>());
    expect((decision as DenyTool).message, isNotEmpty);
  });

  testWidgets('permission: no "don\'t ask again" button without a suggestion', (tester) async {
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, __) {})));
    await tester.pump();
    expect(find.text("2. Allow & don't ask again"), findsNothing);
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

    expect(find.text("2. Allow & don't ask again"), findsOneWidget);
    await tester.tap(find.text("2. Allow & don't ask again"));
    await tester.pump();
    expect((decision as AllowTool).updatedPermissions, hasLength(1));
  });

  testWidgets('permission: a typed note rides Deny as the message', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'write it under docs/ instead');
    await tester.pump();
    await tester.tap(find.text('2. Deny'));
    await tester.pump();
    expect((decision as DenyTool).message, 'write it under docs/ instead');
  });

  testWidgets('permission: a typed note rides Allow as a follow-up note', (tester) async {
    ToolDecision? decision;
    await tester.pumpWidget(harness(f, ToolPromptCard(prompt: permissionPrompt(), onResolve: (_, d) => decision = d)));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'fyi: sandbox only');
    await tester.pump();
    await tester.tap(find.text('1. Allow'));
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

    await tester.tap(find.textContaining('Other…'));
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

  // -- shared tool-input rendering helpers (T-168) ----------------------------

  group('permission card: Edit shows before/after diff via shared helper', () {
    testWidgets('Edit card has two code blocks (before/after)', (tester) async {
      const prompt = ToolPrompt(
        promptId: 'req-e',
        toolName: 'Edit',
        displayName: 'Edit',
        input: {
          'file_path': '/tmp/foo.dart',
          'old_string': 'void main() {}',
          'new_string': 'void main() => run();',
        },
      );
      await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
      await tester.pump();
      // Two code blocks: before + after.
      expect(find.byType(ClideCodeBlock), findsNWidgets(2));
      expect(find.text('— before'), findsOneWidget);
      expect(find.text('+ after'), findsOneWidget);
    });
  });

  group('permission card: Read/Grep show compact path via shared helper', () {
    testWidgets('Read shows the file path label', (tester) async {
      const prompt = ToolPrompt(
        promptId: 'req-r',
        toolName: 'Read',
        displayName: 'Read',
        input: {'file_path': '/docs/readme.md'},
      );
      await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
      await tester.pump();
      expect(find.text('/docs/readme.md'), findsOneWidget);
      // No code blocks — just a text label for Read.
      expect(find.byType(ClideCodeBlock), findsNothing);
    });

    testWidgets('Grep shows pattern quoted alongside any path', (tester) async {
      // Grep with both path and pattern: the label shows file_path + quoted pattern.
      const prompt = ToolPrompt(
        promptId: 'req-grep',
        toolName: 'Grep',
        displayName: 'Grep',
        input: {'pattern': 'TODO', 'path': '/src'},
      );
      await tester.pumpWidget(harness(f, ToolPromptCard(prompt: prompt, onResolve: (_, __) {})));
      await tester.pump();
      // The combined label contains both the path and the quoted pattern.
      expect(find.textContaining('"TODO"'), findsOneWidget);
    });
  });

  group('permission card: didUpdateWidget resets state for a new prompt id', () {
    testWidgets('swapping the prompt id reinitialises the card', (tester) async {
      // To trigger didUpdateWidget: use a ValueNotifier-driven parent so the
      // _ToolPromptCardState is reused (didUpdateWidget fires, not remount).
      ToolDecision? decision;
      final notifier = ValueNotifier<ToolPrompt>(questionPrompt());
      addTearDown(notifier.dispose);

      await tester.pumpWidget(harness(
        f,
        ValueListenableBuilder<ToolPrompt>(
          valueListenable: notifier,
          builder: (_, p, __) => ToolPromptCard(prompt: p, onResolve: (_, d) => decision = d),
        ),
      ));
      await tester.pump();
      expect(find.text('Do you prefer cats or dogs?'), findsOneWidget);

      // Pick an option so the card state is non-initial.
      await tester.tap(find.textContaining('Dogs'));
      await tester.pump();

      // Swap to a new prompt (different promptId) — didUpdateWidget fires.
      notifier.value = const ToolPrompt(
        promptId: 'req-new',
        toolName: 'AskUserQuestion',
        displayName: 'AskUserQuestion',
        input: {
          'questions': [
            {
              'question': 'New question?',
              'header': 'New',
              'multiSelect': false,
              'options': [
                {'label': 'Alpha', 'description': ''},
                {'label': 'Beta', 'description': ''},
              ],
            },
          ],
        },
      );
      await tester.pump();

      // New question visible, old selection gone.
      expect(find.text('New question?'), findsOneWidget);
      expect(find.text('Do you prefer cats or dogs?'), findsNothing);

      // Submit is still gated (selection reset).
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(decision, isNull);

      // Pick an option on the new card.
      await tester.tap(find.textContaining('Alpha'));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(decision, isA<AllowTool>());
      expect((decision as AllowTool).updatedInput['answers']['New question?'], 'Alpha');
    });
  });

  group('number-key + Enter shortcuts (T-240)', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Future<void> pumpCard(WidgetTester tester, ToolPrompt p, void Function(ToolDecision) onDecide) async {
      await tester.pumpWidget(harness(f, ToolPromptCard(prompt: p, onResolve: (_, d) => onDecide(d))));
      await tester.pump(); // let the card autofocus
    }

    testWidgets('1 = Allow, 2 = Deny when there is no remember button', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      expect(d, isA<AllowTool>());
    });

    testWidgets('2 = Deny with no remember button', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(d, isA<DenyTool>());
    });

    const sugg = [
      {'type': 'setMode', 'mode': 'acceptEdits', 'destination': 'session'}
    ];

    testWidgets('with a remember suggestion: 2 = Allow & remember', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(suggestions: sugg), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect((d as AllowTool).updatedPermissions, hasLength(1));
    });

    testWidgets('with a remember suggestion: 3 = Deny', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(suggestions: sugg), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      expect(d, isA<DenyTool>());
    });

    testWidgets('a number key selects a question option', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, questionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2); // Dogs (option 2)
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect((d as AllowTool).updatedInput['answers']['Do you prefer cats or dogs?'], 'Dogs');
    });

    testWidgets('Enter confirms the primary action (Allow)', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(d, isA<AllowTool>());
    });

    testWidgets('a focused note field swallows digits (no button fires)', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.tap(find.byType(EditableText)); // focus the note field
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      expect(d, isNull, reason: 'typing in the note must not trigger Allow');
    });

    // Numpad twins map to the same selection as the number row (T-310).
    testWidgets('numpad 1 = Allow', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.pump();
      expect(d, isA<AllowTool>());
    });

    testWidgets('numpad 2 = Deny when there is no remember button', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
      await tester.pump();
      expect(d, isA<DenyTool>());
    });

    testWidgets('numpad selects a question option just like the number row', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, questionPrompt(), (x) => d = x);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2); // Dogs (option 2)
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect((d as AllowTool).updatedInput['answers']['Do you prefer cats or dogs?'], 'Dogs');
    });

    testWidgets('a focused note field swallows numpad digits too', (tester) async {
      ToolDecision? d;
      await pumpCard(tester, permissionPrompt(), (x) => d = x);
      await tester.tap(find.byType(EditableText)); // focus the note field
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.pump();
      expect(d, isNull, reason: 'typing in the note must not trigger Allow');
    });
  });
}
