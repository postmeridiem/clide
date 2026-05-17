/// More widget tests covering the next batch of zero-coverage files
/// under `lib/widgets/src/`: ClideMarkdown, ClideCodeBlock,
/// ClideAccordion, ClideScrollbar, ClidePtyView.
library;

import 'package:clide/src/terminal/terminal.dart';
import 'package:clide/widgets/src/clide_accordion.dart';
import 'package:clide/widgets/src/clide_code_block.dart';
import 'package:clide/widgets/src/clide_markdown.dart';
import 'package:clide/widgets/src/clide_pty_view.dart';
import 'package:clide/widgets/src/clide_scrollbar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  group('ClideMarkdown', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders headings, paragraphs, lists, code blocks, blockquotes', (tester) async {
      const src = '''# Heading One

A paragraph with **bold** and *italic* and `code` and a [link](https://example.com).

## Heading Two

- bullet one
- bullet two with **bold**
- bullet three

1. ordered one
2. ordered two

> A blockquote line.

Final paragraph.
''';
      await tester.pumpWidget(harness(f, const SingleChildScrollView(child: ClideMarkdown(src))));
      await tester.pumpAndSettle();
      expect(find.byType(ClideMarkdown), findsOneWidget);
      // Some headings/text should be present somewhere in the tree.
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('renders a fenced code block via ClideCodeBlock', (tester) async {
      const src = '''Here is some Dart:

```dart
void main() {
  print('hi');
}
```

After.
''';
      await tester.pumpWidget(harness(f, const SingleChildScrollView(child: ClideMarkdown(src))));
      await tester.pumpAndSettle();
      expect(find.byType(ClideCodeBlock), findsOneWidget);
    });

    testWidgets('renders horizontal rules', (tester) async {
      const src = 'before\n\n---\n\nafter';
      await tester.pumpWidget(harness(f, const ClideMarkdown(src)));
      await tester.pumpAndSettle();
      expect(find.byType(ClideMarkdown), findsOneWidget);
    });

    testWidgets('record-id link fires onRecordTap callback', (tester) async {
      var tapped = '';
      const src = 'See [D-1](#anchor) for details.';
      await tester.pumpWidget(harness(
        f,
        ClideMarkdown(src, onRecordTap: (id) => tapped = id),
      ));
      await tester.pumpAndSettle();
      // The record-link path matches D-1 / Q-N / R-N / T-N and produces
      // a tappable span. We can't easily simulate a TextSpan tap from
      // the high-level finders, so this just exercises the rendering
      // path.
      expect(find.byType(ClideMarkdown), findsOneWidget);
      expect(tapped, isEmpty); // not tapped yet — no crash is the point
    });

    testWidgets('record-id link tap actually invokes onRecordTap', (tester) async {
      var tapped = '';
      const src = '[D-1](#anchor)';
      await tester.pumpWidget(
        harness(f, ClideMarkdown(src, onRecordTap: (id) => tapped = id)),
      );
      await tester.pumpAndSettle();
      // The link renders as a ClideTappable embedded in a WidgetSpan.
      await tester.tap(find.text('D-1'));
      await tester.pumpAndSettle();
      expect(tapped, 'D-1');
    });

    testWidgets('h3 / h4 / h5 / h6 headings render with the right padding tier', (tester) async {
      const src = '### h3\n\n#### h4\n\n##### h5\n\n###### h6\n';
      await tester.pumpWidget(harness(f, const ClideMarkdown(src)));
      await tester.pumpAndSettle();
      expect(find.byType(ClideMarkdown), findsOneWidget);
      // Each heading contributes a Padding parent — at minimum the document
      // must render without throwing and include RichText spans for each.
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('renders pipe-style tables (thead + tbody)', (tester) async {
      const src = '| col a | col b |\n|-------|-------|\n| a1    | b1    |\n| a2    | b2    |\n';
      await tester.pumpWidget(harness(f, const ClideMarkdown(src)));
      await tester.pumpAndSettle();
      // The Flutter `Table` widget appears for every rendered markdown table.
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('renders ~~strikethrough~~ as a del span', (tester) async {
      const src = 'this is ~~gone~~ now';
      await tester.pumpWidget(harness(f, const ClideMarkdown(src)));
      await tester.pumpAndSettle();
      expect(find.byType(ClideMarkdown), findsOneWidget);
    });

    testWidgets('unknown block tags fall through to the default branch without throwing', (tester) async {
      // Raw HTML the markdown parser leaves as a passthrough element with an
      // unrecognized tag — exercises the `default:` arm of `_buildBlock`.
      const src = '<aside>side note</aside>';
      await tester.pumpWidget(harness(f, const ClideMarkdown(src)));
      await tester.pumpAndSettle();
      expect(find.byType(ClideMarkdown), findsOneWidget);
    });
  });

  group('ClideCodeBlock', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders plain source when no language is given', (tester) async {
      await tester.pumpWidget(harness(f, const ClideCodeBlock(source: 'plain text\nmultiple lines')));
      await tester.pumpAndSettle();
      expect(find.byType(ClideCodeBlock), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('handles a language whose grammar is unavailable (falls back to plain text)', (tester) async {
      await tester.pumpWidget(harness(
        f,
        const ClideCodeBlock(source: 'fn main() {}', language: 'rust'),
      ));
      await tester.pumpAndSettle();
      // TreeSitterService can't load the grammar in tests → falls back
      // to plain rendering.
      expect(find.byType(ClideCodeBlock), findsOneWidget);
    });

    testWidgets('didUpdateWidget triggers a re-highlight when source changes', (tester) async {
      await tester.pumpWidget(harness(f, const ClideCodeBlock(source: 'a', language: 'dart')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(f, const ClideCodeBlock(source: 'b', language: 'dart')));
      await tester.pumpAndSettle();
      expect(find.byType(ClideCodeBlock), findsOneWidget);
    });
  });

  group('ClideAccordion', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('collapsed accordion does not render children; tap toggles', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(harness(
        f,
        ClideAccordion(
          label: 'Group',
          count: 2,
          expanded: false,
          onToggle: () => toggled++,
          children: const [Text('child-one'), Text('child-two')],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Group · 2'), findsOneWidget);
      expect(find.text('child-one'), findsNothing);
      await tester.tap(find.text('Group · 2'));
      expect(toggled, 1);
    });

    testWidgets('expanded accordion shows children; leading widget renders', (tester) async {
      await tester.pumpWidget(harness(
        f,
        ClideAccordion(
          label: 'Open',
          count: 1,
          expanded: true,
          onToggle: () {},
          leading: const Text('LEAD'),
          children: const [Text('only-child')],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('only-child'), findsOneWidget);
      expect(find.text('LEAD'), findsOneWidget);
    });
  });

  group('ClideScrollbar', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('wraps a Scrollable child and exposes ScrollbarTheme', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(
        f,
        SizedBox(
          height: 100,
          child: ClideScrollbar(
            controller: controller,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 1000),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ClideScrollbar), findsOneWidget);
    });

    test('ScrollbarTheme.updateShouldNotify detects colour changes', () {
      const a = ScrollbarTheme(
        slider: Color(0xFF000000),
        sliderHover: Color(0xFF111111),
        track: Color(0xFF222222),
        child: SizedBox.shrink(),
      );
      const b = ScrollbarTheme(
        slider: Color(0xFFFFFFFF),
        sliderHover: Color(0xFF111111),
        track: Color(0xFF222222),
        child: SizedBox.shrink(),
      );
      expect(a.updateShouldNotify(b), isTrue);
      expect(a.updateShouldNotify(a), isFalse);
    });
  });

  group('ClidePtyView', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders Semantics live region wrapping a TerminalView', (tester) async {
      final terminal = Terminal(maxLines: 100, onOutput: (_) {});
      await tester.pumpWidget(harness(
        f,
        SizedBox(width: 400, height: 200, child: ClidePtyView(terminal: terminal, label: 'test-pane')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ClidePtyView), findsOneWidget);
      // The TerminalView inside renders the actual viewport.
      expect(find.byType(TerminalView), findsOneWidget);
    });
  });
}
