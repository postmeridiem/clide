/// Widget tests for SelectableRegion-compatible text rendering in
/// [ClideMarkdown] and [ClideCodeBlock].
///
/// Regression guard for T-135: plain paragraphs and code blocks must
/// register with the ambient [SelectableRegion] (Flutter's widget-layer
/// selection API, wrapped by the app in a SelectionArea) so text can be
/// selected and copied across both widget types. Tables and tappable link
/// spans are known non-selectable islands in v1 and are NOT tested here.
library;

import 'package:clide/widgets/src/clide_code_block.dart';
import 'package:clide/widgets/src/clide_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

// ---------------------------------------------------------------------------
// Inline mock clipboard — intercepts the platform channel so the test does
// not require a real platform binary.
// ---------------------------------------------------------------------------

class _MockClipboard {
  Map<String, dynamic> _data = {'text': null};

  Future<Object?> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        _data = Map<String, dynamic>.from(call.arguments as Map);
      case 'Clipboard.getData':
        return _data;
      case 'Clipboard.hasStrings':
        final text = _data['text'] as String?;
        return {'value': text != null && text.isNotEmpty};
    }
    return null;
  }

  String? get text => _data['text'] as String?;
}

// ---------------------------------------------------------------------------
// Key-combo helper — mirrors Flutter SDK selectable_region_test approach.
// ---------------------------------------------------------------------------

Future<void> _sendKeys(WidgetTester tester, SingleActivator activator) async {
  final mods = <LogicalKeyboardKey>[
    if (activator.control) LogicalKeyboardKey.control,
    if (activator.shift) LogicalKeyboardKey.shift,
    if (activator.alt) LogicalKeyboardKey.alt,
    if (activator.meta) LogicalKeyboardKey.meta,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyDownEvent(activator.trigger);
  await tester.sendKeyUpEvent(activator.trigger);
  await tester.pump();
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SelectableRegion — ClideMarkdown + ClideCodeBlock', () {
    late KernelFixture f;
    late _MockClipboard clipboard;

    setUp(() async {
      f = await KernelFixture.create();
      clipboard = _MockClipboard();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, clipboard.handleMethodCall);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      await f.dispose();
    });

    testWidgets('Ctrl+A + Ctrl+C inside SelectableRegion copies paragraph and code text', (tester) async {
      // Give the view a physical size so paragraph layout can resolve.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const paraText = 'Hello world';
      const codeText = 'print(42)';

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        harness(
          f,
          // DefaultTextEditingShortcuts registers Ctrl+A → SelectAllTextIntent
          // and Ctrl+C → CopySelectionTextIntent. SelectableRegion provides
          // the Actions; WidgetsApp (absent here) normally provides the
          // Shortcuts — so we install them explicitly for the test.
          DefaultTextEditingShortcuts(
            child: SelectableRegion(
              focusNode: focusNode,
              selectionControls: emptyTextSelectionControls,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  ClideMarkdown(paraText),
                  ClideCodeBlock(source: codeText),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Give the SelectableRegion focus so it receives keyboard shortcuts.
      focusNode.requestFocus();
      await tester.pump();

      // Ctrl+A selects all content, Ctrl+C copies it.
      await _sendKeys(tester, const SingleActivator(LogicalKeyboardKey.keyA, control: true));
      await _sendKeys(tester, const SingleActivator(LogicalKeyboardKey.keyC, control: true));
      await tester.pump();

      // Both the paragraph text and the code text should appear in the
      // clipboard. SelectableRegion concatenates selectables with newlines.
      final copied = clipboard.text ?? '';
      expect(
        copied,
        contains(paraText),
        reason:
            'paragraph text must be selectable via SelectableRegion after '
            'converting ClideMarkdown from RichText to Text.rich',
      );
      expect(
        copied,
        contains(codeText),
        reason:
            'code block text must be selectable via SelectableRegion after '
            'converting ClideCodeBlock from RichText to Text.rich',
      );
    });

    testWidgets('Text.rich nodes are owned by Text widgets, registering with SelectableRegion', (tester) async {
      // Structural guard: every RichText in the ClideMarkdown/ClideCodeBlock
      // subtree must be wrapped by a Text ancestor. Text (including Text.rich)
      // registers itself with the ambient SelectionRegistrar; a bare
      // RichText(...) does not.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        harness(
          f,
          DefaultTextEditingShortcuts(
            child: SelectableRegion(
              focusNode: focusNode,
              selectionControls: emptyTextSelectionControls,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  ClideMarkdown('A paragraph.\n\nSecond paragraph.'),
                  ClideCodeBlock(source: 'var x = 1;'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Every RichText in the subtree should have a Text ancestor — that is
      // what Text.rich builds. A bare RichText(...) has no Text parent.
      final richTexts = find.byType(RichText);
      for (final el in richTexts.evaluate()) {
        final textAncestor = find.ancestor(of: find.byElementPredicate((e) => e == el), matching: find.byType(Text));
        expect(
          textAncestor,
          findsAtLeastNWidgets(1),
          reason:
              'RichText for "${(el.widget as RichText).text.toPlainText()}" '
              'should be owned by a Text (built via Text.rich, not bare RichText)',
        );
      }
    });
  });
}
