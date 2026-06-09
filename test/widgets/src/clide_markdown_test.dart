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
}
