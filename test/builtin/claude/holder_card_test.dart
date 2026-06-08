/// Widget tests for the shared [ClideHolderCard] container primitive (T-266):
/// collapsed ticker, background-as-toggle, child taps not hijacked, the copy
/// control still works, and the keyboard/AT collapse path.
library;

import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:clide/builtin/claude/src/holder_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async {
    f = await KernelFixture.create();
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    f.dispose();
  });

  // A tight, positioned tree so the holder's Row/Expanded get a bounded width
  // and a deterministic on-screen rect for coordinate hit-testing.
  Future<void> pump(WidgetTester tester, {List<Widget>? children, String summary = 'latest step', bool expanded = false}) async {
    await tester.pumpWidget(harness(
      f,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: ClideHolderCard(
            collapsedSummary: summary,
            stepLabel: '2 steps',
            initiallyExpanded: expanded,
            children: children ??
                const [
                  ConversationCard(
                    variant: ConversationCardVariant.bordered,
                    accent: Color(0xFFFFFFFF),
                    label: 'step',
                    body: Text('child body', textDirection: TextDirection.ltr),
                  ),
                ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('collapsed shows the ticker summary + step count; tap expands', (tester) async {
    await pump(tester);
    expect(find.text('latest step'), findsOneWidget);
    expect(find.text('2 steps'), findsOneWidget);
    expect(find.bySemanticsLabel('Activity, 2 steps, collapsed'), findsOneWidget);
    expect(find.text('child body'), findsNothing); // children hidden while collapsed

    await tester.tap(find.bySemanticsLabel('Activity, 2 steps, collapsed'));
    await tester.pump();
    expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
    expect(find.text('child body'), findsOneWidget);
  });

  testWidgets('a tap on the holder BACKGROUND (gutter) collapses it', (tester) async {
    await pump(tester, expanded: true);
    expect(find.text('child body'), findsOneWidget); // expanded

    // The left gutter (x = left+4) is holder background — children start at
    // left+10 — and below the header, so this hits the background toggle.
    final r = tester.getRect(find.byType(ClideHolderCard));
    await tester.tapAt(Offset(r.left + 4, r.center.dy));
    await tester.pump();
    expect(find.text('child body'), findsNothing); // collapsed
    expect(find.bySemanticsLabel('Activity, 2 steps, collapsed'), findsOneWidget);
  });

  testWidgets('a tap on a child sub-card does NOT toggle the holder', (tester) async {
    await pump(tester, expanded: true);
    expect(find.text('child body'), findsOneWidget);

    // Tapping the child's body must be absorbed by the child, not bubble to the
    // holder background toggle.
    await tester.tap(find.text('child body'));
    await tester.pump();
    expect(find.text('child body'), findsOneWidget); // still expanded
    expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
  });

  testWidgets('a child copy button still copies — not swallowed by the holder', (tester) async {
    await pump(tester, expanded: true, children: const [
      ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: Color(0xFFFFFFFF),
        label: 'step',
        copyText: 'copied from a held card',
        body: Text('child body', textDirection: TextDirection.ltr),
      ),
    ]);

    // Hover the child to reveal its copy action, then tap it.
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(find.byType(ConversationCard)));
    await tester.pump();

    await tester.tap(find.text('copy'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(f.services.clipboard.readAs<String>(), 'copied from a held card');
    // And the holder stayed expanded (the copy tap wasn't a background toggle).
    expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
  });

  testWidgets('the explicit control is keyboard-focusable and toggles on Activate (a11y)', (tester) async {
    await pump(tester); // collapsed; the ticker row is the control
    final focusWidget = tester.widget<Focus>(
      find.ancestor(of: find.text('latest step'), matching: find.byType(Focus)).first,
    );
    focusWidget.focusNode!.requestFocus();
    await tester.pump();
    expect(focusWidget.focusNode!.hasFocus, isTrue);

    Actions.invoke(focusWidget.focusNode!.context!, const ActivateIntent());
    await tester.pump();
    expect(find.bySemanticsLabel('Activity, 2 steps, expanded'), findsOneWidget);
  });
}
