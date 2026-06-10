/// Widget tests for [ClideCollapserCard] (T-305) — the conversation stream's
/// category-3 collapsible card. Covers the collapsed ticker chrome (label +
/// echoed summary + fixed counter + aggregate status), expand/collapse via the
/// row, the background-as-toggle, item taps not hijacked, the keyboard/AT path,
/// and the `color` driving border + label tint.
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

  Future<void> pump(
    WidgetTester tester, {
    List<Widget>? children,
    String label = 'Edits',
    String? summary = 'clide_markdown.dart',
    String? counter = '3 edits',
    ClideRunStatus? status = ClideRunStatus.success,
    Color? color,
    bool expanded = false,
  }) async {
    await tester.pumpWidget(harness(
      f,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: ClideCollapserCard(
            label: label,
            collapsedSummary: summary,
            counter: counter,
            status: status,
            color: color,
            initiallyExpanded: expanded,
            children: children ?? const [Text('item body', textDirection: TextDirection.ltr)],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('collapsed ticker shows label, echoed summary, counter + status; items hidden', (tester) async {
    await pump(tester);
    expect(find.text('Edits'), findsOneWidget);
    expect(find.text('clide_markdown.dart'), findsOneWidget);
    expect(find.text('3 edits'), findsOneWidget);
    expect(find.byType(ClideStatusIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Edits, 3 edits, collapsed'), findsOneWidget);
    expect(find.text('item body'), findsNothing);
  });

  testWidgets('tapping the ticker expands to the framed item canvas', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Edits, 3 edits, collapsed'));
    await tester.pump();
    expect(find.bySemanticsLabel('Edits, 3 edits, expanded'), findsOneWidget);
    expect(find.text('item body'), findsOneWidget);
    // The label + chrome persist in the expanded header.
    expect(find.text('Edits'), findsOneWidget);
    expect(find.text('3 edits'), findsOneWidget);
  });

  testWidgets('a single item still sits in the list (1-item collapser)', (tester) async {
    await pump(tester, counter: '1 edit', children: const [Text('only item', textDirection: TextDirection.ltr)], expanded: true);
    expect(find.text('only item'), findsOneWidget);
    expect(find.text('1 edit'), findsOneWidget);
  });

  testWidgets('a tap on the frame BACKGROUND (gutter) collapses it', (tester) async {
    await pump(tester, expanded: true);
    expect(find.text('item body'), findsOneWidget);

    // The left gutter (x = left+4) is collapser background — items start at
    // left+10 — and below the header, so this hits the background toggle.
    final r = tester.getRect(find.byType(ClideCollapserCard));
    await tester.tapAt(Offset(r.left + 4, r.center.dy));
    await tester.pump();
    expect(find.text('item body'), findsNothing);
    expect(find.bySemanticsLabel('Edits, 3 edits, collapsed'), findsOneWidget);
  });

  testWidgets('a tap on an item does NOT toggle the collapser', (tester) async {
    await pump(tester, expanded: true);
    await tester.tap(find.text('item body'));
    await tester.pump();
    expect(find.text('item body'), findsOneWidget); // still expanded
    expect(find.bySemanticsLabel('Edits, 3 edits, expanded'), findsOneWidget);
  });

  testWidgets('a deeper interactive control inside an item still fires (not swallowed)', (tester) async {
    var tapped = false;
    await pump(tester, expanded: true, children: [
      ClideTappable(
        onTap: () => tapped = true,
        builder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(8),
          child: Text('press me', textDirection: TextDirection.ltr),
        ),
      ),
    ]);
    await tester.tap(find.text('press me'));
    await tester.pump();
    expect(tapped, isTrue); // the item's own control won the hit
    expect(find.bySemanticsLabel('Edits, 3 edits, expanded'), findsOneWidget); // collapser unchanged
  });

  testWidgets('the ticker is keyboard-focusable and toggles on Activate (a11y)', (tester) async {
    await pump(tester);
    final focusWidget = tester.widget<Focus>(
      find.ancestor(of: find.text('clide_markdown.dart'), matching: find.byType(Focus)).first,
    );
    focusWidget.focusNode!.requestFocus();
    await tester.pump();
    expect(focusWidget.focusNode!.hasFocus, isTrue);

    Actions.invoke(focusWidget.focusNode!.context!, const ActivateIntent());
    await tester.pump();
    expect(find.bySemanticsLabel('Edits, 3 edits, expanded'), findsOneWidget);
  });

  testWidgets('color drives the border + the label tint', (tester) async {
    const teal = Color(0xFF00AB9A);
    await pump(tester, color: teal);

    // Label text carries the color.
    final label = tester.widget<ClideText>(find.byWidgetPredicate((w) => w is ClideText && w.data == 'Edits'));
    expect(label.color, teal);

    // Some frame Container carries a border in the color.
    expect(
      find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.border?.bottom.color == teal || (d is BoxDecoration && d.border is Border && (d.border as Border).top.color == teal);
      }),
      findsWidgets,
    );
  });

  testWidgets('no counter + no status renders a bare ticker without error', (tester) async {
    await pump(tester, counter: null, status: null, summary: null);
    expect(find.text('Edits'), findsOneWidget);
    expect(find.byType(ClideStatusIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Edits, collapsed'), findsOneWidget);
  });
}
