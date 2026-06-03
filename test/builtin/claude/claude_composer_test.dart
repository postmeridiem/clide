/// Tests for the native Claude input composer (T-138): Enter submits,
/// Shift+Enter does not, blank input is ignored, and submitted text is
/// PTY-encoded for `pane.write`.
library;

import 'package:clide/builtin/claude/src/claude_composer.dart';
import 'package:clide/builtin/claude/src/clipboard_paste.dart';
import 'package:clide/builtin/claude/src/slash_commands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('encodeClaudeInput', () {
    test('single-line input gets a trailing carriage return', () {
      expect(encodeClaudeInput('hello claude'), 'hello claude\r');
    });

    test('multi-line input is wrapped in bracketed-paste markers', () {
      expect(
        encodeClaudeInput('line one\nline two'),
        '\x1b[200~line one\nline two\x1b[201~\r',
      );
    });
  });

  group('ClaudeComposer', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    Future<List<String>> pump(WidgetTester tester, {bool enabled = true}) async {
      final submitted = <String>[];
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(enabled: enabled, onSubmit: submitted.add),
      ));
      return submitted;
    }

    testWidgets('Enter submits the text and clears the field', (tester) async {
      final submitted = await pump(tester);
      await tester.enterText(find.byType(EditableText), 'hey there');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(submitted, ['hey there']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    });

    testWidgets('Shift+Enter does not submit', (tester) async {
      final submitted = await pump(tester);
      await tester.enterText(find.byType(EditableText), 'draft');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(submitted, isEmpty);
    });

    testWidgets('blank input is ignored', (tester) async {
      final submitted = await pump(tester);
      await tester.enterText(find.byType(EditableText), '   ');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(submitted, isEmpty);
    });

    testWidgets('disabled composer is read-only', (tester) async {
      await pump(tester, enabled: false);
      expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isTrue);
    });

    Future<void> pasteAttachment(WidgetTester tester) async {
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+V of a file shows a chip and leaves the text field empty', (tester) async {
      // WidgetsApp provides DefaultTextEditingShortcuts in the real app;
      // the bare harness doesn't, so wrap explicitly to map Ctrl+V ->
      // PasteTextIntent, which the composer's Actions override intercepts.
      await tester.pumpWidget(harness(
        f,
        DefaultTextEditingShortcuts(
          child: ClaudeComposer(
            onSubmit: (_) {},
            pasteResolver: () async => const [ComposerAttachment(path: '/tmp/notes.txt', isImage: false)],
          ),
        ),
      ));
      await pasteAttachment(tester);

      expect(find.text('notes.txt'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    });

    testWidgets('submit appends attachment @path tokens to the message', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(harness(
        f,
        DefaultTextEditingShortcuts(
          child: ClaudeComposer(
            onSubmit: submitted.add,
            pasteResolver: () async => const [ComposerAttachment(path: '/tmp/notes.txt', isImage: false)],
          ),
        ),
      ));
      await tester.enterText(find.byType(EditableText), 'look at this');
      await pasteAttachment(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(submitted, ['look at this @/tmp/notes.txt']);
      // Chip cleared after send.
      expect(find.text('notes.txt'), findsNothing);
    });

    Future<List<String>> pumpWithCommands(
      WidgetTester tester,
      List<String> commands,
    ) async {
      final submitted = <String>[];
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(
          onSubmit: submitted.add,
          slashCommandsResolver: () => commands,
        ),
      ));
      return submitted;
    }

    testWidgets('typing a slash opens the typeahead with matching commands', (tester) async {
      await pumpWithCommands(tester, ['model', 'memory', 'clear']);
      await tester.enterText(find.byType(EditableText), '/m');
      await tester.pump();

      expect(find.text('/model'), findsOneWidget);
      expect(find.text('/memory'), findsOneWidget);
      expect(find.text('/clear'), findsNothing);
    });

    testWidgets('an inline slash (mid-message) also opens the typeahead', (tester) async {
      await pumpWithCommands(tester, ['clear', 'compact']);
      await tester.enterText(find.byType(EditableText), 'hey /cl');
      await tester.pump();
      expect(find.text('/clear'), findsOneWidget);
    });

    testWidgets('arrow-down + Enter completes the selected command (no submit)', (tester) async {
      final submitted = await pumpWithCommands(tester, ['model', 'memory']);
      await tester.enterText(find.byType(EditableText), '/m'); // → [memory, model]
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // select 'model'
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '/model ');
      expect(submitted, isEmpty, reason: 'Enter completes, it does not submit, while the popup is open');
      expect(find.text('/memory'), findsNothing, reason: 'popup closes after completion');
    });

    testWidgets('Tab completes the top suggestion', (tester) async {
      await pumpWithCommands(tester, ['clear', 'compact']);
      await tester.enterText(find.byType(EditableText), '/cle');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '/clear ');
    });

    testWidgets('Escape dismisses the typeahead', (tester) async {
      await pumpWithCommands(tester, ['model']);
      await tester.enterText(find.byType(EditableText), '/mo');
      await tester.pump();
      expect(find.text('/model'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('/model'), findsNothing);
    });

    testWidgets('with the popup closed, Enter still submits', (tester) async {
      final submitted = await pumpWithCommands(tester, ['model']);
      await tester.enterText(find.byType(EditableText), 'plain message');
      await tester.pump();
      expect(find.text('/model'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, ['plain message']);
    });

    testWidgets('remove × cancels the attachment before send', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(harness(
        f,
        DefaultTextEditingShortcuts(
          child: ClaudeComposer(
            onSubmit: submitted.add,
            pasteResolver: () async => const [ComposerAttachment(path: '/tmp/notes.txt', isImage: false)],
          ),
        ),
      ));
      await pasteAttachment(tester);
      expect(find.text('notes.txt'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('composer-remove-/tmp/notes.txt')));
      await tester.pumpAndSettle();
      expect(find.text('notes.txt'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'just text');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, ['just text']);
    });

    testWidgets('Escape interrupts when the typeahead is closed', (tester) async {
      var interrupts = 0;
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, onInterrupt: () => interrupts++),
      ));
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(interrupts, 1);
    });

    testWidgets('Escape closes the typeahead before it interrupts', (tester) async {
      var interrupts = 0;
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(
          onSubmit: (_) {},
          onInterrupt: () => interrupts++,
          slashCommandsResolver: () => ['model'],
        ),
      ));
      await tester.enterText(find.byType(EditableText), '/mo');
      await tester.pump();
      expect(find.text('/model'), findsOneWidget);

      // First Escape only dismisses the popup; it does not interrupt.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('/model'), findsNothing);
      expect(interrupts, 0);

      // A second Escape, now with the popup closed, interrupts.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(interrupts, 1);
    });

    testWidgets('the Stop button shows when busy and interrupts on tap', (tester) async {
      var interrupts = 0;
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, busy: true, onInterrupt: () => interrupts++),
      ));
      expect(find.text('Stop  ⎋'), findsOneWidget);

      await tester.tap(find.text('Stop  ⎋'));
      await tester.pump();
      expect(interrupts, 1);
    });

    testWidgets('no Stop button when idle', (tester) async {
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, onInterrupt: () {}),
      ));
      expect(find.text('Stop  ⎋'), findsNothing);
    });

    // T-162: clide-owned commands surface in typeahead even when absent from the
    // CLI probe (slashCommandsResolver).
    testWidgets('clide-owned /resume surfaces even when absent from the probe list', (tester) async {
      // The probe list (CLI-sourced) only has 'model' — no 'resume' or 'fork'.
      await pumpWithCommands(tester, ['model']);
      await tester.enterText(find.byType(EditableText), '/res');
      await tester.pump();

      // /resume must appear (sourced from kClideOwnedCommands).
      expect(find.text('/resume'), findsOneWidget);
      // /model must not appear (doesn't match '/res').
      expect(find.text('/model'), findsNothing);
    });

    testWidgets('clide-owned /clear surfaces without duplicate when also in probe', (tester) async {
      // 'clear' is in both the probe list AND kClideOwnedCommands.
      await pumpWithCommands(tester, ['clear', 'model']);
      await tester.enterText(find.byType(EditableText), '/cl');
      await tester.pump();

      // /clear must appear exactly once (filterSlashCommands de-dupes via seen set).
      expect(find.text('/clear'), findsOneWidget);
    });

    testWidgets('clide-owned commands are reachable via the default resolver', (tester) async {
      // No slashCommandsResolver → default path; kClideOwnedCommands must be included.
      final submitted = <String>[];
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: submitted.add),
      ));
      await tester.enterText(find.byType(EditableText), '/fo');
      await tester.pump();

      // /fork is a kClideOwnedCommands member; it must appear without a probe.
      expect(find.text('/fork'), findsOneWidget);
      // Sanity: kClideOwnedCommands is the source (not a coincidence).
      expect(kClideOwnedCommands, contains('fork'));
    });
  });

  group('ClaudeComposer external focus node (T-227)', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('uses a supplied focus node and focuses the input on request', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(f, ClaudeComposer(onSubmit: (_) {}, focusNode: node)));

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode, same(node));

      node.requestFocus(); // what the pane does on a background tap
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('key handling still works through the supplied node', (tester) async {
      final submitted = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: submitted.add, focusNode: node),
      ));
      await tester.enterText(find.byType(EditableText), 'via external node');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, ['via external node']);
    });
  });

  group('ClaudeComposer prompt history (T-163)', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    String text(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    Future<void> pumpWithHistory(
      WidgetTester tester, {
      required List<String> history,
      ValueChanged<TextEditingValue>? onDraftChanged,
    }) async {
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, history: history, onDraftChanged: onDraftChanged),
      ));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
    }

    testWidgets('Up walks back through history, Down walks forward', (tester) async {
      await pumpWithHistory(tester, history: ['first', 'second', 'third']);
      await tester.enterText(find.byType(EditableText), 'wip');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(text(tester), 'third'); // newest first

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(text(tester), 'second');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(text(tester), 'third');
    });

    testWidgets('Down past the newest entry restores the in-progress draft', (tester) async {
      await pumpWithHistory(tester, history: ['old']);
      await tester.enterText(find.byType(EditableText), 'my draft');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // → 'old'
      await tester.pump();
      expect(text(tester), 'old');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // past newest → restore
      await tester.pump();
      expect(text(tester), 'my draft');
    });

    testWidgets('Up does nothing when there is no history', (tester) async {
      await pumpWithHistory(tester, history: const []);
      await tester.enterText(find.byType(EditableText), 'solo');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(text(tester), 'solo');
    });

    testWidgets('Up off the first line does not recall (multiline edits first)', (tester) async {
      await pumpWithHistory(tester, history: ['recalled']);
      // Caret ends up on the last line of a two-line draft.
      await tester.enterText(find.byType(EditableText), 'line one\nline two');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(text(tester), 'line one\nline two'); // unchanged — no recall
    });

    testWidgets('previewing history does not overwrite the persisted draft', (tester) async {
      final drafts = <TextEditingValue>[];
      await pumpWithHistory(tester, history: ['past'], onDraftChanged: drafts.add);
      await tester.enterText(find.byType(EditableText), 'keep me');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // preview 'past'
      await tester.pump();

      // The last *persisted* draft is still the user's text, not the preview.
      expect(drafts.last.text, 'keep me');
    });
  });

  group('ClaudeComposer draft persistence (T-228)', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('seeds the field from initialValue on mount', (tester) async {
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(
          onSubmit: (_) {},
          initialValue: const TextEditingValue(
            text: 'half-typed',
            selection: TextSelection.collapsed(offset: 4),
          ),
        ),
      ));
      final controller = tester.widget<EditableText>(find.byType(EditableText)).controller;
      expect(controller.text, 'half-typed');
      expect(controller.selection.baseOffset, 4); // caret restored too
    });

    testWidgets('reports draft changes (text + caret) via onDraftChanged', (tester) async {
      final drafts = <TextEditingValue>[];
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, onDraftChanged: drafts.add),
      ));
      await tester.enterText(find.byType(EditableText), 'draft text');
      await tester.pump();

      expect(drafts.last.text, 'draft text');
    });

    testWidgets('reports an empty draft when submitting clears the field', (tester) async {
      final drafts = <TextEditingValue>[];
      await tester.pumpWidget(harness(
        f,
        ClaudeComposer(onSubmit: (_) {}, onDraftChanged: drafts.add),
      ));
      await tester.enterText(find.byType(EditableText), 'send me');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // The last reported value is empty — owners drop the draft so a sent
      // message doesn't come back.
      expect(drafts.last.text, isEmpty);
    });

    testWidgets('round-trips a draft across an interaction-zone swap', (tester) async {
      // Mirrors the pane's pattern: a host holds the draft and shows either
      // the prompt (composer gone) or the composer seeded from that draft.
      final showPrompt = ValueNotifier(false);
      addTearDown(showPrompt.dispose);
      await tester.pumpWidget(harness(f, _DraftSwapHost(showPrompt: showPrompt)));

      await tester.enterText(find.byType(EditableText), 'survived the prompt');
      await tester.pump();

      // Prompt arrives — the composer is torn down.
      showPrompt.value = true;
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);

      // Prompt resolved — composer remounts and restores the draft.
      showPrompt.value = false;
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'survived the prompt',
      );
    });
  });
}

/// Mimics the pane's draft handling (T-228): holds a per-host draft and
/// renders either a prompt placeholder (composer torn down) or the
/// composer seeded from that draft.
class _DraftSwapHost extends StatefulWidget {
  const _DraftSwapHost({required this.showPrompt});
  final ValueListenable<bool> showPrompt;
  @override
  State<_DraftSwapHost> createState() => _DraftSwapHostState();
}

class _DraftSwapHostState extends State<_DraftSwapHost> {
  TextEditingValue? _draft;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.showPrompt,
      builder: (context, prompt, _) => prompt
          ? const SizedBox.shrink()
          : ClaudeComposer(
              onSubmit: (_) {},
              initialValue: _draft,
              onDraftChanged: (v) => _draft = v,
            ),
    );
  }
}
