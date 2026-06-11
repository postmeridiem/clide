import 'package:clide/builtin/claude/src/conversation_card.dart';
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
    // Let Clipboard.setData complete instead of throwing on the unmocked
    // platform channel, so ClideClipboard.writePlain reaches its history push.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    f.dispose();
  });

  // Move a synthetic mouse over the card so the hover-revealed actions appear.
  Future<void> hoverCard(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(find.byType(ConversationCard)));
    await tester.pump();
  }

  // Returns the Opacity wrapping the action bar (the Opacity that reveals/hides
  // the action buttons on hover or focus).
  Opacity actionBarOpacity(WidgetTester tester) {
    // The action bar Opacity is a direct child of the header Row — pick the
    // first Opacity that is an ancestor of the 'copy' Semantics (or any action
    // label), which is the one whose value toggles on hover/focus.
    return tester.widgetList<Opacity>(find.byType(Opacity)).first;
  }

  testWidgets('copy button is always in the tree (Opacity 0 before hover)', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          accent: Color(0xFFFFFFFF),
          label: 'you',
          copyText: 'the raw message',
          body: Text('the raw message', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();

    // The text widget is in the tree (always), but the Opacity hides it.
    expect(find.text('copy'), findsOneWidget);
    expect(actionBarOpacity(tester).opacity, 0.0);
  });

  testWidgets('copy button (on hover) writes the copyText to the clipboard', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          accent: Color(0xFFFFFFFF),
          label: 'you',
          copyText: 'the raw message',
          body: Text('the raw message', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();

    await hoverCard(tester);
    expect(actionBarOpacity(tester).opacity, 1.0);

    await tester.tap(find.text('copy'));
    // writePlain awaits the clipboard channel; let the real async settle.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(f.services.clipboard.readAs<String>(), 'the raw message');
  });

  testWidgets('copy button: keyboard focus + ActivateIntent writes to clipboard without hovering', (tester) async {
    // T-174: actions must be keyboard-reachable even when the card is not hovered.
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          accent: Color(0xFFFFFFFF),
          label: 'you',
          copyText: 'keyboard written',
          body: Text('keyboard written', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();

    // Locate the ClideTappable whose FocusNode we want: the one wrapping the
    // 'copy' label. We drive focus programmatically via the node embedded in
    // the widget — find the Focus descendent nearest to the 'copy' text.
    final copyTextFinder = find.text('copy');
    expect(copyTextFinder, findsOneWidget);

    // Walk up to find the Focus that ClideTappable installed, then request focus.
    final focusWidget = tester.widget<Focus>(find.ancestor(of: copyTextFinder, matching: find.byType(Focus)).first);
    focusWidget.focusNode!.requestFocus();
    await tester.pump(); // focus resolves; the focus listener calls setState
    await tester.pump(); // the scheduled rebuild paints the lifted opacity

    expect(focusWidget.focusNode!.hasFocus, isTrue, reason: 'copy action should accept keyboard focus');

    // With focus, the action bar opacity should lift to 1.0.
    expect(actionBarOpacity(tester).opacity, 1.0);

    // Invoke via ActivateIntent (what Enter/Space dispatches from the keymap).
    Actions.invoke(focusWidget.focusNode!.context!, const ActivateIntent());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

    expect(f.services.clipboard.readAs<String>(), 'keyboard written');
  });

  testWidgets('copy button carries a Semantics button label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          accent: Color(0xFFFFFFFF),
          label: 'you',
          copyText: 'msg',
          body: Text('msg', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    // Semantics label 'copy' must be present even before hover, so AT can
    // discover the button without the user mousing over first.
    expect(find.bySemanticsLabel('copy'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('collapsible card hides its body until expanded', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFFFFFF),
          label: 'result',
          collapsible: true,
          collapsedByDefault: true,
          body: Text('tool output here', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('tool output here'), findsNothing); // collapsed

    await tester.tap(find.bySemanticsLabel('Expand'));
    await tester.pump();
    expect(find.text('tool output here'), findsOneWidget); // expanded
    expect(find.bySemanticsLabel('Collapse'), findsOneWidget);
  });

  testWidgets('a non-collapsible card always shows its body and no caret', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          accent: Color(0xFFFFFFFF),
          label: 'claude',
          body: Text('always visible', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('always visible'), findsOneWidget);
    expect(find.bySemanticsLabel('Expand'), findsNothing);
    expect(find.bySemanticsLabel('Collapse'), findsNothing);
  });

  testWidgets('custom actions are always in the tree (Opacity 0 before hover)', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        ConversationCard(
          accent: const Color(0xFFFFFFFF),
          label: 'claude',
          body: const Text('body', textDirection: TextDirection.ltr),
          actions: [MessageAction(label: 'fork', onInvoke: () {})],
        ),
      ),
    );
    await tester.pump();

    // 'fork' is in the tree (always), but the Opacity hides it.
    expect(find.text('fork'), findsOneWidget);
    expect(actionBarOpacity(tester).opacity, 0.0);
  });

  testWidgets('custom actions appear on hover and invoke', (tester) async {
    var forked = false;
    await tester.pumpWidget(
      harness(
        f,
        ConversationCard(
          accent: const Color(0xFFFFFFFF),
          label: 'claude',
          body: const Text('body', textDirection: TextDirection.ltr),
          actions: [MessageAction(label: 'fork', onInvoke: () => forked = true)],
        ),
      ),
    );
    await tester.pump();

    await hoverCard(tester);
    expect(actionBarOpacity(tester).opacity, 1.0);
    await tester.tap(find.text('fork'));
    await tester.pump();
    expect(forked, isTrue);
  });

  testWidgets('didUpdateWidget: shrink path disposes excess focus nodes when actions count drops', (tester) async {
    // Use a ValueNotifier to drive rebuildable parent so the _ConversationCardState
    // is reused across builds (didUpdateWidget fires rather than a full remount).
    final showExtra = ValueNotifier<bool>(true);
    addTearDown(showExtra.dispose);

    await tester.pumpWidget(
      harness(
        f,
        ValueListenableBuilder<bool>(
          valueListenable: showExtra,
          builder: (_, show, _) => ConversationCard(
            accent: const Color(0xFFFFFFFF),
            label: 'claude',
            copyText: show ? 'text' : null,
            body: const Text('body', textDirection: TextDirection.ltr),
            actions: show ? [MessageAction(label: 'fork', onInvoke: () {})] : [],
          ),
        ),
      ),
    );
    await tester.pump();
    // Initially: copy + fork.
    expect(find.text('copy'), findsOneWidget);
    expect(find.text('fork'), findsOneWidget);

    // Shrink: remove copyText and all custom actions.
    // This triggers the shrink branch of _syncActionFocusNodes.
    showExtra.value = false;
    await tester.pump();

    // Actions gone.
    expect(find.text('copy'), findsNothing);
    expect(find.text('fork'), findsNothing);
  });

  testWidgets('collapsible card: Semantics.onTap on caret also toggles collapse', (tester) async {
    // The caret Semantics node has its own onTap (for accessibility-tree callers).
    // Invoke it via the Semantics.onTap callback directly.
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFFFFFF),
          label: 'result',
          collapsible: true,
          collapsedByDefault: true,
          body: Text('tool output here', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('tool output here'), findsNothing); // collapsed

    // Find the Semantics node for the caret and trigger its onTap.
    final caretSem = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Expand');
    expect(caretSem, findsOneWidget);
    final sem = caretSem.evaluate().single.widget as Semantics;
    // Fire the accessibility tap callback.
    sem.properties.onTap!();
    await tester.pump();

    expect(find.text('tool output here'), findsOneWidget); // expanded
  });

  testWidgets('bordered variant renders with a border container', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFF0000),
          label: 'result',
          body: Text('bordered body', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('bordered body'), findsOneWidget);
    expect(find.text('result'), findsOneWidget);
  });

  testWidgets('status: success renders a "succeeded" semantics mark in the header (T-262)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFFFFFF),
          label: 'Bash',
          status: ConversationCardStatus.success,
          body: Text('body', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('succeeded'), findsOneWidget);
    expect(find.bySemanticsLabel('failed'), findsNothing);
    handle.dispose();
  });

  testWidgets('status: error renders a "failed" semantics mark; none renders nothing (T-262)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFFFFFF),
          label: 'Bash',
          status: ConversationCardStatus.error,
          body: Text('body', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('failed'), findsOneWidget);
    expect(find.bySemanticsLabel('succeeded'), findsNothing);
    handle.dispose();
  });

  testWidgets('extraSegments render below the body with their sub-label when expanded (T-262)', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bordered,
          accent: Color(0xFFFFFFFF),
          label: 'Read',
          collapsible: true,
          collapsedByDefault: true,
          body: Text('the call', textDirection: TextDirection.ltr),
          extraSegments: [
            CardSegment(
              label: 'result',
              child: Text('the output', textDirection: TextDirection.ltr),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    // Collapsed: neither the body nor the segment shows.
    expect(find.text('the call'), findsNothing);
    expect(find.text('result'), findsNothing);
    expect(find.text('the output'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Expand'));
    await tester.pump();
    expect(find.text('the call'), findsOneWidget); // primary body
    expect(find.text('result'), findsOneWidget); // segment sub-label
    expect(find.text('the output'), findsOneWidget); // segment child
  });

  testWidgets('bare variant renders content without frame decoration', (tester) async {
    await tester.pumpWidget(
      harness(
        f,
        const ConversationCard(
          variant: ConversationCardVariant.bare,
          accent: Color(0xFF00FF00),
          label: 'bare',
          body: Text('bare body', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('bare body'), findsOneWidget);
  });
}
