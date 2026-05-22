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
  });
}
