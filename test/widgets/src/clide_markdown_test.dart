/// Tests for ClideMarkdown link handling (T-253): http(s) links are tappable and
/// hand the URL to the caller; other schemes stay inert.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  testWidgets('an autolinked bare URL is tappable and opens via onLinkTap', (tester) async {
    String? opened;
    await tester.pumpWidget(harness(f, ClideMarkdown('see https://example.com/x for more', onLinkTap: (u) => opened = u)));
    await tester.pump();

    await tester.tap(find.text('https://example.com/x'));
    await tester.pump();
    expect(opened, 'https://example.com/x');
  });

  testWidgets('a markdown [text](url) link opens the href, not the text', (tester) async {
    String? opened;
    await tester.pumpWidget(harness(f, ClideMarkdown('[the docs](https://clide.dev/docs)', onLinkTap: (u) => opened = u)));
    await tester.pump();

    await tester.tap(find.text('the docs'));
    await tester.pump();
    expect(opened, 'https://clide.dev/docs');
  });

  testWidgets('a non-http scheme is not tappable (no handler fired)', (tester) async {
    var calls = 0;
    await tester.pumpWidget(harness(f, ClideMarkdown('[mail](mailto:a@b.com)', onLinkTap: (_) => calls++)));
    await tester.pump();

    await tester.tap(find.text('mail'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('with no onLinkTap, a link still renders (inert, no crash)', (tester) async {
    await tester.pumpWidget(harness(f, const ClideMarkdown('see https://example.com here')));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // T-379: hard breaks and images fell through to empty text spans —
  // words glued together, images vanished without a trace.
  testWidgets('a hard line break splits the line instead of gluing words', (tester) async {
    // Two trailing spaces = a markdown hard break.
    await tester.pumpWidget(harness(f, const ClideMarkdown('alpha  \nbeta')));
    await tester.pump();
    expect(find.textContaining('alpha\nbeta'), findsOneWidget);
    expect(find.textContaining('alphabeta'), findsNothing);
  });

  testWidgets('an image renders its alt text as a visible placeholder', (tester) async {
    await tester.pumpWidget(harness(f, const ClideMarkdown('before ![a diagram](http://x/y.png) after')));
    await tester.pump();
    expect(find.textContaining('[image: a diagram]'), findsOneWidget);
  });

  testWidgets('an image with no alt text falls back to its source', (tester) async {
    await tester.pumpWidget(harness(f, const ClideMarkdown('![](http://x/y.png)')));
    await tester.pump();
    expect(find.textContaining('[image: http://x/y.png]'), findsOneWidget);
  });

  // T-475 (UI) / T-472 (mono): the static span builders take no BuildContext,
  // so they used to pin the bundled const families and ignore the live font
  // settings. They now read the resolved families from the ClideSettingsScope.
  testWidgets('prose and inline code honour the live UI + mono families from the scope', (tester) async {
    await tester.pumpWidget(harness(f, const ClideSettingsScope(ui: 'TestUiFace', mono: 'TestMonoFace', child: ClideMarkdown('hello `snippet` world'))));
    await tester.pump();

    final families = <String?>{};
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        families.add(span.style?.fontFamily);
        for (final child in span.children ?? const <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final span = t.textSpan;
      if (span != null) collect(span);
    }
    expect(families, contains('TestUiFace')); // prose paragraph
    expect(families, contains('TestMonoFace')); // inline `code`
  });
}
