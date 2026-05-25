/// Tests for the native Claude input composer (T-138): Enter submits,
/// Shift+Enter does not, blank input is ignored, and submitted text is
/// PTY-encoded for `pane.write`.
library;

import 'package:clide/builtin/claude/src/claude_composer.dart';
import 'package:clide/builtin/claude/src/clipboard_paste.dart';
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
  });
}
